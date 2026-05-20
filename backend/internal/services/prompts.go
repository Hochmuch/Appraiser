package services

import (
	"appraiser/internal/models"
	"encoding/json"
	"fmt"
	"strings"
)

func buildPrompt(files []GitHubFile, criteria []models.Criteria) string {
	var sb strings.Builder
	sb.WriteString("Ты — опытный IT-эксперт и преподаватель. Твоя задача: провести ревью исходного кода.\n\n")
	sb.WriteString("КРИТЕРИИ ОЦЕНКИ (Оценивай строго по ним):\n")
	for _, c := range criteria {
		sb.WriteString(fmt.Sprintf("- ID: %d, Описание критерия: %s, Максимальный балл: %d\n", c.ID, c.Description, c.MaxScore))
	}

	sb.WriteString("\nФАЙЛЫ ПРОЕКТА:\n")
	for _, f := range files {
		sb.WriteString(fmt.Sprintf("---\nФайл: %s\n%s\n", f.Path, f.Content))
	}

	sb.WriteString("\nПожалуйста, предоставь ответ строго в запрошенном JSON-формате.\n")
	return sb.String()
}

func buildContextPrompt(rc *ReviewContext, criteria []models.Criteria) string {
	var sb strings.Builder
	sb.WriteString("Ты — опытный IT-эксперт и преподаватель. Твоя задача: провести ревью исходного кода.\n\n")

	sb.WriteString("КРИТЕРИИ ОЦЕНКИ (Оценивай строго по ним):\n")
	for _, c := range criteria {
		sb.WriteString(fmt.Sprintf("- ID: %d, Описание критерия: %s, Максимальный балл: %d\n", c.ID, c.Description, c.MaxScore))
	}

	if rc.ProjectMap != "" {
		sb.WriteString("\nСТРУКТУРА ПРОЕКТА (Дерево файлов):\n")
		sb.WriteString(rc.ProjectMap + "\n")
	}

	if rc.Summary != "" {
		sb.WriteString("\nСАММАРИ ПРОЕКТА (Что он делает):\n")
		sb.WriteString(rc.Summary + "\n")
	}

	sb.WriteString("\nФРАГМЕНТЫ КОДА НА ПРОВЕРКУ:\n")
	for _, chunk := range rc.Chunks {
		sb.WriteString(fmt.Sprintf("---\nФайл: %s\nЯзык: %s\nСтроки: %d-%d\n%s\n", chunk.FilePath, chunk.Language, chunk.StartLine, chunk.EndLine, chunk.Content))
	}

	sb.WriteString("\nПРАВИЛА И ТРЕБОВАНИЯ К FINDINGS (КРИТИЧЕСКИ ВАЖНО!):\n")
	sb.WriteString("1. Ты — Senior Software Engineer и безжалостный ревьюер. Оценивай справедливо, но помни, что идеального кода не бывает.\n")
	sb.WriteString("2. Ищи архитектурные ошибки, нарушения SOLID, DRY, KISS, утечки памяти, спагетти-код, отсутствие обработки ошибок, хардкод (magic numbers), избыточную вложенность и плохой нейминг.\n")
	sb.WriteString("3. Ты ОБЯЗАН сгенерировать не менее 4-6 конкретных замечаний (объектов в массиве findings) к участкам кода!\n")
	sb.WriteString("4. Даже если серьезных багов нет, оставляй ревью с уровнем severity: 'info' или 'warning' на места, где возможен рефакторинг или повышение читаемости.\n")
	sb.WriteString("5. Каждый finding ОБЯЗАН содержать в точности тот `file_path`, который находится в ФРАГМЕНТАХ КОДА выше.\n")
	sb.WriteString("6. Номера `start_line` и `end_line` должны математически лежать внутри блоков строк из фрагментов выше.\n")
	sb.WriteString("7. Связывай свои замечания с `criteria_id`. Если ты снижаешь балл в `results`, это должно быть подтверждено соответствующим finding.\n")
	sb.WriteString("8. Поле `score` в массиве `results` ДОЛЖНО БЫТЬ СТРОГО ЦЕЛЫМ ЧИСЛОМ (integer). Никаких дробных значений (например, 1.5 недопустимо, должно быть 1 или 2).\n")

	sb.WriteString("\nПожалуйста, предоставь результат ревью СТРОГО в следующем JSON-формате (без оберток markdown, только чистый JSON):\n")
	sb.WriteString(`{
  "results": [
    {"criteria_id": 1, "score": 10, "comment": "Отличная реализация, архитектура соблюдена."}
  ],
  "findings": [
    {"criteria_id": 1, "file_path": "main.go", "start_line": 10, "end_line": 12, "severity": "warning", "title": "Утечка памяти", "comment": "Здесь возможно переполнение...", "suggestion": "Закройте дескриптор через defer."}
  ]
}`)
	sb.WriteString("\nВЫВЕДИ ТОЛЬКО JSON! Никакого сопроводительного текста.")

	return sb.String()
}

func parseReviewResponse(content string, criteria []models.Criteria) (*ReviewResult, error) {
	content = strings.TrimSpace(content)

	if strings.HasPrefix(content, "```json") {
		content = strings.TrimPrefix(content, "```json")
		content = strings.TrimSuffix(content, "```")
	} else if strings.HasPrefix(content, "```") {
		content = strings.TrimPrefix(content, "```")
		content = strings.TrimSuffix(content, "```")
	}
	content = strings.TrimSpace(content)

	var result ReviewResult
	if err := json.Unmarshal([]byte(content), &result); err != nil {
		return nil, fmt.Errorf("ошибка парсинга JSON от LLM: %w\nСырые данные: %s", err, content)
	}

	return &result, nil
}
