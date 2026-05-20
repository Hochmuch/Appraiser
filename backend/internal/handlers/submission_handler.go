package handlers

import (
	"context"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"

	"appraiser/internal/middleware"
	"appraiser/internal/models"
	"appraiser/internal/repository"
	"appraiser/internal/services"
	"appraiser/internal/services/ingestion"

	"github.com/gorilla/mux"
)

type SubmissionHandler struct {
	submissionRepo   *repository.SubmissionRepo
	assignmentRepo   *repository.AssignmentRepo
	snapshotRepo     *repository.SnapshotRepo
	userRepo         *repository.UserRepo
	githubService    *services.GitHubService
	ingestionService *ingestion.Service
	defaultProvider  string
}

func NewSubmissionHandler(
	sr *repository.SubmissionRepo,
	ar *repository.AssignmentRepo,
	snap *repository.SnapshotRepo,
	ur *repository.UserRepo,
	gs *services.GitHubService,
	ing *ingestion.Service,
) *SubmissionHandler {
	provider := services.NormalizeLLMProvider(os.Getenv("LLM_PROVIDER"))
	if provider == "" {
		provider = services.LLMProviderGigaChat
	}

	return &SubmissionHandler{
		submissionRepo:   sr,
		assignmentRepo:   ar,
		snapshotRepo:     snap,
		userRepo:         ur,
		githubService:    gs,
		ingestionService: ing,
		defaultProvider:  provider,
	}
}

func (h *SubmissionHandler) Submit(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	assignmentID, err := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	if err != nil {
		writeError(w, "invalid assignment id", http.StatusBadRequest)
		return
	}

	var req models.SubmitRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.GithubRepo == "" {
		writeError(w, "github_repo is required", http.StatusBadRequest)
		return
	}

	user, err := h.userRepo.GetByID(userID)
	if err != nil {
		writeError(w, "user not found", http.StatusInternalServerError)
		return
	}
	if user.GithubLogin == "" {
		writeError(w, "Please link your GitHub account first", http.StatusForbidden)
		return
	}

	repoPrefix := strings.ToLower(user.GithubLogin)

	urlParts := strings.Split(strings.TrimSuffix(strings.TrimSuffix(req.GithubRepo, "/"), ".git"), "/")
	var owner string
	if len(urlParts) >= 2 {
		owner = urlParts[len(urlParts)-2]
	}

	if strings.ToLower(owner) != repoPrefix {
		writeError(w, "You can only submit your own repository", http.StatusBadRequest)
		return
	}

	hasAccess, err := h.assignmentRepo.StudentHasAccess(assignmentID, userID)
	if err != nil {
		writeError(w, "failed to validate assignment access", http.StatusInternalServerError)
		return
	}
	if !hasAccess {
		writeError(w, "assignment is not assigned to your groups", http.StatusForbidden)
		return
	}

	submission, err := h.submissionRepo.Create(assignmentID, userID, req.GithubRepo)
	if err != nil {
		writeError(w, "failed to create submission: "+err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, submission)
}

func (h *SubmissionHandler) StartReview(w http.ResponseWriter, r *http.Request) {
	var req models.StartReviewRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil && err != io.EOF {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	provider := services.NormalizeLLMProvider(req.LLMProvider)
	if provider == "" {
		provider = h.defaultProvider
	}

	reviewer, err := services.NewLLMReviewer(r.Context(), provider)
	if err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}

	submissionID, err := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	if err != nil {
		writeError(w, "invalid submission id", http.StatusBadRequest)
		return
	}

	submission, err := h.submissionRepo.GetByID(submissionID)
	if err != nil {
		writeError(w, "submission not found", http.StatusNotFound)
		return
	}

	criteria, err := h.assignmentRepo.GetCriteria(submission.AssignmentID)
	if err != nil || len(criteria) == 0 {
		writeError(w, "no criteria found for this assignment", http.StatusBadRequest)
		return
	}

	if err := h.submissionRepo.ClearReviewData(submissionID); err != nil {
		writeError(w, "failed to clear previous review data", http.StatusInternalServerError)
		return
	}

	if err := h.submissionRepo.UpdateLLMProvider(submissionID, provider); err != nil {
		writeError(w, "failed to save llm provider", http.StatusInternalServerError)
		return
	}

	h.submissionRepo.UpdateStatus(submissionID, "reviewing")

	go func() {
		ctx := context.Background()

		ir, err := h.ingestionService.Ingest(submissionID, submission.GithubRepo)
		if err != nil {
			log.Printf("Error during ingestion for submission %d: %v", submissionID, err)
			h.submissionRepo.UpdateStatus(submissionID, "error")
			return
		}

		sourceFiles, err := h.snapshotRepo.GetSourceFiles(ir.Snapshot.ID)
		if err != nil {
			log.Printf("Error loading source files for submission %d: %v", submissionID, err)
			h.submissionRepo.UpdateStatus(submissionID, "error")
			return
		}

		sourceFileIDByPath := make(map[string]int64, len(sourceFiles))
		for _, sourceFile := range sourceFiles {
			sourceFileIDByPath[normalizeFilePath(sourceFile.FilePath)] = sourceFile.ID
		}

		rc := &services.ReviewContext{
			ProjectMap: ir.Snapshot.ProjectMap,
			Summary:    ir.Snapshot.Summary,
		}
		for _, ch := range ir.Chunks {
			rc.Chunks = append(rc.Chunks, services.ReviewCodeChunk{
				FilePath:   ch.FilePath,
				Language:   ch.Language,
				StartLine:  ch.StartLine,
				EndLine:    ch.EndLine,
				SymbolType: ch.SymbolType,
				SymbolName: ch.SymbolName,
				Content:    ch.Content,
			})
		}

		result, err := reviewer.ReviewWithContext(ctx, rc, criteria)
		if err != nil {
			log.Printf("Error during LLM review for submission %d: %v", submissionID, err)
			h.submissionRepo.UpdateStatus(submissionID, "error")
			return
		}

		reviewMap := make(map[int64]int64)
		var defaultReviewID int64
		for _, cr := range result.Results {
			review := &models.Review{
				SubmissionID: submissionID,
				CriteriaID:   cr.CriteriaID,
				Score:        int(cr.Score),
				Comment:      cr.Comment,
			}
			if err := h.submissionRepo.SaveReview(review); err != nil {
				log.Printf("Error saving review for submission %d, criteria %d: %v", submissionID, cr.CriteriaID, err)
			} else {
				reviewMap[cr.CriteriaID] = review.ID
				if defaultReviewID == 0 {
					defaultReviewID = review.ID
				}
			}
		}

		findings := make([]models.ReviewFinding, 0, len(result.Findings))
		for _, f := range result.Findings {
			startLine := f.StartLine
			endLine := f.EndLine
			if startLine < 1 {
				startLine = 1
			}
			if endLine < startLine {
				endLine = startLine
			}

			severity := strings.ToLower(strings.TrimSpace(f.Severity))
			switch severity {
			case "info", "warning", "error":
			default:
				severity = "info"
			}

			rID := defaultReviewID
			if mapID, ok := reviewMap[f.CriteriaID]; ok {
				rID = mapID
			}

			findings = append(findings, models.ReviewFinding{
				ReviewID:    rID,
				SourceFileID: func() *int64 {
					if id, ok := sourceFileIDByPath[normalizeFilePath(f.FilePath)]; ok {
						return &id
					}
					return nil
				}(),
				StartLine:   startLine,
				EndLine:     endLine,
				Severity:    severity,
				Title:       strings.TrimSpace(f.Title),
				Comment:     strings.TrimSpace(f.Comment),
				Suggestion:  strings.TrimSpace(f.Suggestion),
				Source:      "llm",
			})
		}

		if err := h.submissionRepo.ReplaceFindings(submissionID, findings); err != nil {
			log.Printf("Error saving findings for submission %d: %v", submissionID, err)
		}

		h.submissionRepo.UpdateStatus(submissionID, "completed")
		log.Printf("Review completed for submission %d", submissionID)
	}()

	writeJSON(w, http.StatusAccepted, map[string]string{
		"message": "review started",
		"status":  "reviewing",
	})
}

func (h *SubmissionHandler) GetResults(w http.ResponseWriter, r *http.Request) {
	submissionID, err := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	if err != nil {
		writeError(w, "invalid submission id", http.StatusBadRequest)
		return
	}

	submission, err := h.submissionRepo.GetByID(submissionID)
	if err != nil {
		writeError(w, "submission not found", http.StatusNotFound)
		return
	}

	reviews, err := h.submissionRepo.GetReviews(submissionID)
	if err != nil {
		writeError(w, "failed to get reviews", http.StatusInternalServerError)
		return
	}

	submission.Reviews = reviews
	if submission.Reviews == nil {
		submission.Reviews = []models.Review{}
	}

	findings, err := h.submissionRepo.GetFindings(submissionID)
	if err != nil {
		log.Printf("ERROR GetFindings for submission %d: %v", submissionID, err)
		writeError(w, "failed to get findings", http.StatusInternalServerError)
		return
	}
	submission.Findings = findings
	if submission.Findings == nil {
		submission.Findings = []models.ReviewFinding{}
	}

	writeJSON(w, http.StatusOK, submission)
}

func (h *SubmissionHandler) MySubmissions(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)

	submissions, err := h.submissionRepo.ListByStudent(userID)
	if err != nil {
		writeError(w, "failed to list submissions", http.StatusInternalServerError)
		return
	}

	if submissions == nil {
		submissions = []models.Submission{}
	}

	writeJSON(w, http.StatusOK, submissions)
}

