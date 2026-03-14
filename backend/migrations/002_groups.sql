CREATE TABLE IF NOT EXISTS groups (
    id BIGSERIAL PRIMARY KEY,
    teacher_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS group_students (
    group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    student_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (group_id, student_id)
);

CREATE TABLE IF NOT EXISTS assignment_groups (
    assignment_id BIGINT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    PRIMARY KEY (assignment_id, group_id)
);