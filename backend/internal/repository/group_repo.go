package repository

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"fmt"
	"strings"

	"appraiser/internal/models"

	"github.com/lib/pq"
)

type GroupRepo struct {
	db *sql.DB
}

func NewGroupRepo(db *sql.DB) *GroupRepo {
	return &GroupRepo{db: db}
}

func generateInviteCode() (string, error) {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

func isMissingInviteCodeColumn(err error) bool {
	return err != nil && strings.Contains(err.Error(), "invite_code")
}

func (r *GroupRepo) Create(teacherID int64, req models.CreateGroupRequest) (*models.Group, error) {
	tx, err := r.db.Begin()
	if err != nil {
		return nil, err
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback()
		}
	}()

	inviteCode, err := generateInviteCode()
	if err != nil {
		return nil, err
	}

	group := &models.Group{}
	insertErr := tx.QueryRow(
		`INSERT INTO groups (teacher_id, name, invite_code)
		 VALUES ($1, $2, $3)
		 RETURNING id, teacher_id, name, invite_code, created_at`,
		teacherID, req.Name, inviteCode,
	).Scan(&group.ID, &group.TeacherID, &group.Name, &group.InviteCode, &group.CreatedAt)
	if insertErr != nil {
		if isMissingInviteCodeColumn(insertErr) {
			if rbErr := tx.Rollback(); rbErr != nil {
				return nil, rbErr
			}
			tx, err = r.db.Begin()
			if err != nil {
				return nil, err
			}
			if err := tx.QueryRow(
				`INSERT INTO groups (teacher_id, name)
				 VALUES ($1, $2)
				 RETURNING id, teacher_id, name, created_at`,
				teacherID, req.Name,
			).Scan(&group.ID, &group.TeacherID, &group.Name, &group.CreatedAt); err != nil {
				return nil, err
			}
			group.InviteCode = ""
		} else {
			return nil, insertErr
		}
	}

	for _, email := range req.StudentEmails {
		var userID int64
		var name string
		if err := tx.QueryRow(
			`SELECT id, name FROM users WHERE email = $1 AND role = 'student'`,
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
		`SELECT id, teacher_id, name, invite_code, created_at
		 FROM groups
		 WHERE teacher_id = $1
		 ORDER BY created_at DESC`,
		teacherID,
	)
	fallback := false
	if err != nil {
		if isMissingInviteCodeColumn(err) {
			fallback = true
			rows, err = r.db.Query(
				`SELECT id, teacher_id, name, created_at
				 FROM groups
				 WHERE teacher_id = $1
				 ORDER BY created_at DESC`,
				teacherID,
			)
		}
		if err != nil {
			return nil, err
		}
	}
	defer rows.Close()

	var groups []models.Group
	for rows.Next() {
		var g models.Group
		if fallback {
			if err := rows.Scan(&g.ID, &g.TeacherID, &g.Name, &g.CreatedAt); err != nil {
				return nil, err
			}
			g.InviteCode = ""
		} else {
			if err := rows.Scan(&g.ID, &g.TeacherID, &g.Name, &g.InviteCode, &g.CreatedAt); err != nil {
				return nil, err
			}
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
			`SELECT id FROM users WHERE email = $1 AND role = 'student'`,
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
	err = r.db.QueryRow(
		`SELECT id, teacher_id, name, invite_code, created_at FROM groups WHERE id = $1`,
		groupID,
	).Scan(&group.ID, &group.TeacherID, &group.Name, &group.InviteCode, &group.CreatedAt)
	if err != nil {
		if isMissingInviteCodeColumn(err) {
			err = r.db.QueryRow(
				`SELECT id, teacher_id, name, created_at FROM groups WHERE id = $1`,
				groupID,
			).Scan(&group.ID, &group.TeacherID, &group.Name, &group.CreatedAt)
			if err != nil {
				return nil, err
			}
			group.InviteCode = ""
		} else {
			return nil, err
		}
	}

	students, err := r.GetStudents(groupID)
	if err != nil {
		return nil, err
	}
	group.Students = students
	return group, nil
}

func (r *GroupRepo) JoinByInviteCode(inviteCode string, studentID int64) (*models.Group, error) {
	group := &models.Group{}
	if err := r.db.QueryRow(
		`SELECT id, teacher_id, name, invite_code, created_at FROM groups WHERE invite_code = $1`,
		inviteCode,
	).Scan(&group.ID, &group.TeacherID, &group.Name, &group.InviteCode, &group.CreatedAt); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("group not found")
		}
		return nil, err
	}

	if _, err := r.db.Exec(
		`INSERT INTO group_students (group_id, student_id)
		 VALUES ($1, $2)
		 ON CONFLICT (group_id, student_id) DO NOTHING`,
		group.ID, studentID,
	); err != nil {
		return nil, err
	}

	students, err := r.GetStudents(group.ID)
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
