CREATE TABLE IF NOT EXISTS repo_snapshots (
    id BIGSERIAL PRIMARY KEY,
    submission_id BIGINT NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    commit_sha VARCHAR(40) NOT NULL DEFAULT '',
    branch VARCHAR(255) NOT NULL DEFAULT 'main',
    file_count INT NOT NULL DEFAULT 0,
    total_size INT NOT NULL DEFAULT 0,
    project_map TEXT NOT NULL DEFAULT '',
    summary TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(submission_id)
);

CREATE TABLE IF NOT EXISTS source_files (
    id BIGSERIAL PRIMARY KEY,
    snapshot_id BIGINT NOT NULL REFERENCES repo_snapshots(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    language VARCHAR(50) NOT NULL DEFAULT '',
    size INT NOT NULL DEFAULT 0,
    content_hash VARCHAR(64) NOT NULL DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_source_files_snapshot ON source_files(snapshot_id);

CREATE TABLE IF NOT EXISTS code_chunks (
    id BIGSERIAL PRIMARY KEY,
    source_file_id BIGINT NOT NULL REFERENCES source_files(id) ON DELETE CASCADE,
    snapshot_id BIGINT NOT NULL REFERENCES repo_snapshots(id) ON DELETE CASCADE,
    chunk_index INT NOT NULL DEFAULT 0,
    start_line INT NOT NULL DEFAULT 1,
    end_line INT NOT NULL DEFAULT 1,
    symbol_type VARCHAR(50) NOT NULL DEFAULT '',
    symbol_name VARCHAR(255) NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    token_estimate INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_code_chunks_snapshot ON code_chunks(snapshot_id);
CREATE INDEX IF NOT EXISTS idx_code_chunks_source_file ON code_chunks(source_file_id);

CREATE TABLE IF NOT EXISTS chunk_relations (
    id BIGSERIAL PRIMARY KEY,
    snapshot_id BIGINT NOT NULL REFERENCES repo_snapshots(id) ON DELETE CASCADE,
    source_chunk_id BIGINT NOT NULL REFERENCES code_chunks(id) ON DELETE CASCADE,
    target_chunk_id BIGINT NOT NULL REFERENCES code_chunks(id) ON DELETE CASCADE,
    relation_type VARCHAR(50) NOT NULL DEFAULT 'imports',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chunk_relations_snapshot ON chunk_relations(snapshot_id);
