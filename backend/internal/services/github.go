package services

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)


type GitHubService struct {
	httpClient *http.Client
}

func NewGitHubService() *GitHubService {
	return &GitHubService{httpClient: &http.Client{}}
}


type GitHubFile struct {
	Path    string `json:"path"`
	Content string `json:"content"`
}



func (s *GitHubService) FetchRepoFiles(repoURL string) ([]GitHubFile, error) {
	owner, repo, err := parseGitHubURL(repoURL)
	if err != nil {
		return nil, err
	}

	return s.fetchTree(owner, repo, "main")
}

func parseGitHubURL(url string) (owner, repo string, err error) {
	url = strings.TrimSuffix(url, "/")
	url = strings.TrimSuffix(url, ".git")

	
	parts := strings.Split(url, "/")
	if len(parts) < 2 {
		return "", "", fmt.Errorf("invalid github URL: %s", url)
	}

	return parts[len(parts)-2], parts[len(parts)-1], nil
}

type treeResponse struct {
	Tree []treeEntry `json:"tree"`
}

type treeEntry struct {
	Path string `json:"path"`
	Type string `json:"type"`
	URL  string `json:"url"`
}

type blobResponse struct {
	Content  string `json:"content"`
	Encoding string `json:"encoding"`
}

func (s *GitHubService) fetchTree(owner, repo, branch string) ([]GitHubFile, error) {
	
	branches := []string{branch, "master"}

	for _, b := range branches {
		url := fmt.Sprintf("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1", owner, repo, b)
		resp, err := s.httpClient.Get(url)
		if err != nil {
			continue
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			continue
		}

		var tree treeResponse
		if err := json.NewDecoder(resp.Body).Decode(&tree); err != nil {
			continue
		}

		var files []GitHubFile
		for _, entry := range tree.Tree {
			if entry.Type != "blob" {
				continue
			}
			if !isCodeFile(entry.Path) {
				continue
			}

			content, err := s.fetchFileContent(owner, repo, b, entry.Path)
			if err != nil {
				continue
			}
			files = append(files, GitHubFile{Path: entry.Path, Content: content})
		}

		return files, nil
	}

	return nil, fmt.Errorf("could not access repo %s/%s", owner, repo)
}

func (s *GitHubService) fetchFileContent(owner, repo, branch, path string) (string, error) {
	url := fmt.Sprintf("https://raw.githubusercontent.com/%s/%s/%s/%s", owner, repo, branch, path)
	resp, err := s.httpClient.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("failed to fetch %s: %d", path, resp.StatusCode)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	
	if len(data) > 50*1024 {
		return string(data[:50*1024]) + "\n... (truncated)", nil
	}

	return string(data), nil
}

func isCodeFile(path string) bool {
	extensions := []string{
		".go", ".py", ".js", ".ts", ".java", ".kt", ".dart", ".rs",
		".c", ".cpp", ".h", ".hpp", ".cs", ".rb", ".php", ".swift",
		".html", ".css", ".sql", ".sh", ".yaml", ".yml", ".json",
		".xml", ".md", ".txt", ".toml", ".cfg", ".ini", ".env",
		".dockerfile", ".makefile", ".gradle",
	}

	lower := strings.ToLower(path)

	
	skipPaths := []string{"node_modules/", "vendor/", ".git/", "build/", "dist/", ".idea/"}
	for _, sp := range skipPaths {
		if strings.Contains(lower, sp) {
			return false
		}
	}

	for _, ext := range extensions {
		if strings.HasSuffix(lower, ext) {
			return true
		}
	}

	
	baseName := path
	if idx := strings.LastIndex(path, "/"); idx >= 0 {
		baseName = path[idx+1:]
	}
	configFiles := []string{"Makefile", "Dockerfile", "Jenkinsfile", "Procfile"}
	for _, cf := range configFiles {
		if baseName == cf {
			return true
		}
	}

	return false
}
