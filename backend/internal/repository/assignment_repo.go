package repository

import (
	"database/sql"
	"fmt"

	"appraiser/internal/models"

	"github.com/lib/pq"
)

type AssignmentRepo struct {
	db *sql.DB
}

func NewAssignmentRepo(db *sql.DB) *AssignmentRepo {
	return &AssignmentRepo{db: db}
}

func (r *AssignmentRepo) Create(teacherID int64, req models.CreateAssignmentRequest) (*models.Assignment, error) {
	tx, err := r.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	assignment := &models.Assignment{}
	err = tx.QueryRow(
		`INSERT INTO assignments (teacher_id, title, description)
		 VALUES ($1, $2, $3)
		 RETURNING id, teacher_id, title, description, created_at`,
		teacherID, req.Title, req.Description,
	).Scan(&assignment.ID, &assignment.TeacherID, &assignment.Title, &assignment.Description, &assignment.CreatedAt)
	if err != nil {
		return nil, err
	}

	for _, c := range req.Criteria {
		criteria := models.Criteria{}
		err = tx.QueryRow(
			`INSERT INTO criteria (assignment_id, description, max_score)
			 VALUES ($1, $2, $3)
			 RETURNING id, assignment_id, description, max_score`,
			assignment.ID, c.Description, c.MaxScore,
		).Scan(&criteria.ID, &criteria.AssignmentID, &criteria.Description, &criteria.MaxScore)
		if err != nil {
			return nil, err
		}
		assignment.Criteria = append(assignment.Criteria, criteria)
	}

	for _, groupID := range req.GroupIDs {
		if _, err := tx.Exec(
			`INSERT INTO assignment_groups (assignment_id, group_id)
			 VALUES ($1, $2)
			 ON CONFLICT (assignment_id, group_id) DO NOTHING`,
			assignment.ID, groupID,
		); err != nil {
			return nil, err
		}
		assignment.GroupIDs = append(assignment.GroupIDs, groupID)
	}

	return assignment, tx.Commit()
}

