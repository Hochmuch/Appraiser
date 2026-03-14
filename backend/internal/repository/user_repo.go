package repository

import (
	"database/sql"
	"errors"
	"fmt"
	"math/rand"

	"appraiser/internal/models"

	"golang.org/x/crypto/bcrypt"
)

type UserRepo struct {
	db *sql.DB
}

func NewUserRepo(db *sql.DB) *UserRepo {
	return &UserRepo{db: db}
}

func (r *UserRepo) Create(req models.RegisterRequest) (*models.User, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	user := &models.User{}
	err = r.db.QueryRow(
		`INSERT INTO users (email, name, password_hash, is_teacher)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, email, name, password_hash, github_id, github_login, is_teacher, created_at`,
		req.Email, req.Name, string(hash), req.IsTeacher,
	).Scan(&user.ID, &user.Email, &user.Name, &user.PasswordHash, &user.GithubID, &user.GithubLogin, &user.IsTeacher, &user.CreatedAt)

	return user, err
}

func (r *UserRepo) GetByEmail(email string) (*models.User, error) {
	user := &models.User{}
	err := r.db.QueryRow(
		`SELECT id, email, name, password_hash, github_id, github_login, is_teacher, created_at FROM users WHERE email = $1`,
		email,
	).Scan(&user.ID, &user.Email, &user.Name, &user.PasswordHash, &user.GithubID, &user.GithubLogin, &user.IsTeacher, &user.CreatedAt)
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (r *UserRepo) GetByID(id int64) (*models.User, error) {
	user := &models.User{}
	err := r.db.QueryRow(
		`SELECT id, email, name, password_hash, github_id, github_login, is_teacher, created_at FROM users WHERE id = $1`,
		id,
	).Scan(&user.ID, &user.Email, &user.Name, &user.PasswordHash, &user.GithubID, &user.GithubLogin, &user.IsTeacher, &user.CreatedAt)
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (r *UserRepo) GetByGitHubID(githubID int64) (*models.User, error) {
	user := &models.User{}
	err := r.db.QueryRow(
		`SELECT id, email, name, password_hash, github_id, github_login, is_teacher, created_at
		 FROM users WHERE github_id = $1`,
		githubID,
	).Scan(&user.ID, &user.Email, &user.Name, &user.PasswordHash, &user.GithubID, &user.GithubLogin, &user.IsTeacher, &user.CreatedAt)
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (r *UserRepo) UpsertGitHubUser(email, name string, githubID int64, githubLogin string, isTeacher bool) (*models.User, error) {
	user, err := r.GetByGitHubID(githubID)
	if err == nil {
		return user, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}

	userByEmail, err := r.GetByEmail(email)
	if err == nil {
		if _, err := r.db.Exec(
			`UPDATE users
			 SET github_id = $1, github_login = $2, name = COALESCE(NULLIF(name, ''), $3)
			 WHERE id = $4`,
			githubID, githubLogin, name, userByEmail.ID,
		); err != nil {
			return nil, err
		}
		return r.GetByID(userByEmail.ID)
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}

	randomPassword := fmt.Sprintf("oauth-github-%d-%d", githubID, rand.Int63())
	hash, err := bcrypt.GenerateFromPassword([]byte(randomPassword), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	newUser := &models.User{}
	err = r.db.QueryRow(
		`INSERT INTO users (email, name, password_hash, github_id, github_login, is_teacher)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 RETURNING id, email, name, password_hash, github_id, github_login, is_teacher, created_at`,
		email, name, string(hash), githubID, githubLogin, isTeacher,
	).Scan(&newUser.ID, &newUser.Email, &newUser.Name, &newUser.PasswordHash, &newUser.GithubID, &newUser.GithubLogin, &newUser.IsTeacher, &newUser.CreatedAt)
	if err != nil {
		return nil, err
	}

	return newUser, nil
}
