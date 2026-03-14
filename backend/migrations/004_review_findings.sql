CREATE TABLE IF NOT EXISTS review_findings (
    id BIGSERIAL PRIMARY KEY,
    submission_id BIGINT NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    start_line INT NOT NULL DEFAULT 1,
    end_line INT NOT NULL DEFAULT 1,
    severity VARCHAR(20) NOT NULL DEFAULT 'info',
    title TEXT NOT NULL,
    comment TEXT NOT NULL,
    suggestion TEXT NOT NULL DEFAULT '',
    source VARCHAR(20) NOT NULL DEFAULT 'llm',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_review_findings_submission_id
    ON review_findings(submission_id);
