package handlers

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
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
	githubService    *services.GitHubService
	llmReviewer      services.LLMReviewer
	ingestionService *ingestion.Service
}

func NewSubmissionHandler(
	sr *repository.SubmissionRepo,
	ar *repository.AssignmentRepo,
	gs *services.GitHubService,
	llm services.LLMReviewer,
	ing *ingestion.Service,
) *SubmissionHandler {
	return &SubmissionHandler{
		submissionRepo:   sr,
		assignmentRepo:   ar,
		githubService:    gs,
		llmReviewer:      llm,
		ingestionService: ing,
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

	
	h.submissionRepo.UpdateStatus(submissionID, "reviewing")

	
	go func() {
		ctx := context.Background()

		
		ir, err := h.ingestionService.Ingest(submissionID, submission.GithubRepo)
		if err != nil {
			log.Printf("Error during ingestion for submission %d: %v", submissionID, err)
			h.submissionRepo.UpdateStatus(submissionID, "error")
			return
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

		
		result, err := h.llmReviewer.ReviewWithContext(ctx, rc, criteria)
		if err != nil {
			log.Printf("Error during LLM review for submission %d: %v", submissionID, err)
			h.submissionRepo.UpdateStatus(submissionID, "error")
			return
		}

		
		for _, cr := range result.Results {
			review := &models.Review{
				SubmissionID: submissionID,
				CriteriaID:   cr.CriteriaID,
				Score:        cr.Score,
				Comment:      cr.Comment,
			}
			if err := h.submissionRepo.SaveReview(review); err != nil {
				log.Printf("Error saving review for submission %d, criteria %d: %v", submissionID, cr.CriteriaID, err)
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

			var criteriaID *int64
			if f.CriteriaID > 0 {
				cid := f.CriteriaID
				criteriaID = &cid
			}

			findings = append(findings, models.ReviewFinding{
				SubmissionID: submissionID,
				CriteriaID:   criteriaID,
				FilePath:     f.FilePath,
				StartLine:    startLine,
				EndLine:      endLine,
				Severity:     severity,
				Title:        strings.TrimSpace(f.Title),
				Comment:      strings.TrimSpace(f.Comment),
				Suggestion:   strings.TrimSpace(f.Suggestion),
				Source:       "llm",
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

func decodeJSON(r *http.Request, v interface{}) error {
	return json.NewDecoder(r.Body).Decode(v)
}
