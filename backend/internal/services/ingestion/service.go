package ingestion

import (
	"crypto/sha256"
	"fmt"
	"log"
	"path/filepath"
	"sort"
	"strings"

	"appraiser/internal/models"
	"appraiser/internal/repository"
	"appraiser/internal/services"
)


type Service struct {
	github       *services.GitHubService
	snapshotRepo *repository.SnapshotRepo
}

func NewService(gh *services.GitHubService, sr *repository.SnapshotRepo) *Service {
	return &Service{github: gh, snapshotRepo: sr}
}


type IngestResult struct {
	Snapshot *models.RepoSnapshot
	Files    []services.GitHubFile 
	Chunks   []models.CodeChunk
}


func (s *Service) Ingest(submissionID int64, repoURL string) (*IngestResult, error) {
	
	files, err := s.github.FetchRepoFiles(repoURL)
	if err != nil {
		return nil, fmt.Errorf("fetching repo: %w", err)
	}
	if len(files) == 0 {
		return nil, fmt.Errorf("no files found in repo")
	}

	
	totalSize := 0
	for _, f := range files {
		totalSize += len(f.Content)
	}

	snapshot := &models.RepoSnapshot{
		SubmissionID: submissionID,
		Branch:       "main",
		FileCount:    len(files),
		TotalSize:    totalSize,
	}
	if err := s.snapshotRepo.CreateSnapshot(snapshot); err != nil {
		return nil, fmt.Errorf("creating snapshot: %w", err)
	}

	
	s.snapshotRepo.DeleteSnapshotData(snapshot.ID)

	
	snapshot.ProjectMap = buildProjectMap(files)

	
	var allChunks []models.CodeChunk
	for _, f := range files {
		lang := detectLanguage(f.Path)
		hash := fmt.Sprintf("%x", sha256.Sum256([]byte(f.Content)))

		sf := &models.SourceFile{
			SnapshotID:  snapshot.ID,
			FilePath:    f.Path,
			Language:    lang,
			Size:        len(f.Content),
			ContentHash: hash,
		}
		if err := s.snapshotRepo.InsertSourceFile(sf); err != nil {
			log.Printf("ingestion: failed to store file %s: %v", f.Path, err)
			continue
		}

		
		chunks := chunkFile(sf, f.Content, snapshot.ID)
		for i := range chunks {
			chunks[i].FilePath = sf.FilePath
			chunks[i].Language = sf.Language
			if err := s.snapshotRepo.InsertChunk(&chunks[i]); err != nil {
				log.Printf("ingestion: failed to store chunk %s#%d: %v", f.Path, i, err)
				continue
			}
			allChunks = append(allChunks, chunks[i])
		}
	}

	
	snapshot.Summary = buildSummary(files, allChunks)

	
	s.snapshotRepo.CreateSnapshot(snapshot)

	return &IngestResult{
		Snapshot: snapshot,
		Files:    files,
		Chunks:   allChunks,
	}, nil
}




type treeNode struct {
	name     string
	children map[string]*treeNode 
	files    []string             
}

func newTreeNode(name string) *treeNode {
	return &treeNode{name: name, children: make(map[string]*treeNode)}
}

func buildProjectMap(files []services.GitHubFile) string {
	root := newTreeNode(".")

	for _, f := range files {
		parts := strings.Split(f.Path, "/")
		cur := root
		for i, p := range parts {
			if i == len(parts)-1 {
				
				cur.files = append(cur.files, p)
			} else {
				child, ok := cur.children[p]
				if !ok {
					child = newTreeNode(p)
					cur.children[p] = child
				}
				cur = child
			}
		}
	}

	var sb strings.Builder
	renderTree(&sb, root, "", true)
	return sb.String()
}


