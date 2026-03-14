package repository

import (
	"database/sql"

	"appraiser/internal/models"
)

type SubmissionRepo struct {
	db *sql.DB
}

func NewSubmissionRepo(db *sql.DB) *SubmissionRepo {
	return &SubmissionRepo{db: db}
}

func (r *SubmissionRepo) Create(assignmentID, studentID int64, githubRepo string) (*models.Submission, error) {
	s := &models.Submission{}
	err := r.db.QueryRow(
		`INSERT INTO submissions (assignment_id, student_id, github_repo, status)
		 VALUES ($1, $2, $3, 'pending')
		 ON CONFLICT (assignment_id, student_id) DO UPDATE SET github_repo = $3, status = 'pending'
		 RETURNING id, assignment_id, student_id, github_repo, status, created_at`,
		assignmentID, studentID, githubRepo,
	).Scan(&s.ID, &s.AssignmentID, &s.StudentID, &s.GithubRepo, &s.Status, &s.CreatedAt)
	return s, err
}

func (r *SubmissionRepo) GetByID(id int64) (*models.Submission, error) {
	s := &models.Submission{}
	err := r.db.QueryRow(
		`SELECT s.id, s.assignment_id, s.student_id, u.name, s.github_repo, s.status, s.created_at
		 FROM submissions s
		 JOIN users u ON u.id = s.student_id
		 WHERE s.id = $1`,
		id,
	).Scan(&s.ID, &s.AssignmentID, &s.StudentID, &s.StudentName, &s.GithubRepo, &s.Status, &s.CreatedAt)
	if err != nil {
		return nil, err
	}
	return s, err
}

func (r *SubmissionRepo) ListByAssignment(assignmentID int64) ([]models.Submission, error) {
	rows, err := r.db.Query(
		`SELECT s.id, s.assignment_id, s.student_id, u.name, s.github_repo, s.status, s.created_at
		 FROM submissions s
		 JOIN users u ON u.id = s.student_id
		 WHERE s.assignment_id = $1
		 ORDER BY s.created_at DESC`,
		assignmentID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var submissions []models.Submission
	for rows.Next() {
		var s models.Submission
		if err := rows.Scan(&s.ID, &s.AssignmentID, &s.StudentID, &s.StudentName, &s.GithubRepo, &s.Status, &s.CreatedAt); err != nil {
			return nil, err
		}
		submissions = append(submissions, s)
	}
	return submissions, rows.Err()
}

func (r *SubmissionRepo) ListByStudent(studentID int64) ([]models.Submission, error) {
	rows, err := r.db.Query(
		`SELECT s.id, s.assignment_id, s.student_id, u.name, s.github_repo, s.status, s.created_at
		 FROM submissions s
		 JOIN users u ON u.id = s.student_id
		 WHERE s.student_id = $1
		 ORDER BY s.created_at DESC`,
		studentID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var submissions []models.Submission
	for rows.Next() {
		var s models.Submission
		if err := rows.Scan(&s.ID, &s.AssignmentID, &s.StudentID, &s.StudentName, &s.GithubRepo, &s.Status, &s.CreatedAt); err != nil {
			return nil, err
		}
		submissions = append(submissions, s)
	}
	return submissions, rows.Err()
}

func (r *SubmissionRepo) UpdateStatus(id int64, status string) error {
	_, err := r.db.Exec(`UPDATE submissions SET status = $1 WHERE id = $2`, status, id)
	return err
}

func (r *SubmissionRepo) ClearReviewData(submissionID int64) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.Exec(`DELETE FROM review_findings WHERE submission_id = $1`, submissionID); err != nil {
		return err
	}
	if _, err := tx.Exec(`DELETE FROM reviews WHERE submission_id = $1`, submissionID); err != nil {
		return err
	}

	return tx.Commit()
}

func (r *SubmissionRepo) SaveReview(review *models.Review) error {
	return r.db.QueryRow(
		`INSERT INTO reviews (submission_id, criteria_id, score, comment)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (submission_id, criteria_id) DO UPDATE SET score = $3, comment = $4
		 RETURNING id, created_at`,
		review.SubmissionID, review.CriteriaID, review.Score, review.Comment,
	).Scan(&review.ID, &review.CreatedAt)
}

func (r *SubmissionRepo) GetReviews(submissionID int64) ([]models.Review, error) {
	rows, err := r.db.Query(
		`SELECT r.id, r.submission_id, r.criteria_id, c.description, r.score, c.max_score, r.comment, r.created_at
		 FROM reviews r
		 JOIN criteria c ON c.id = r.criteria_id
		 WHERE r.submission_id = $1
		 ORDER BY c.id`,
		submissionID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reviews []models.Review
	for rows.Next() {
		var rv models.Review
		if err := rows.Scan(&rv.ID, &rv.SubmissionID, &rv.CriteriaID, &rv.CriteriaDesc, &rv.Score, &rv.MaxScore, &rv.Comment, &rv.CreatedAt); err != nil {
			return nil, err
		}
		reviews = append(reviews, rv)
	}
	return reviews, rows.Err()
}

func (r *SubmissionRepo) ReplaceFindings(submissionID int64, findings []models.ReviewFinding) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.Exec(`DELETE FROM review_findings WHERE submission_id = $1`, submissionID); err != nil {
		return err
	}

	for i := range findings {
		f := &findings[i]
		if err := tx.QueryRow(
			`INSERT INTO review_findings (submission_id, criteria_id, file_path, start_line, end_line, severity, title, comment, suggestion, source)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
			 RETURNING id, created_at`,
			f.SubmissionID, f.CriteriaID, f.FilePath, f.StartLine, f.EndLine, f.Severity, f.Title, f.Comment, f.Suggestion, f.Source,
		).Scan(&f.ID, &f.CreatedAt); err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (r *SubmissionRepo) GetFindings(submissionID int64) ([]models.ReviewFinding, error) {
	rows, err := r.db.Query(
		`SELECT id, submission_id, criteria_id, file_path, start_line, end_line, severity, title, comment, suggestion, source, created_at
		 FROM review_findings
		 WHERE submission_id = $1
		 ORDER BY id`,
		submissionID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var findings []models.ReviewFinding
	for rows.Next() {
		var f models.ReviewFinding
		if err := rows.Scan(
			&f.ID,
			&f.SubmissionID,
			&f.CriteriaID,
			&f.FilePath,
			&f.StartLine,
			&f.EndLine,
			&f.Severity,
			&f.Title,
			&f.Comment,
			&f.Suggestion,
			&f.Source,
			&f.CreatedAt,
		); err != nil {
			return nil, err
		}
		findings = append(findings, f)
	}

	return findings, rows.Err()
}
