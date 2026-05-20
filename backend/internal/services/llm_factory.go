package services

import (
	"context"
	"fmt"
	"strings"
)

const (
	LLMProviderGigaChat = "gigachat"
	LLMProviderGemini   = "gemini"
)

func NormalizeLLMProvider(provider string) string {
	return strings.ToLower(strings.TrimSpace(provider))
}

func NewLLMReviewer(ctx context.Context, provider string) (LLMReviewer, error) {
	switch NormalizeLLMProvider(provider) {
	case LLMProviderGigaChat:
		return NewGigaChatReviewer(), nil
	case LLMProviderGemini:
		return NewGeminiReviewer(ctx)
	default:
		return nil, fmt.Errorf("unsupported llm provider: %s", provider)
	}
}
