package main

import (
	"log"
	"net/http"
	"os"
	"strings"

	"appraiser/internal/handlers"
	"appraiser/internal/middleware"
	"appraiser/internal/repository"
	"appraiser/internal/services"
	"appraiser/internal/services/ingestion"

	"github.com/gorilla/mux"
)

func main() {
	
	db, err := repository.NewDB()
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	
	if err := repository.RunMigrations(db, "migrations"); err != nil {
		log.Printf("Warning: migration error (may already be applied): %v", err)
	}

	
	userRepo := repository.NewUserRepo(db)
	assignmentRepo := repository.NewAssignmentRepo(db)
	submissionRepo := repository.NewSubmissionRepo(db)
	groupRepo := repository.NewGroupRepo(db)
	snapshotRepo := repository.NewSnapshotRepo(db)

	
	githubService := services.NewGitHubService()
	ingestionService := ingestion.NewService(githubService, snapshotRepo)

	
	
	
	
	var llmReviewer services.LLMReviewer
	provider := strings.ToLower(strings.TrimSpace(os.Getenv("LLM_PROVIDER")))
	switch provider {
	case "gigachat":
		llmReviewer = services.NewGigaChatReviewer()
		log.Println("Using GigaChat LLM reviewer")
	default:
		log.Println("No LLM_PROVIDER specified")
	}

	
	authHandler := handlers.NewAuthHandler(userRepo)
	assignmentHandler := handlers.NewAssignmentHandler(assignmentRepo, submissionRepo)
	submissionHandler := handlers.NewSubmissionHandler(submissionRepo, assignmentRepo, githubService, llmReviewer, ingestionService)
	groupHandler := handlers.NewGroupHandler(groupRepo)

	
	r := mux.NewRouter()

	
	r.HandleFunc("/api/auth/register", authHandler.Register).Methods("POST", "OPTIONS")
	r.HandleFunc("/api/auth/login", authHandler.Login).Methods("POST", "OPTIONS")
	r.HandleFunc("/api/auth/github/device/start", authHandler.GitHubDeviceStart).Methods("POST", "OPTIONS")
	r.HandleFunc("/api/auth/github/device/poll", authHandler.GitHubDevicePoll).Methods("POST", "OPTIONS")

	
	api := r.PathPrefix("/api").Subrouter()
	api.Use(middleware.AuthMiddleware)

	
	api.HandleFunc("/assignments", assignmentHandler.List).Methods("GET", "OPTIONS")
	api.Handle("/assignments", middleware.TeacherOnly(http.HandlerFunc(assignmentHandler.Create))).Methods("POST")
	api.HandleFunc("/assignments/{id}", assignmentHandler.GetByID).Methods("GET", "OPTIONS")
	api.Handle("/assignments/{id}", middleware.TeacherOnly(http.HandlerFunc(assignmentHandler.Update))).Methods("PUT")

	
	api.HandleFunc("/assignments/{id}/submit", submissionHandler.Submit).Methods("POST", "OPTIONS")
	api.Handle("/submissions/{id}/review", middleware.TeacherOnly(http.HandlerFunc(submissionHandler.StartReview))).Methods("POST", "OPTIONS")
	api.HandleFunc("/submissions/{id}/results", submissionHandler.GetResults).Methods("GET", "OPTIONS")
	api.Handle("/submissions/{id}/files", middleware.TeacherOnly(http.HandlerFunc(submissionHandler.GetFiles))).Methods("GET", "OPTIONS")
	api.Handle("/submissions/{id}/findings", middleware.TeacherOnly(http.HandlerFunc(submissionHandler.GetFindings))).Methods("GET", "OPTIONS")
	api.HandleFunc("/my/submissions", submissionHandler.MySubmissions).Methods("GET", "OPTIONS")

	
	api.Handle("/groups", middleware.TeacherOnly(http.HandlerFunc(groupHandler.ListMine))).Methods("GET", "OPTIONS")
	api.Handle("/groups", middleware.TeacherOnly(http.HandlerFunc(groupHandler.Create))).Methods("POST", "OPTIONS")
	api.Handle("/groups/{id}/students", middleware.TeacherOnly(http.HandlerFunc(groupHandler.AddStudents))).Methods("POST", "OPTIONS")

	
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	handler := middleware.CORSMiddleware(r)

	log.Printf("Server starting on :%s", port)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
