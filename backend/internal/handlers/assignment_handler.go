package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"

	"appraiser/internal/middleware"
	"appraiser/internal/models"
	"appraiser/internal/repository"

	"github.com/gorilla/mux"
)

type AssignmentHandler struct {
	assignmentRepo *repository.AssignmentRepo
	submissionRepo *repository.SubmissionRepo
}

func NewAssignmentHandler(ar *repository.AssignmentRepo, sr *repository.SubmissionRepo) *AssignmentHandler {
	return &AssignmentHandler{assignmentRepo: ar, submissionRepo: sr}
}

func (h *AssignmentHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)

	var req models.CreateAssignmentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Title == "" || len(req.Criteria) == 0 || len(req.GroupIDs) == 0 {
		writeError(w, "title, at least one criteria and at least one group are required", http.StatusBadRequest)
		return
	}

	allowed, err := h.assignmentRepo.ValidateGroupsForTeacher(userID, req.GroupIDs)
	if err != nil {
		writeError(w, "failed to validate groups", http.StatusInternalServerError)
		return
	}
	if !allowed {
		writeError(w, "one or more groups are invalid", http.StatusBadRequest)
		return
	}

	assignment, err := h.assignmentRepo.Create(userID, req)
	if err != nil {
		writeError(w, "failed to create assignment: "+err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, assignment)
}

func (h *AssignmentHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	role, _ := r.Context().Value(middleware.RoleKey).(string)

	assignments, err := h.assignmentRepo.ListForUser(userID, role == "teacher")
	if err != nil {
		writeError(w, "failed to list assignments", http.StatusInternalServerError)
		return
	}

	if assignments == nil {
		assignments = []models.Assignment{}
	}

	writeJSON(w, http.StatusOK, assignments)
}

func (h *AssignmentHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	id, err := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	if err != nil {
		writeError(w, "invalid assignment id", http.StatusBadRequest)
		return
	}

	var req models.CreateAssignmentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Title == "" || len(req.Criteria) == 0 || len(req.GroupIDs) == 0 {
		writeError(w, "title, at least one criteria and at least one group are required", http.StatusBadRequest)
		return
	}

	allowed, err := h.assignmentRepo.ValidateGroupsForTeacher(userID, req.GroupIDs)
	if err != nil {
		writeError(w, "failed to validate groups", http.StatusInternalServerError)
		return
	}
	if !allowed {
		writeError(w, "one or more groups are invalid", http.StatusBadRequest)
		return
	}

	assignment, err := h.assignmentRepo.Update(id, userID, req)
	if err != nil {
		writeError(w, "failed to update assignment: "+err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, assignment)
}

func (h *AssignmentHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	role, _ := r.Context().Value(middleware.RoleKey).(string)
	isTeacher := role == "teacher"

	id, err := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	if err != nil {
		writeError(w, "invalid assignment id", http.StatusBadRequest)
		return
	}

	assignment, err := h.assignmentRepo.GetByIDForUser(id, userID, isTeacher)
	if err != nil {
		writeError(w, "assignment not found", http.StatusNotFound)
		return
	}

	if isTeacher {
		submissions, err := h.submissionRepo.ListByAssignment(id)
		if err != nil {
			log.Printf("ERROR calling ListByAssignment: %v", err)
		} else {
			type assignmentWithSubmissions struct {
				models.Assignment
				Submissions []models.Submission `json:"submissions"`
			}
			resp := assignmentWithSubmissions{
				Assignment:  *assignment,
				Submissions: submissions,
			}
			if resp.Submissions == nil {
				resp.Submissions = []models.Submission{}
			}
			writeJSON(w, http.StatusOK, resp)
			return
		}
	}

	writeJSON(w, http.StatusOK, assignment)
}