func renderTree(sb *strings.Builder, node *treeNode, prefix string, isRoot bool) {
	
	type entry struct {
		name  string
		isDir bool
		node  *treeNode
	}
	var entries []entry

	dirNames := make([]string, 0, len(node.children))
	for k := range node.children {
		dirNames = append(dirNames, k)
	}
	sort.Strings(dirNames)
	for _, d := range dirNames {
		entries = append(entries, entry{name: d, isDir: true, node: node.children[d]})
	}

	sort.Strings(node.files)
	for _, f := range node.files {
		entries = append(entries, entry{name: f, isDir: false})
	}

	for i, e := range entries {
		isLast := i == len(entries)-1
		connector := "├── "
		childPrefix := "│   "
		if isLast {
			connector = "└── "
			childPrefix = "    "
		}

		if e.isDir {
			sb.WriteString(fmt.Sprintf("%s%s%s/\n", prefix, connector, e.name))
			renderTree(sb, e.node, prefix+childPrefix, false)
		} else {
			sb.WriteString(fmt.Sprintf("%s%s%s\n", prefix, connector, e.name))
		}
	}
}

func buildSummary(files []services.GitHubFile, chunks []models.CodeChunk) string {
	var sb strings.Builder
	sb.WriteString("## Repository Summary\n\n")

	
	langCount := make(map[string]int)
	for _, f := range files {
		lang := detectLanguage(f.Path)
		if lang != "" {
			langCount[lang]++
		}
	}

	sb.WriteString("Languages:\n")
	for lang, count := range langCount {
		sb.WriteString(fmt.Sprintf("  %s: %d files\n", lang, count))
	}

	sb.WriteString(fmt.Sprintf("\nTotal files: %d\n", len(files)))
	sb.WriteString(fmt.Sprintf("Total chunks: %d\n", len(chunks)))

	
	sb.WriteString("\nKey files:\n")
	keyPatterns := []string{"main.", "app.", "index.", "server.", "config.", "docker", "makefile", "readme", "go.mod", "pubspec", "package.json"}
	for _, f := range files {
		lower := strings.ToLower(filepath.Base(f.Path))
		for _, pat := range keyPatterns {
			if strings.Contains(lower, pat) {
				sb.WriteString(fmt.Sprintf("  %s\n", f.Path))
				break
			}
		}
	}

	return sb.String()
}



func detectLanguage(path string) string {
	ext := strings.ToLower(filepath.Ext(path))
	switch ext {
	case ".go":
		return "go"
	case ".py":
		return "python"
	case ".js":
		return "javascript"
	case ".ts":
		return "typescript"
	case ".java":
		return "java"
	case ".kt":
		return "kotlin"
	case ".dart":
		return "dart"
	case ".rs":
		return "rust"
	case ".c", ".h":
		return "c"
	case ".cpp", ".hpp", ".cc":
		return "cpp"
	case ".cs":
		return "csharp"
	case ".rb":
		return "ruby"
	case ".php":
		return "php"
	case ".swift":
		return "swift"
	case ".html":
		return "html"
	case ".css":
		return "css"
	case ".sql":
		return "sql"
	case ".sh":
		return "shell"
	case ".yaml", ".yml":
		return "yaml"
	case ".json":
		return "json"
	case ".xml":
		return "xml"
	case ".md":
		return "markdown"
	case ".toml":
		return "toml"
	default:
		return ""
	}
}






func chunkFile(sf *models.SourceFile, content string, snapshotID int64) []models.CodeChunk {
	lines := strings.Split(content, "\n")
	if len(lines) == 0 {
		return nil
	}

	
	if len(lines) <= 60 {
		return []models.CodeChunk{{
			SourceFileID:  sf.ID,
			SnapshotID:    snapshotID,
			ChunkIndex:    0,
			StartLine:     1,
			EndLine:       len(lines),
			SymbolType:    "file",
			SymbolName:    filepath.Base(sf.FilePath),
			Content:       content,
			TokenEstimate: estimateTokens(content),
		}}
	}

	
	switch sf.Language {
	case "go", "java", "kotlin", "dart", "javascript", "typescript", "c", "cpp", "csharp", "rust", "swift", "php":
		chunks := splitBraceLang(sf, lines, snapshotID)
		if len(chunks) > 0 {
			return chunks
		}
	case "python", "ruby":
		chunks := splitIndentLang(sf, lines, snapshotID)
		if len(chunks) > 0 {
			return chunks
		}
	}

	
	return splitByLines(sf, lines, snapshotID, 50, 10)
}


