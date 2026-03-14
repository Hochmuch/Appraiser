package repository

import (
	"database/sql"
	"fmt"

	"appraiser/internal/models"

	"github.com/lib/pq"
)

type GroupRepo struct {
	db *sql.DB
}

func NewGroupRepo(db *sql.DB) *GroupRepo {
	return &GroupRepo{db: db}
}

func (r *GroupRepo) Create(teacherID int64, req models.CreateGroupRequest) (*models.Group, error) {
	tx, err := r.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	group := &models.Group{}
	if err := tx.QueryRow(
		`INSERT INTO groups (teacher_id, name)
		 VALUES ($1, $2)
		 RETURNING id, teacher_id, name, created_at`,
		teacherID, req.Name,
	).Scan(&group.ID, &group.TeacherID, &group.Name, &group.CreatedAt); err != nil {
		return nil, err
	}

	for _, email := range req.StudentEmails {
		var userID int64
		var name string
		if err := tx.QueryRow(
			`SELECT id, name FROM users WHERE email = $1 AND is_teacher = FALSE`,
			email,
		).Scan(&userID, &name); err != nil {
			if err == sql.ErrNoRows {
				return nil, fmt.Errorf("student with email %s not found", email)
			}
			return nil, err
		}

		if _, err := tx.Exec(
			`INSERT INTO group_students (group_id, student_id)
			 VALUES ($1, $2)
			 ON CONFLICT (group_id, student_id) DO NOTHING`,
			group.ID, userID,
		); err != nil {
			return nil, err
		}

		group.Students = append(group.Students, models.GroupMember{
			UserID: userID,
			Email:  email,
			Name:   name,
		})
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}

	return group, nil
}

func (r *GroupRepo) ListByTeacher(teacherID int64) ([]models.Group, error) {
	rows, err := r.db.Query(
		`SELECT id, teacher_id, name, created_at
		 FROM groups
		 WHERE teacher_id = $1
		 ORDER BY created_at DESC`,
		teacherID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var groups []models.Group
	for rows.Next() {
		var g models.Group
		if err := rows.Scan(&g.ID, &g.TeacherID, &g.Name, &g.CreatedAt); err != nil {
			return nil, err
		}

		students, err := r.GetStudents(g.ID)
		if err != nil {
			return nil, err
		}
		g.Students = students
		groups = append(groups, g)
	}

	return groups, rows.Err()
}

func (r *GroupRepo) GetStudents(groupID int64) ([]models.GroupMember, error) {
	rows, err := r.db.Query(
		`SELECT u.id, u.email, u.name
		 FROM group_students gs
		 JOIN users u ON u.id = gs.student_id
		 WHERE gs.group_id = $1
		 ORDER BY u.name`,
		groupID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []models.GroupMember
	for rows.Next() {
		var m models.GroupMember
		if err := rows.Scan(&m.UserID, &m.Email, &m.Name); err != nil {
			return nil, err
		}
		members = append(members, m)
	}

	return members, rows.Err()
}

func (r *GroupRepo) AddStudents(groupID int64, teacherID int64, emails []string) (*models.Group, error) {
	var count int
	if err := r.db.QueryRow(
		`SELECT COUNT(*) FROM groups WHERE id = $1 AND teacher_id = $2`,
		groupID, teacherID,
	).Scan(&count); err != nil {
		return nil, err
	}
	if count == 0 {
		return nil, fmt.Errorf("group not found")
	}

	tx, err := r.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	for _, email := range emails {
		var userID int64
		if err := tx.QueryRow(
			`SELECT id FROM users WHERE email = $1 AND is_teacher = FALSE`,
			email,
		).Scan(&userID); err != nil {
			if err == sql.ErrNoRows {
				return nil, fmt.Errorf("student with email %s not found", email)
			}
			return nil, err
		}

		if _, err := tx.Exec(
			`INSERT INTO group_students (group_id, student_id)
			 VALUES ($1, $2)
			 ON CONFLICT (group_id, student_id) DO NOTHING`,
			groupID, userID,
		); err != nil {
			return nil, err
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}

	group := &models.Group{}
	if err := r.db.QueryRow(
		`SELECT id, teacher_id, name, created_at FROM groups WHERE id = $1`,
		groupID,
	).Scan(&group.ID, &group.TeacherID, &group.Name, &group.CreatedAt); err != nil {
		return nil, err
	}

	students, err := r.GetStudents(groupID)
	if err != nil {
		return nil, err
	}
	group.Students = students
	return group, nil
}

func (r *GroupRepo) AreTeacherGroups(teacherID int64, groupIDs []int64) (bool, error) {
	if len(groupIDs) == 0 {
		return false, nil
	}

	var count int
	if err := r.db.QueryRow(
		`SELECT COUNT(*)
		 FROM groups
		 WHERE teacher_id = $1 AND id = ANY($2)`,
		teacherID, pq.Array(groupIDs),
	).Scan(&count); err != nil {
		return false, err
	}

	return count == len(groupIDs), nil
}