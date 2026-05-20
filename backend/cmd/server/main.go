package main

import (
	"log"
	"net/http"
	"os"

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

	authHandler := handlers.NewAuthHandler(userRepo)
	assignmentHandler := handlers.NewAssignmentHandler(assignmentRepo, submissionRepo)
	submissionHandler := handlers.NewSubmissionHandler(submissionRepo, assignmentRepo, snapshotRepo, userRepo, githubService, ingestionService)
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
	api.HandleFunc("/groups/join/{invite_code}", groupHandler.JoinByInviteCode).Methods("GET", "POST", "OPTIONS")

	r.HandleFunc("/groups/join/{invite_code}", func(w http.ResponseWriter, r *http.Request) {
		code := mux.Vars(r)["invite_code"]
		html := `<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Приглашение в группу</title>
    <script>
        window.onload = function() {
            window.location.href = "appraiser://app/groups/join/" + "` + code + `";
        };
    </script>
    <style>
        body { font-family: sans-serif; text-align: center; padding: 50px; background-color: #f5f5f5; }
        .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); max-width: 400px; margin: 0 auto; }
        .btn { display: inline-block; margin-top: 20px; padding: 12px 24px; background: #1976d2; color: white; text-decoration: none; border-radius: 8px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="card">
        <h2>Приглашение в группу</h2>
        <p>Вы перешли по ссылке для присоединения к группе.</p>
        <p>Если приложение Appraiser не открылось автоматически, нажмите кнопку ниже:</p>
        <a class="btn" href="appraiser://app/groups/join/` + code + `">Открыть в приложении Appraiser</a>
    </div>
</body>
</html>`
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Write([]byte(html))
	}).Methods("GET")

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