func (h *SubmissionHandler) GetFiles(w http.ResponseWriter, r *http.Request) {
	submissionID, err := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	if err != nil {
		writeError(w, "invalid submission id", http.StatusBadRequest)
		return
	}

	submission, err := h.submissionRepo.GetByID(submissionID)
	if err != nil {
		writeError(w, "submission not found", http.StatusNotFound)
		return
	}

	files, err := h.githubService.FetchRepoFiles(submission.GithubRepo)
	if err != nil {
		writeError(w, "failed to fetch repository files: "+err.Error(), http.StatusBadGateway)
		return
	}

	if files == nil {
		files = []services.GitHubFile{}
	}

	writeJSON(w, http.StatusOK, files)
}

func (h *SubmissionHandler) GetFindings(w http.ResponseWriter, r *http.Request) {
	submissionID, err := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	if err != nil {
		writeError(w, "invalid submission id", http.StatusBadRequest)
		return
	}

	_, err = h.submissionRepo.GetByID(submissionID)
	if err != nil {
		writeError(w, "submission not found", http.StatusNotFound)
		return
	}

	findings, err := h.submissionRepo.GetFindings(submissionID)
	if err != nil {
		writeError(w, "failed to load findings", http.StatusInternalServerError)
		return
	}

	if findings == nil {
		findings = []models.ReviewFinding{}
	}

	writeJSON(w, http.StatusOK, findings)
}

func normalizeFilePath(path string) string {
	return strings.ReplaceAll(strings.TrimSpace(path), "\\", "/")
}

func decodeJSON(r *http.Request, v interface{}) error {
	return json.NewDecoder(r.Body).Decode(v)
}
