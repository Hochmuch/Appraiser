package repository

import (
	"database/sql"

	"appraiser/internal/models"
)

type SnapshotRepo struct {
	db *sql.DB
}

func NewSnapshotRepo(db *sql.DB) *SnapshotRepo {
	return &SnapshotRepo{db: db}
}

func (r *SnapshotRepo) CreateSnapshot(s *models.RepoSnapshot) error {
	return r.db.QueryRow(
		`INSERT INTO repo_snapshots (submission_id, commit_sha, branch, file_count, total_size, project_map, summary)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 ON CONFLICT (submission_id) DO UPDATE
		   SET commit_sha = $2, branch = $3, file_count = $4, total_size = $5, project_map = $6, summary = $7, created_at = NOW()
		 RETURNING id, created_at`,
		s.SubmissionID, s.CommitSHA, s.Branch, s.FileCount, s.TotalSize, s.ProjectMap, s.Summary,
	).Scan(&s.ID, &s.CreatedAt)
}

func (r *SnapshotRepo) GetBySubmission(submissionID int64) (*models.RepoSnapshot, error) {
	s := &models.RepoSnapshot{}
	err := r.db.QueryRow(
		`SELECT id, submission_id, commit_sha, branch, file_count, total_size, project_map, summary, created_at
		 FROM repo_snapshots WHERE submission_id = $1`,
		submissionID,
	).Scan(&s.ID, &s.SubmissionID, &s.CommitSHA, &s.Branch, &s.FileCount, &s.TotalSize, &s.ProjectMap, &s.Summary, &s.CreatedAt)
	if err != nil {
		return nil, err
	}
	return s, nil
}

func (r *SnapshotRepo) DeleteSnapshotData(snapshotID int64) error {

	_, err := r.db.Exec(`DELETE FROM source_files WHERE snapshot_id = $1`, snapshotID)
	return err
}

func (r *SnapshotRepo) InsertSourceFile(f *models.SourceFile) error {
	return r.db.QueryRow(
		`INSERT INTO source_files (snapshot_id, file_path, language, size, content_hash)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING id, created_at`,
		f.SnapshotID, f.FilePath, f.Language, f.Size, f.ContentHash,
	).Scan(&f.ID, &f.CreatedAt)
}

func (r *SnapshotRepo) InsertChunk(c *models.CodeChunk) error {
	return r.db.QueryRow(
		`INSERT INTO code_chunks (source_file_id, snapshot_id, chunk_index, start_line, end_line, symbol_type, symbol_name, content, token_estimate)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		 RETURNING id, created_at`,
		c.SourceFileID, c.SnapshotID, c.ChunkIndex, c.StartLine, c.EndLine, c.SymbolType, c.SymbolName, c.Content, c.TokenEstimate,
	).Scan(&c.ID, &c.CreatedAt)
}

func (r *SnapshotRepo) InsertRelation(rel *models.ChunkRelation) error {
	return r.db.QueryRow(
		`INSERT INTO chunk_relations (snapshot_id, source_chunk_id, target_chunk_id, relation_type)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, created_at`,
		rel.SnapshotID, rel.SourceChunkID, rel.TargetChunkID, rel.RelationType,
	).Scan(&rel.ID, &rel.CreatedAt)
}

func (r *SnapshotRepo) GetChunksBySnapshot(snapshotID int64) ([]models.CodeChunk, error) {
	rows, err := r.db.Query(
		`SELECT c.id, c.source_file_id, c.snapshot_id, c.chunk_index,
		        c.start_line, c.end_line, c.symbol_type, c.symbol_name,
		        c.content, c.token_estimate, c.created_at
		 FROM code_chunks c
		 WHERE c.snapshot_id = $1
		 ORDER BY c.source_file_id, c.chunk_index`,
		snapshotID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var chunks []models.CodeChunk
	for rows.Next() {
		var c models.CodeChunk
		if err := rows.Scan(
			&c.ID, &c.SourceFileID, &c.SnapshotID, &c.ChunkIndex,
			&c.StartLine, &c.EndLine, &c.SymbolType, &c.SymbolName,
			&c.Content, &c.TokenEstimate, &c.CreatedAt,
		); err != nil {
			return nil, err
		}
		chunks = append(chunks, c)
	}
	return chunks, rows.Err()
}

func (r *SnapshotRepo) GetSourceFiles(snapshotID int64) ([]models.SourceFile, error) {
	rows, err := r.db.Query(
		`SELECT id, snapshot_id, file_path, language, size, content_hash, created_at
		 FROM source_files WHERE snapshot_id = $1 ORDER BY file_path`,
		snapshotID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var files []models.SourceFile
	for rows.Next() {
		var f models.SourceFile
		if err := rows.Scan(&f.ID, &f.SnapshotID, &f.FilePath, &f.Language, &f.Size, &f.ContentHash, &f.CreatedAt); err != nil {
			return nil, err
		}
		files = append(files, f)
	}
	return files, rows.Err()
}
