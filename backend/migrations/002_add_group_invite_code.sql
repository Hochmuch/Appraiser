ALTER TABLE groups ADD COLUMN IF NOT EXISTS invite_code VARCHAR(64);

UPDATE groups
SET invite_code = substr(md5(random()::text || clock_timestamp()::text), 1, 32)
WHERE invite_code IS NULL;

ALTER TABLE groups ALTER COLUMN invite_code SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_groups_invite_code ON groups(invite_code);
