package models

import "time"

type User struct {
	ID           int64     `json:"id"`
	Email        string    `json:"email"`
	Name         string    `json:"name"`
	PasswordHash string    `json:"-"`
	GithubID     *int64    `json:"github_id,omitempty"`
	GithubLogin  string    `json:"github_login,omitempty"`
	Role string `json:"role"`
	CreatedAt    time.Time `json:"created_at"`
}

type Assignment struct {
	ID          int64      `json:"id"`
	TeacherID   int64      `json:"teacher_id"`
	TeacherName string     `json:"teacher_name,omitempty"`
	Title       string     `json:"title"`
	Description string     `json:"description"`
	Criteria    []Criteria `json:"criteria,omitempty"`
	GroupIDs    []int64    `json:"group_ids,omitempty"`
	GroupNames  []string   `json:"group_names,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
}

type Group struct {
	ID         int64         `json:"id"`
	TeacherID  int64         `json:"teacher_id"`
	Name       string        `json:"name"`
	InviteCode string        `json:"invite_code,omitempty"`
	Students   []GroupMember `json:"students,omitempty"`
	CreatedAt  time.Time     `json:"created_at"`
}

type GroupMember struct {
	UserID int64  `json:"user_id"`
	Email  string `json:"email"`
	Name   string `json:"name"`
}

type Criteria struct {
	ID           int64  `json:"id"`
	AssignmentID int64  `json:"assignment_id"`
	Description  string `json:"description"`
	MaxScore     int    `json:"max_score"`
}

type Submission struct {
	ID           int64           `json:"id"`
	AssignmentID int64           `json:"assignment_id"`
	StudentID    int64           `json:"student_id"`
	StudentName  string          `json:"student_name,omitempty"`
	GithubRepo   string          `json:"github_repo"`
	LLMProvider  string          `json:"llm_provider,omitempty"`
	Status       string          `json:"status"` 
	Reviews      []Review        `json:"reviews,omitempty"`
	Findings     []ReviewFinding `json:"findings,omitempty"`
	CreatedAt    time.Time       `json:"created_at"`
}

type ReviewFinding struct {
	ID           int64     `json:"id"`
	ReviewID int64 `json:"review_id"`
	SourceFileID *int64 `json:"source_file_id,omitempty"`
	SourceFilePath string `json:"source_file_path,omitempty"`
	StartLine    int       `json:"start_line"`
	EndLine      int       `json:"end_line"`
	Severity     string    `json:"severity"`
	Title        string    `json:"title"`
	Comment      string    `json:"comment"`
	Suggestion   string    `json:"suggestion,omitempty"`
	Source       string    `json:"source"`
	CreatedAt    time.Time `json:"created_at"`
}

type Review struct {
	ID           int64     `json:"id"`
	SubmissionID int64     `json:"submission_id"`
	CriteriaID   int64     `json:"criteria_id"`
	CriteriaDesc string    `json:"criteria_desc,omitempty"`
	Score        int       `json:"score"`
	MaxScore     int       `json:"max_score,omitempty"`
	Comment      string    `json:"comment"`
	CreatedAt    time.Time `json:"created_at"`
}



type RegisterRequest struct {
	Email     string `json:"email"`
	Password  string `json:"password"`
	Name      string `json:"name"`
	Role     string `json:"role" validate:"required"`
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type LoginResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}

type CreateAssignmentRequest struct {
	Title       string               `json:"title"`
	Description string               `json:"description"`
	Criteria    []CreateCriteriaItem `json:"criteria"`
	GroupIDs    []int64              `json:"group_ids"`
}

type CreateCriteriaItem struct {
	Description string `json:"description"`
	MaxScore    int    `json:"max_score"`
}

type SubmitRequest struct {
	GithubRepo string `json:"github_repo"`
}

type StartReviewRequest struct {
	LLMProvider string `json:"llm_provider"`
}

type CreateGroupRequest struct {
	Name          string   `json:"name"`
	StudentEmails []string `json:"student_emails"`
}

type AddStudentsRequest struct {
	StudentEmails []string `json:"student_emails"`
}

type GitHubDeviceStartRequest struct {
	Role  string `json:"role"`
	Email string `json:"email,omitempty"`
}

type GitHubDeviceStartResponse struct {
	DeviceCode      string `json:"device_code"`
	UserCode        string `json:"user_code"`
	VerificationURI string `json:"verification_uri"`
	ExpiresIn       int    `json:"expires_in"`
	Interval        int    `json:"interval"`
}

type GitHubDevicePollRequest struct {
	DeviceCode string `json:"device_code"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}



type RepoSnapshot struct {
	ID           int64     `json:"id"`
	SubmissionID int64     `json:"submission_id"`
	CommitSHA    string    `json:"commit_sha"`
	Branch       string    `json:"branch"`
	FileCount    int       `json:"file_count"`
	TotalSize    int       `json:"total_size"`
	ProjectMap   string    `json:"project_map"`
	Summary      string    `json:"summary"`
	CreatedAt    time.Time `json:"created_at"`
}

type SourceFile struct {
	ID          int64     `json:"id"`
	SnapshotID  int64     `json:"snapshot_id"`
	FilePath    string    `json:"file_path"`
	Language    string    `json:"language"`
	Size        int       `json:"size"`
	ContentHash string    `json:"content_hash"`
	CreatedAt   time.Time `json:"created_at"`
}

type CodeChunk struct {
	ID            int64     `json:"id"`
	SourceFileID  int64     `json:"source_file_id"`
	SnapshotID    int64     `json:"snapshot_id"`
	ChunkIndex    int       `json:"chunk_index"`
	StartLine     int       `json:"start_line"`
	EndLine       int       `json:"end_line"`
	SymbolType    string    `json:"symbol_type"`
	SymbolName    string    `json:"symbol_name"`
	Content       string    `json:"content"`
	TokenEstimate int       `json:"token_estimate"`
	CreatedAt     time.Time `json:"created_at"`
	
	FilePath string `json:"file_path,omitempty"`
	Language string `json:"language,omitempty"`
}

type ChunkRelation struct {
	ID            int64     `json:"id"`
	SnapshotID    int64     `json:"snapshot_id"`
	SourceChunkID int64     `json:"source_chunk_id"`
	TargetChunkID int64     `json:"target_chunk_id"`
	RelationType  string    `json:"relation_type"`
	CreatedAt     time.Time `json:"created_at"`
}
