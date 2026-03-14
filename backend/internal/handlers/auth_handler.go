package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"strconv"
	"net/url"
	"net/http"
	"os"
	"sync"
	"time"

	"appraiser/internal/middleware"
	"appraiser/internal/models"
	"appraiser/internal/repository"

	"golang.org/x/crypto/bcrypt"
)

type AuthHandler struct {
	userRepo *repository.UserRepo
	mu       sync.Mutex
	device   map[string]deviceFlowMeta
}

type deviceFlowMeta struct {
	IsTeacher bool
	ExpiresAt time.Time
}

type githubAccessTokenResponse struct {
	AccessToken      string `json:"access_token"`
	TokenType        string `json:"token_type"`
	Scope            string `json:"scope"`
	Error            string `json:"error"`
	ErrorDescription string `json:"error_description"`
}

type githubUserResponse struct {
	ID    int64  `json:"id"`
	Login string `json:"login"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

type githubEmailResponse struct {
	Email    string `json:"email"`
	Primary  bool   `json:"primary"`
	Verified bool   `json:"verified"`
}

func NewAuthHandler(userRepo *repository.UserRepo) *AuthHandler {
	return &AuthHandler{userRepo: userRepo, device: map[string]deviceFlowMeta{}}
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req models.RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Email == "" || req.Password == "" || req.Name == "" {
		writeError(w, "email, password and name are required", http.StatusBadRequest)
		return
	}

	user, err := h.userRepo.Create(req)
	if err != nil {
		writeError(w, "user already exists or database error", http.StatusConflict)
		return
	}

	token, err := middleware.GenerateToken(user.ID, user.IsTeacher)
	if err != nil {
		writeError(w, "failed to generate token", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, models.LoginResponse{
		Token: token,
		User:  *user,
	})
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req models.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	user, err := h.userRepo.GetByEmail(req.Email)
	if err != nil {
		writeError(w, "invalid email or password", http.StatusUnauthorized)
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		writeError(w, "invalid email or password", http.StatusUnauthorized)
		return
	}

	token, err := middleware.GenerateToken(user.ID, user.IsTeacher)
	if err != nil {
		writeError(w, "failed to generate token", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, models.LoginResponse{
		Token: token,
		User:  *user,
	})
}

func (h *AuthHandler) GitHubDeviceStart(w http.ResponseWriter, r *http.Request) {
	clientID := os.Getenv("GITHUB_CLIENT_ID")
	if clientID == "" {
		writeError(w, "GITHUB_CLIENT_ID is not configured", http.StatusBadRequest)
		return
	}

	var req models.GitHubDeviceStartRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	form := url.Values{}
	form.Set("client_id", clientID)
	form.Set("scope", "read:user user:email")

	startReq, _ := http.NewRequest(
		"POST",
		"https://github.com/login/device/code",
		bytes.NewBufferString(form.Encode()),
	)
	startReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	startReq.Header.Set("Accept", "application/json")

	resp, err := (&http.Client{Timeout: 12 * time.Second}).Do(startReq)
	if err != nil {
		writeError(w, "failed to start github oauth", http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		writeError(w, fmt.Sprintf("github oauth start failed: %s", string(body)), http.StatusBadGateway)
		return
	}

	startResp, err := parseDeviceStartResponse(body)
	if err != nil {
		writeError(w, "failed to parse github oauth response", http.StatusBadGateway)
		return
	}

	h.mu.Lock()
	h.device[startResp.DeviceCode] = deviceFlowMeta{
		IsTeacher: req.IsTeacher,
		ExpiresAt: time.Now().Add(time.Duration(startResp.ExpiresIn) * time.Second),
	}
	h.mu.Unlock()

	writeJSON(w, http.StatusOK, startResp)
}

func (h *AuthHandler) GitHubDevicePoll(w http.ResponseWriter, r *http.Request) {
	clientID := os.Getenv("GITHUB_CLIENT_ID")
	clientSecret := os.Getenv("GITHUB_CLIENT_SECRET")
	if clientID == "" || clientSecret == "" {
		writeError(w, "GITHUB_CLIENT_ID/GITHUB_CLIENT_SECRET are not configured", http.StatusBadRequest)
		return
	}

	var req models.GitHubDevicePollRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if req.DeviceCode == "" {
		writeError(w, "device_code is required", http.StatusBadRequest)
		return
	}

	h.mu.Lock()
	meta, ok := h.device[req.DeviceCode]
	h.mu.Unlock()
	if !ok {
		writeError(w, "unknown device_code", http.StatusBadRequest)
		return
	}
	if time.Now().After(meta.ExpiresAt) {
		h.mu.Lock()
		delete(h.device, req.DeviceCode)
		h.mu.Unlock()
		writeError(w, "device_code expired", http.StatusBadRequest)
		return
	}

	form := url.Values{}
	form.Set("client_id", clientID)
	form.Set("client_secret", clientSecret)
	form.Set("device_code", req.DeviceCode)
	form.Set("grant_type", "urn:ietf:params:oauth:grant-type:device_code")

	pollReq, _ := http.NewRequest(
		"POST",
		"https://github.com/login/oauth/access_token",
		bytes.NewBufferString(form.Encode()),
	)
	pollReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	pollReq.Header.Set("Accept", "application/json")

	resp, err := (&http.Client{Timeout: 12 * time.Second}).Do(pollReq)
	if err != nil {
		writeError(w, "failed to poll github oauth", http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		writeError(w, fmt.Sprintf("github oauth poll failed: %s", string(body)), http.StatusBadGateway)
		return
	}

	tokenResp, err := parseTokenResponse(body)
	if err != nil {
		writeError(w, "failed to parse github token response", http.StatusBadGateway)
		return
	}

	if tokenResp.Error != "" {
		if tokenResp.Error == "authorization_pending" || tokenResp.Error == "slow_down" {
			writeJSON(w, http.StatusAccepted, map[string]bool{"pending": true})
			return
		}
		writeError(w, "github oauth error: "+tokenResp.Error, http.StatusBadRequest)
		return
	}

	ghUser, email, err := h.fetchGitHubUser(tokenResp.AccessToken)
	if err != nil {
		writeError(w, "failed to fetch github profile: "+err.Error(), http.StatusBadGateway)
		return
	}

	name := ghUser.Name
	if name == "" {
		name = ghUser.Login
	}

	user, err := h.userRepo.UpsertGitHubUser(email, name, ghUser.ID, ghUser.Login, meta.IsTeacher)
	if err != nil {
		writeError(w, "failed to login via github: "+err.Error(), http.StatusInternalServerError)
		return
	}

	h.mu.Lock()
	delete(h.device, req.DeviceCode)
	h.mu.Unlock()

	jwtToken, err := middleware.GenerateToken(user.ID, user.IsTeacher)
	if err != nil {
		writeError(w, "failed to generate token", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, models.LoginResponse{Token: jwtToken, User: *user})
}

func parseDeviceStartResponse(body []byte) (models.GitHubDeviceStartResponse, error) {
	var startResp models.GitHubDeviceStartResponse
	if err := json.Unmarshal(body, &startResp); err == nil && startResp.DeviceCode != "" {
		return startResp, nil
	}

	values, err := url.ParseQuery(string(body))
	if err != nil {
		return models.GitHubDeviceStartResponse{}, err
	}

	expiresIn, _ := strconv.Atoi(values.Get("expires_in"))
	interval, _ := strconv.Atoi(values.Get("interval"))
	startResp = models.GitHubDeviceStartResponse{
		DeviceCode:      values.Get("device_code"),
		UserCode:        values.Get("user_code"),
		VerificationURI: values.Get("verification_uri"),
		ExpiresIn:       expiresIn,
		Interval:        interval,
	}
	if startResp.DeviceCode == "" {
		return models.GitHubDeviceStartResponse{}, fmt.Errorf("device_code is missing")
	}
	if startResp.ExpiresIn <= 0 {
		startResp.ExpiresIn = 900
	}
	if startResp.Interval <= 0 {
		startResp.Interval = 5
	}

	return startResp, nil
}

func parseTokenResponse(body []byte) (githubAccessTokenResponse, error) {
	var tokenResp githubAccessTokenResponse
	if err := json.Unmarshal(body, &tokenResp); err == nil && (tokenResp.AccessToken != "" || tokenResp.Error != "") {
		return tokenResp, nil
	}

	values, err := url.ParseQuery(string(body))
	if err != nil {
		return githubAccessTokenResponse{}, err
	}

	tokenResp = githubAccessTokenResponse{
		AccessToken:      values.Get("access_token"),
		TokenType:        values.Get("token_type"),
		Scope:            values.Get("scope"),
		Error:            values.Get("error"),
		ErrorDescription: values.Get("error_description"),
	}

	if tokenResp.AccessToken == "" && tokenResp.Error == "" {
		return githubAccessTokenResponse{}, fmt.Errorf("access_token/error missing")
	}

	return tokenResp, nil
}

func (h *AuthHandler) fetchGitHubUser(accessToken string) (*githubUserResponse, string, error) {
	client := &http.Client{Timeout: 12 * time.Second}

	userReq, _ := http.NewRequest("GET", "https://api.github.com/user", nil)
	userReq.Header.Set("Authorization", "Bearer "+accessToken)
	userReq.Header.Set("Accept", "application/vnd.github+json")
	userReq.Header.Set("User-Agent", "appraiser")

	userResp, err := client.Do(userReq)
	if err != nil {
		return nil, "", err
	}
	defer userResp.Body.Close()

	if userResp.StatusCode < 200 || userResp.StatusCode >= 300 {
		body, _ := io.ReadAll(userResp.Body)
		return nil, "", fmt.Errorf("github /user failed: %s", string(body))
	}

	var ghUser githubUserResponse
	if err := json.NewDecoder(userResp.Body).Decode(&ghUser); err != nil {
		return nil, "", err
	}

	email := ghUser.Email
	if email != "" {
		return &ghUser, email, nil
	}

	emailsReq, _ := http.NewRequest("GET", "https://api.github.com/user/emails", nil)
	emailsReq.Header.Set("Authorization", "Bearer "+accessToken)
	emailsReq.Header.Set("Accept", "application/vnd.github+json")
	emailsReq.Header.Set("User-Agent", "appraiser")

	emailsResp, err := client.Do(emailsReq)
	if err != nil {
		return nil, "", err
	}
	defer emailsResp.Body.Close()

	if emailsResp.StatusCode >= 200 && emailsResp.StatusCode < 300 {
		var emails []githubEmailResponse
		if err := json.NewDecoder(emailsResp.Body).Decode(&emails); err == nil {
			for _, e := range emails {
				if e.Primary && e.Verified {
					return &ghUser, e.Email, nil
				}
			}
			for _, e := range emails {
				if e.Verified {
					return &ghUser, e.Email, nil
				}
			}
			if len(emails) > 0 {
				return &ghUser, emails[0].Email, nil
			}
		}
	}

	return &ghUser, fmt.Sprintf("%s@users.noreply.github.com", ghUser.Login), nil
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func writeError(w http.ResponseWriter, msg string, status int) {
	writeJSON(w, status, models.ErrorResponse{Error: msg})
}