func splitBraceLang(sf *models.SourceFile, lines []string, snapshotID int64) []models.CodeChunk {
	type boundary struct {
		line       int
		symbolType string
		symbolName string
	}

	var boundaries []boundary
	braceDepth := 0

	for i, line := range lines {
		trimmed := strings.TrimSpace(line)

		
		braceDepth += strings.Count(trimmed, "{") - strings.Count(trimmed, "}")

		
		if braceDepth <= 1 {
			if isTopLevelDecl(trimmed, sf.Language) {
				name := extractSymbolName(trimmed, sf.Language)
				stype := "function"
				if isClassLike(trimmed, sf.Language) {
					stype = "class"
				}
				boundaries = append(boundaries, boundary{line: i, symbolType: stype, symbolName: name})
			}
		}
	}

	if len(boundaries) == 0 {
		return nil
	}

	
	var chunks []models.CodeChunk
	for i, b := range boundaries {
		startLine := b.line
		var endLine int
		if i+1 < len(boundaries) {
			endLine = boundaries[i+1].line - 1
		} else {
			endLine = len(lines) - 1
		}

		
		contextStart := startLine
		if i == 0 {
			contextStart = 0 
		}

		chunkContent := strings.Join(lines[contextStart:endLine+1], "\n")
		chunks = append(chunks, models.CodeChunk{
			SourceFileID:  sf.ID,
			SnapshotID:    snapshotID,
			ChunkIndex:    i,
			StartLine:     contextStart + 1,
			EndLine:       endLine + 1,
			SymbolType:    b.symbolType,
			SymbolName:    b.symbolName,
			Content:       chunkContent,
			TokenEstimate: estimateTokens(chunkContent),
		})
	}

	return chunks
}


func splitIndentLang(sf *models.SourceFile, lines []string, snapshotID int64) []models.CodeChunk {
	type boundary struct {
		line       int
		symbolType string
		symbolName string
	}

	var boundaries []boundary
	for i, line := range lines {
		if len(line) == 0 || line[0] == ' ' || line[0] == '\t' || line[0] == '#' {
			continue
		}
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "def ") || strings.HasPrefix(trimmed, "class ") ||
			strings.HasPrefix(trimmed, "async def ") {
			stype := "function"
			name := ""
			if strings.HasPrefix(trimmed, "class ") {
				stype = "class"
				name = strings.TrimPrefix(trimmed, "class ")
			} else if strings.HasPrefix(trimmed, "async def ") {
				name = strings.TrimPrefix(trimmed, "async def ")
			} else {
				name = strings.TrimPrefix(trimmed, "def ")
			}
			if idx := strings.IndexAny(name, "(: "); idx > 0 {
				name = name[:idx]
			}
			boundaries = append(boundaries, boundary{line: i, symbolType: stype, symbolName: name})
		}
	}

	if len(boundaries) == 0 {
		return nil
	}

	var chunks []models.CodeChunk
	for i, b := range boundaries {
		startLine := b.line
		var endLine int
		if i+1 < len(boundaries) {
			endLine = boundaries[i+1].line - 1
		} else {
			endLine = len(lines) - 1
		}
		contextStart := startLine
		if i == 0 {
			contextStart = 0
		}

		chunkContent := strings.Join(lines[contextStart:endLine+1], "\n")
		chunks = append(chunks, models.CodeChunk{
			SourceFileID:  sf.ID,
			SnapshotID:    snapshotID,
			ChunkIndex:    i,
			StartLine:     contextStart + 1,
			EndLine:       endLine + 1,
			SymbolType:    b.symbolType,
			SymbolName:    b.symbolName,
			Content:       chunkContent,
			TokenEstimate: estimateTokens(chunkContent),
		})
	}
	return chunks
}


