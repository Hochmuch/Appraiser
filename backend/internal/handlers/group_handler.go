package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"appraiser/internal/middleware"
	"appraiser/internal/models"
	"appraiser/internal/repository"

	"github.com/gorilla/mux"
)

type GroupHandler struct {
	groupRepo *repository.GroupRepo
}

func NewGroupHandler(groupRepo *repository.GroupRepo) *GroupHandler {
	return &GroupHandler{groupRepo: groupRepo}
}

func (h *GroupHandler) Create(w http.ResponseWriter, r *http.Request) {
	teacherID := r.Context().Value(middleware.UserIDKey).(int64)

	var req models.CreateGroupRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Name == "" {
		writeError(w, "group name is required", http.StatusBadRequest)
		return
	}

	group, err := h.groupRepo.Create(teacherID, req)
	if err != nil {
		writeError(w, "failed to create group: "+err.Error(), http.StatusBadRequest)
		return
	}

	writeJSON(w, http.StatusCreated, group)
}

func (h *GroupHandler) ListMine(w http.ResponseWriter, r *http.Request) {
	teacherID := r.Context().Value(middleware.UserIDKey).(int64)

	groups, err := h.groupRepo.ListByTeacher(teacherID)
	if err != nil {
		writeError(w, "failed to list groups", http.StatusInternalServerError)
		return
	}

	if groups == nil {
		groups = []models.Group{}
	}

	writeJSON(w, http.StatusOK, groups)
}

func (h *GroupHandler) AddStudents(w http.ResponseWriter, r *http.Request) {
	teacherID := r.Context().Value(middleware.UserIDKey).(int64)

	groupID, err := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	if err != nil {
		writeError(w, "invalid group id", http.StatusBadRequest)
		return
	}

	var req models.AddStudentsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if len(req.StudentEmails) == 0 {
		writeError(w, "student_emails is required", http.StatusBadRequest)
		return
	}

	group, err := h.groupRepo.AddStudents(groupID, teacherID, req.StudentEmails)
	if err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}

	writeJSON(w, http.StatusOK, group)
}