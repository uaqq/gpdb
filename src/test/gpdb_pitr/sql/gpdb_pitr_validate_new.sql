-- This table must exist, and be empty (all WALs have been replayed).
SELECT * FROM gpdb_pitr_tt;

-- The DELETE was replayed.
SELECT * FROM gpdb_two_phase_commit_before_acquire_share_lock;

-- The DELETE should have been rebroadcasted so should show no rows.
SELECT * FROM gpdb_two_phase_commit_after_acquire_share_lock;

-- The INSERT happened after the restore point, and was replayed
SELECT * FROM gpdb_two_phase_commit_after_restore_point;

-- The one-phase commit should have gone through before the restore
-- point was created so it should show up.
SELECT * FROM gpdb_one_phase_commit;
