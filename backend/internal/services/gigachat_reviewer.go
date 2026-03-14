package services

import (
	"appraiser/internal/models"
	"bytes"
	"context"
	"crypto/tls"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)


type GigaChatReviewer struct {
	accessToken string
	authKey     string
	authURL     string
	scope       string

	model       string
	baseURL     string
	http        *http.Client

	mu             sync.Mutex
	tokenExpiresAt time.Time
}

func NewGigaChatReviewer() *GigaChatReviewer {
	model := os.Getenv("GIGACHAT_MODEL")
	if strings.TrimSpace(model) == "" {
		model = "GigaChat-2"
	}

	baseURL := os.Getenv("GIGACHAT_BASE_URL")
	if strings.TrimSpace(baseURL) == "" {
		baseURL = "https://gigachat.devices.sberbank.ru/api/v1"
	}

	authURL := os.Getenv("GIGACHAT_AUTH_URL")
	if strings.TrimSpace(authURL) == "" {
		authURL = "https://ngw.devices.sberbank.ru:9443/api/v2/oauth"
	}

	scope := os.Getenv("GIGACHAT_SCOPE")
	if strings.TrimSpace(scope) == "" {
		scope = "GIGACHAT_API_PERS"
	}

	insecureSkipVerify := strings.EqualFold(strings.TrimSpace(os.Getenv("GIGACHAT_INSECURE_SKIP_VERIFY")), "true")
	transport := &http.Transport{}
	if insecureSkipVerify {
		transport.TLSClientConfig = &tls.Config{InsecureSkipVerify: true}
	}

	return &GigaChatReviewer{
		accessToken: os.Getenv("GIGACHAT_ACCESS_TOKEN"),
		authKey:     os.Getenv("GIGACHAT_AUTH_KEY"),
		authURL:     strings.TrimRight(authURL, "/"),
		scope:       scope,
		model:       model,
		baseURL:     strings.TrimRight(baseURL, "/"),
		http: &http.Client{
			Timeout:   90 * time.Second,
			Transport: transport,
		},
		tokenExpiresAt: time.Now().Add(29 * time.Minute),
	}
}

func (g *GigaChatReviewer) Review(ctx context.Context, files []GitHubFile, criteria []models.Criteria) (*ReviewResult, error) {
	prompt := buildPrompt(files, criteria)
	return g.callGigaChat(ctx, prompt, criteria)
}

func (g *GigaChatReviewer) ReviewWithContext(ctx context.Context, rc *ReviewContext, criteria []models.Criteria) (*ReviewResult, error) {
	prompt := buildContextPrompt(rc, criteria)
	return g.callGigaChat(ctx, prompt, criteria)
}

func (g *GigaChatReviewer) callGigaChat(ctx context.Context, prompt string, criteria []models.Criteria) (*ReviewResult, error) {
	token, err := g.getAccessToken(ctx)
	if err != nil {
		return nil, err
	}

	payload := map[string]interface{}{
		"model":       g.model,
		"temperature": 0.2,
		"messages": []map[string]string{
			{"role": "user", "content": prompt},
		},
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshal gigachat request: %w", err)
	}

	url := g.baseURL + "/chat/completions"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create gigachat request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := g.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("calling gigachat: %w", err)
	}
	if resp.StatusCode == http.StatusUnauthorized {
		resp.Body.Close()
		if _, err := g.refreshAccessToken(ctx); err != nil {
			return nil, fmt.Errorf("gigachat unauthorized and refresh failed: %w", err)
		}
		token, err = g.getAccessToken(ctx)
		if err != nil {
			return nil, err
		}
		reqRetry, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
		if err != nil {
			return nil, fmt.Errorf("create gigachat retry request: %w", err)
		}
		reqRetry.Header.Set("Authorization", "Bearer "+token)
		reqRetry.Header.Set("Content-Type", "application/json")
		resp, err = g.http.Do(reqRetry)
		if err != nil {
			return nil, fmt.Errorf("calling gigachat retry: %w", err)
		}
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read gigachat response: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		msg := strings.TrimSpace(string(respBody))
		if len(msg) > 500 {
			msg = msg[:500]
		}
		return nil, fmt.Errorf("gigachat API error (%d): %s", resp.StatusCode, msg)
	}

	var parsed struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(respBody, &parsed); err != nil {
		return nil, fmt.Errorf("parse gigachat response: %w", err)
	}
	if len(parsed.Choices) == 0 || strings.TrimSpace(parsed.Choices[0].Message.Content) == "" {
		return nil, fmt.Errorf("empty response from GigaChat")
	}

	content := parsed.Choices[0].Message.Content
	log.Printf("GigaChat raw response (%d chars): %s", len(content), content)
	return parseReviewResponse(content, criteria)
}