func splitByLines(sf *models.SourceFile, lines []string, snapshotID int64, chunkSize, overlap int) []models.CodeChunk {
	var chunks []models.CodeChunk
	idx := 0
	for start := 0; start < len(lines); start += chunkSize - overlap {
		end := start + chunkSize
		if end > len(lines) {
			end = len(lines)
		}

		chunkContent := strings.Join(lines[start:end], "\n")
		chunks = append(chunks, models.CodeChunk{
			SourceFileID:  sf.ID,
			SnapshotID:    snapshotID,
			ChunkIndex:    idx,
			StartLine:     start + 1,
			EndLine:       end,
			SymbolType:    "block",
			SymbolName:    fmt.Sprintf("lines_%d_%d", start+1, end),
			Content:       chunkContent,
			TokenEstimate: estimateTokens(chunkContent),
		})
		idx++

		if end >= len(lines) {
			break
		}
	}
	return chunks
}



func isTopLevelDecl(line, lang string) bool {
	switch lang {
	case "go":
		return strings.HasPrefix(line, "func ") || strings.HasPrefix(line, "type ")
	case "java", "kotlin":
		return strings.Contains(line, "class ") || strings.Contains(line, "interface ") ||
			(strings.Contains(line, "(") && !strings.HasPrefix(line, "//") && !strings.HasPrefix(line, "*") && !strings.HasPrefix(line, "import"))
	case "dart":
		return strings.HasPrefix(line, "class ") || strings.HasPrefix(line, "mixin ") ||
			(strings.Contains(line, "(") && !strings.HasPrefix(line, "//") && !strings.HasPrefix(line, "import"))
	case "javascript", "typescript":
		return strings.HasPrefix(line, "function ") || strings.HasPrefix(line, "class ") ||
			strings.HasPrefix(line, "export ") || strings.HasPrefix(line, "const ") ||
			strings.HasPrefix(line, "async function ")
	case "c", "cpp", "csharp":
		return strings.Contains(line, "(") && !strings.HasPrefix(line, "//") && !strings.HasPrefix(line, "#")
	case "rust":
		return strings.HasPrefix(line, "fn ") || strings.HasPrefix(line, "pub fn ") ||
			strings.HasPrefix(line, "struct ") || strings.HasPrefix(line, "impl ") ||
			strings.HasPrefix(line, "pub struct ")
	case "swift":
		return strings.HasPrefix(line, "func ") || strings.HasPrefix(line, "class ") ||
			strings.HasPrefix(line, "struct ")
	case "php":
		return strings.HasPrefix(line, "function ") || strings.HasPrefix(line, "class ") ||
			strings.HasPrefix(line, "public function ") || strings.HasPrefix(line, "private function ")
	}
	return false
}

func isClassLike(line, lang string) bool {
	return strings.Contains(line, "class ") || strings.Contains(line, "struct ") ||
		strings.Contains(line, "interface ") || strings.Contains(line, "mixin ") ||
		strings.Contains(line, "impl ")
}

func extractSymbolName(line, lang string) string {
	
	keywords := []string{"func ", "function ", "class ", "struct ", "type ", "def ",
		"pub fn ", "fn ", "impl ", "mixin ", "interface ", "async function ",
		"export function ", "export default function ", "export class ",
		"public function ", "private function "}

	for _, kw := range keywords {
		if idx := strings.Index(line, kw); idx >= 0 {
			rest := line[idx+len(kw):]
			if end := strings.IndexAny(rest, "({ <:"); end > 0 {
				return strings.TrimSpace(rest[:end])
			}
			if end := strings.IndexAny(rest, " \t"); end > 0 {
				return strings.TrimSpace(rest[:end])
			}
			return strings.TrimSpace(rest)
		}
	}

	return ""
}

func estimateTokens(content string) int {
	
	return len(content) / 4
}