func (r *AssignmentRepo) ListForUser(userID int64, isTeacher bool) ([]models.Assignment, error) {
	var rows *sql.Rows
	var err error

	if isTeacher {
		rows, err = r.db.Query(
			`SELECT a.id, a.teacher_id, u.name, a.title, a.description, a.created_at
			 FROM assignments a
			 JOIN users u ON u.id = a.teacher_id
			 WHERE a.teacher_id = $1
			 ORDER BY a.created_at DESC`,
			userID,
		)
	} else {
		rows, err = r.db.Query(
			`SELECT DISTINCT a.id, a.teacher_id, u.name, a.title, a.description, a.created_at
			 FROM assignments a
			 JOIN users u ON u.id = a.teacher_id
			 JOIN assignment_groups ag ON ag.assignment_id = a.id
			 JOIN group_students gs ON gs.group_id = ag.group_id
			 WHERE gs.student_id = $1
			 ORDER BY a.created_at DESC`,
			userID,
		)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assignments []models.Assignment
	for rows.Next() {
		var a models.Assignment
		if err := rows.Scan(&a.ID, &a.TeacherID, &a.TeacherName, &a.Title, &a.Description, &a.CreatedAt); err != nil {
			return nil, err
		}
		a.GroupIDs, _ = r.GetGroupIDs(a.ID)
		a.GroupNames, _ = r.GetGroupNames(a.ID)
		assignments = append(assignments, a)
	}
	return assignments, rows.Err()
}

func (r *AssignmentRepo) GetByIDForUser(id, userID int64, isTeacher bool) (*models.Assignment, error) {
	a := &models.Assignment{}
	var err error

	if isTeacher {
		err = r.db.QueryRow(
			`SELECT a.id, a.teacher_id, u.name, a.title, a.description, a.created_at
			 FROM assignments a
			 JOIN users u ON u.id = a.teacher_id
			 WHERE a.id = $1 AND a.teacher_id = $2`,
			id, userID,
		).Scan(&a.ID, &a.TeacherID, &a.TeacherName, &a.Title, &a.Description, &a.CreatedAt)
	} else {
		err = r.db.QueryRow(
			`SELECT DISTINCT a.id, a.teacher_id, u.name, a.title, a.description, a.created_at
			 FROM assignments a
			 JOIN users u ON u.id = a.teacher_id
			 JOIN assignment_groups ag ON ag.assignment_id = a.id
			 JOIN group_students gs ON gs.group_id = ag.group_id
			 WHERE a.id = $1 AND gs.student_id = $2`,
			id, userID,
		).Scan(&a.ID, &a.TeacherID, &a.TeacherName, &a.Title, &a.Description, &a.CreatedAt)
	}

	if err != nil {
		return nil, err
	}

	a.Criteria, err = r.GetCriteria(id)
	if err != nil {
		return nil, err
	}

	a.GroupIDs, _ = r.GetGroupIDs(id)
	a.GroupNames, _ = r.GetGroupNames(id)

	return a, nil
}

func (r *AssignmentRepo) StudentHasAccess(assignmentID, studentID int64) (bool, error) {
	var count int
	err := r.db.QueryRow(
		`SELECT COUNT(*)
		 FROM assignment_groups ag
		 JOIN group_students gs ON gs.group_id = ag.group_id
		 WHERE ag.assignment_id = $1 AND gs.student_id = $2`,
		assignmentID, studentID,
	).Scan(&count)
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

func (r *AssignmentRepo) GetGroupIDs(assignmentID int64) ([]int64, error) {
	rows, err := r.db.Query(
		`SELECT group_id FROM assignment_groups WHERE assignment_id = $1 ORDER BY group_id`,
		assignmentID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var groupIDs []int64
	for rows.Next() {
		var groupID int64
		if err := rows.Scan(&groupID); err != nil {
			return nil, err
		}
		groupIDs = append(groupIDs, groupID)
	}
	return groupIDs, rows.Err()
}

func (r *AssignmentRepo) GetGroupNames(assignmentID int64) ([]string, error) {
	rows, err := r.db.Query(
		`SELECT g.name
		 FROM assignment_groups ag
		 JOIN groups g ON g.id = ag.group_id
		 WHERE ag.assignment_id = $1
		 ORDER BY g.name`,
		assignmentID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var names []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		names = append(names, name)
	}

	return names, rows.Err()
}

func (r *AssignmentRepo) ValidateGroupsForTeacher(teacherID int64, groupIDs []int64) (bool, error) {
	if len(groupIDs) == 0 {
		return false, nil
	}

	var count int
	err := r.db.QueryRow(
		`SELECT COUNT(*) FROM groups WHERE teacher_id = $1 AND id = ANY($2)`,
		teacherID, pq.Array(groupIDs),
	).Scan(&count)
	if err != nil {
		return false, err
	}

	return count == len(groupIDs), nil
}

func (r *AssignmentRepo) Update(assignmentID, teacherID int64, req models.CreateAssignmentRequest) (*models.Assignment, error) {
	tx, err := r.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	
	var ownerID int64
	err = tx.QueryRow(`SELECT teacher_id FROM assignments WHERE id = $1`, assignmentID).Scan(&ownerID)
	if err != nil {
		return nil, err
	}
	if ownerID != teacherID {
		return nil, fmt.Errorf("not the owner of this assignment")
	}

	
	a := &models.Assignment{}
	err = tx.QueryRow(
		`UPDATE assignments SET title = $1, description = $2
		 WHERE id = $3
		 RETURNING id, teacher_id, title, description, created_at`,
		req.Title, req.Description, assignmentID,
	).Scan(&a.ID, &a.TeacherID, &a.Title, &a.Description, &a.CreatedAt)
	if err != nil {
		return nil, err
	}

	
	_, err = tx.Exec(
		`DELETE FROM review_findings WHERE submission_id IN (
			SELECT id FROM submissions WHERE assignment_id = $1
		)`, assignmentID)
	if err != nil {
		return nil, err
	}
	_, err = tx.Exec(
		`DELETE FROM reviews WHERE criteria_id IN (
			SELECT id FROM criteria WHERE assignment_id = $1
		)`, assignmentID)
	if err != nil {
		return nil, err
	}
	_, err = tx.Exec(`DELETE FROM criteria WHERE assignment_id = $1`, assignmentID)
	if err != nil {
		return nil, err
	}
	for _, c := range req.Criteria {
		criteria := models.Criteria{}
		err = tx.QueryRow(
			`INSERT INTO criteria (assignment_id, description, max_score)
			 VALUES ($1, $2, $3)
			 RETURNING id, assignment_id, description, max_score`,
			assignmentID, c.Description, c.MaxScore,
		).Scan(&criteria.ID, &criteria.AssignmentID, &criteria.Description, &criteria.MaxScore)
		if err != nil {
			return nil, err
		}
		a.Criteria = append(a.Criteria, criteria)
	}

	
	_, err = tx.Exec(`DELETE FROM assignment_groups WHERE assignment_id = $1`, assignmentID)
	if err != nil {
		return nil, err
	}
	for _, groupID := range req.GroupIDs {
		if _, err := tx.Exec(
			`INSERT INTO assignment_groups (assignment_id, group_id)
			 VALUES ($1, $2)`,
			assignmentID, groupID,
		); err != nil {
			return nil, err
		}
		a.GroupIDs = append(a.GroupIDs, groupID)
	}

	return a, tx.Commit()
}

func (r *AssignmentRepo) GetCriteria(assignmentID int64) ([]models.Criteria, error) {
	rows, err := r.db.Query(
		`SELECT id, assignment_id, description, max_score FROM criteria WHERE assignment_id = $1`,
		assignmentID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var criteria []models.Criteria
	for rows.Next() {
		var c models.Criteria
		if err := rows.Scan(&c.ID, &c.AssignmentID, &c.Description, &c.MaxScore); err != nil {
			return nil, err
		}
		criteria = append(criteria, c)
	}
	return criteria, rows.Err()
}