func (g *GigaChatReviewer) getAccessToken(ctx context.Context) (string, error) {
	g.mu.Lock()
	defer g.mu.Unlock()

	now := time.Now()
	if strings.TrimSpace(g.accessToken) != "" && now.Before(g.tokenExpiresAt.Add(-1*time.Minute)) {
		return g.accessToken, nil
	}

	return g.refreshAccessTokenLocked(ctx)
}

func (g *GigaChatReviewer) refreshAccessToken(ctx context.Context) (string, error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	return g.refreshAccessTokenLocked(ctx)
}

func (g *GigaChatReviewer) refreshAccessTokenLocked(ctx context.Context) (string, error) {
	if strings.TrimSpace(g.authKey) == "" {
		if strings.TrimSpace(g.accessToken) != "" {
			return g.accessToken, nil
		}
		return "", fmt.Errorf("GIGACHAT_AUTH_KEY is not set (and no GIGACHAT_ACCESS_TOKEN provided)")
	}

	form := "scope=" + url.QueryEscape(g.scope)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, g.authURL, strings.NewReader(form))
	if err != nil {
		return "", fmt.Errorf("create gigachat auth request: %w", err)
	}
	req.Header.Set("Authorization", basicAuthHeader(g.authKey))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("RqUID", randomRqUID())
	req.Header.Set("Accept", "application/json")

	resp, err := g.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("calling gigachat auth: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read gigachat auth response: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		msg := strings.TrimSpace(string(body))
		if len(msg) > 500 {
			msg = msg[:500]
		}
		return "", fmt.Errorf("gigachat auth error (%d): %s", resp.StatusCode, msg)
	}

	var authResp struct {
		AccessToken string `json:"access_token"`
		ExpiresAt   int64  `json:"expires_at"`
		ExpiresIn   int64  `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &authResp); err != nil {
		return "", fmt.Errorf("parse gigachat auth response: %w", err)
	}
	if strings.TrimSpace(authResp.AccessToken) == "" {
		return "", fmt.Errorf("gigachat auth response has empty access_token")
	}

	g.accessToken = authResp.AccessToken
	g.tokenExpiresAt = calcTokenExpiry(authResp.ExpiresAt, authResp.ExpiresIn)
	return g.accessToken, nil
}

func calcTokenExpiry(expiresAt, expiresIn int64) time.Time {
	now := time.Now()
	if expiresAt > 0 {
		if expiresAt > 1_000_000_000_000 {
			return time.UnixMilli(expiresAt)
		}
		return time.Unix(expiresAt, 0)
	}
	if expiresIn > 0 {
		return now.Add(time.Duration(expiresIn) * time.Second)
	}
	return now.Add(29 * time.Minute)
}

func basicAuthHeader(authKey string) string {
	v := strings.TrimSpace(authKey)
	if strings.HasPrefix(strings.ToLower(v), "basic ") {
		return v
	}
	return "Basic " + v
}

func randomRqUID() string {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Sprintf("rq-%d", time.Now().UnixNano())
	}
	
	buf[6] = (buf[6] & 0x0f) | 0x40
	buf[8] = (buf[8] & 0x3f) | 0x80
	return fmt.Sprintf("%08x-%04x-%04x-%04x-%04x%08x",
		buf[0:4], buf[4:6], buf[6:8], buf[8:10], buf[10:12], buf[12:16])
}
