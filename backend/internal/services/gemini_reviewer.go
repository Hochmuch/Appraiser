package services

import (
	"appraiser/internal/models"
	"context"
	"fmt"
	"os"

	"google.golang.org/genai"
)

type GeminiReviewer struct {
	client *genai.Client
}

func NewGeminiReviewer(ctx context.Context) (*GeminiReviewer, error) {
	client, err := genai.NewClient(ctx, nil)
	if err != nil {
		return nil, err
	}
	return &GeminiReviewer{client: client}, nil
}

func (r *GeminiReviewer) Review(ctx context.Context, files []GitHubFile, criteria []models.Criteria) (*ReviewResult, error) {
	prompt := buildPrompt(files, criteria)
	return r.callGemini(ctx, prompt, criteria)
}

func (r *GeminiReviewer) ReviewWithContext(ctx context.Context, rc *ReviewContext, criteria []models.Criteria) (*ReviewResult, error) {
	prompt := buildContextPrompt(rc, criteria)
	return r.callGemini(ctx, prompt, criteria)
}

func (r *GeminiReviewer) callGemini(ctx context.Context, prompt string, criteria []models.Criteria) (*ReviewResult, error) {
	model := os.Getenv("GEMINI_MODEL")
	if model == "" {
		model = "gemini-3.1-flash-lite"
	}

	resp, err := r.client.Models.GenerateContent(ctx, model, genai.Text(prompt), nil)
	if err != nil {
		return nil, fmt.Errorf("ошибка генерации ответа Gemini: %w", err)
	}

	text := resp.Text()
	
	if text == "" {
		return nil, fmt.Errorf("пустой ответ от Gemini")
	}

	return parseReviewResponse(text, criteria)
}