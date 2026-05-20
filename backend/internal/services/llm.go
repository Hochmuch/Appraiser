package services

import (
	"appraiser/internal/models"
	"context"
)


type CriteriaResult struct {
	CriteriaID int64   `json:"criteria_id"`
	Score      float64 `json:"score"`
	Comment    string  `json:"comment"`
}


type ReviewResult struct {
	Results  []CriteriaResult `json:"results"`
	Findings []FindingResult  `json:"findings"`
}


type FindingResult struct {
	CriteriaID int64  `json:"criteria_id"`
	FilePath   string `json:"file_path"`
	StartLine  int    `json:"start_line"`
	EndLine    int    `json:"end_line"`
	Severity   string `json:"severity"`
	Title      string `json:"title"`
	Comment    string `json:"comment"`
	Suggestion string `json:"suggestion"`
}


type ReviewContext struct {
	ProjectMap string            
	Summary    string            
	Chunks     []ReviewCodeChunk 
}


type ReviewCodeChunk struct {
	FilePath   string
	Language   string
	StartLine  int
	EndLine    int
	SymbolType string
	SymbolName string
	Content    string
}


type LLMReviewer interface {
	Review(ctx context.Context, files []GitHubFile, criteria []models.Criteria) (*ReviewResult, error)
	ReviewWithContext(ctx context.Context, rc *ReviewContext, criteria []models.Criteria) (*ReviewResult, error)
}
