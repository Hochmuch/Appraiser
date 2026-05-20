CREATE TYPE user_role AS ENUM ('student', 'teacher', 'admin');
CREATE TYPE submission_status AS ENUM ('pending', 'reviewing', 'completed', 'error');
CREATE TYPE llm_provider_type AS ENUM ('gigachat', 'gemini');
CREATE TYPE finding_severity AS ENUM ('info', 'warning', 'error');


CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'student',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    github_id BIGINT UNIQUE,
    github_login VARCHAR(255)
);

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

CREATE TABLE IF NOT EXISTS assignments (
    id BIGSERIAL PRIMARY KEY,
    teacher_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS assignment_groups (
    assignment_id BIGINT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    PRIMARY KEY (assignment_id, group_id)
);

CREATE TABLE IF NOT EXISTS criteria (
    id BIGSERIAL PRIMARY KEY,
    assignment_id BIGINT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    max_score INT NOT NULL DEFAULT 10
);

CREATE TABLE IF NOT EXISTS submissions (
    id BIGSERIAL PRIMARY KEY,
    assignment_id BIGINT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    student_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    github_repo VARCHAR(500) NOT NULL,
    status submission_status NOT NULL DEFAULT 'pending',
    llm_provider llm_provider_type NOT NULL DEFAULT 'gigachat',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (assignment_id, student_id)
);

CREATE TABLE IF NOT EXISTS reviews (
    id BIGSERIAL PRIMARY KEY,
    submission_id BIGINT NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    criteria_id BIGINT NOT NULL REFERENCES criteria(id) ON DELETE CASCADE,
    score INT NOT NULL DEFAULT 0,
    comment TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS repo_snapshots (
    id BIGSERIAL PRIMARY KEY,
    submission_id BIGINT UNIQUE NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    commit_sha VARCHAR(255),
    branch VARCHAR(255),
    file_count INT,
    total_size INT,
    project_map TEXT,
    summary TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS source_files (
    id BIGSERIAL PRIMARY KEY,
    snapshot_id BIGINT NOT NULL REFERENCES repo_snapshots(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    language VARCHAR(255),
    size INT,
    content_hash VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS review_findings (
    id BIGSERIAL PRIMARY KEY,
    review_id BIGINT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
    source_file_id BIGINT REFERENCES source_files(id) ON DELETE SET NULL,
    start_line INT DEFAULT 1,
    end_line INT DEFAULT 1,
    severity finding_severity NOT NULL DEFAULT 'info',
    title TEXT,
    comment TEXT,
    suggestion TEXT,
    source VARCHAR(255) NOT NULL DEFAULT 'llm',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS code_chunks (
    id BIGSERIAL PRIMARY KEY,
    source_file_id BIGINT NOT NULL REFERENCES source_files(id) ON DELETE CASCADE,
    snapshot_id BIGINT NOT NULL REFERENCES repo_snapshots(id) ON DELETE CASCADE,
    chunk_index INT,
    start_line INT,
    end_line INT,
    symbol_type VARCHAR(255),
    symbol_name VARCHAR(255),
    content TEXT,
    token_estimate INT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chunk_relations (
    id BIGSERIAL PRIMARY KEY,
    snapshot_id BIGINT NOT NULL REFERENCES repo_snapshots(id) ON DELETE CASCADE,
    source_chunk_id BIGINT NOT NULL REFERENCES code_chunks(id) ON DELETE CASCADE,
    target_chunk_id BIGINT NOT NULL REFERENCES code_chunks(id) ON DELETE CASCADE,
    relation_type VARCHAR(255) NOT NULL DEFAULT 'imports',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);