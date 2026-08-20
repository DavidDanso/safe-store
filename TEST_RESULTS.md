# Test Results

Results of recovery and replication tests.


## Recovery

- manual live test first, before touching the script: uploaded a real
  3MB file, deleted it, checked list-object-versions — delete marker
  present, original version still there underneath. confirms the basic
  mechanism (delete = marker, not real deletion) actually works before
  trusting a script to automate it.

- ran recover.py for the first time — FAILED. AccessDenied on the
  upload step. script wasn't sending the encryption header, same issue
  hit on Day 1 with the console and CLI. fixed with
  ServerSideEncryption='AES256'.

- before re-running, caught a real bug in the script itself: it was
  grabbing delete_markers[0] and assuming that's the current one — not
  safe if a past run left extra markers behind. switched to filtering
  on IsLatest instead. caught this by reading the code, not by it
  failing.

- ran recover.py again — PASSED. full sequence: upload → delete →
  head_object confirmed 404 → correct delete marker found → marker
  deleted → object restored → size and content matched the original
  exactly → cleanup left the bucket empty again.

**Recovery: confirmed working. 1 real failure along the way (missing
encryption header), fixed, then a clean pass with real output.**


## Replication

- replication itself took two failed terraform applies before the
  pipeline even existed:
  - attempt 1: DeleteMarkerReplication had to be set explicitly, even
    to disable it. AWS rejected the config without it.
  - attempt 2: race condition — replication config got sent before
    versioning had fully propagated on both buckets. fixed with
    depends_on.
  neither of these were "test failures" exactly — more like the
  infrastructure not being ready to test yet.

- first real replication test, manual: uploaded a file to primary with
  the CLI, waited ~3 minutes, ran head_object against backup for the
  same key — PASSED, file was there.

- confirmed again later, separately, just from normal use: big-dee.jpg
  showed up in both buckets with identical size and matching version
  timestamps — not a deliberate test, but still real evidence
  replication kept working over time, not just once.

- wrote check_replication.py — walked through the logic, found a likely
  bug before ever running it: both the primary and backup boto3 clients
  default to the same region, so the "backup" client isn't actually
  pointed at eu-west-1 unless region_name is set explicitly. this would
  probably make the very first backup check fail with something other
  than a clean 404, which the script's retry logic doesn't handle —
  it would likely exit immediately instead of polling.

- **check_replication.py has NOT been run yet.** fix the region bug
  first, then run it for real and record the actual output here.

- test case 7 from the PRD (upload a file *before* replication is
  configured, confirm it's NOT in backup) — **not explicitly tested.**
  replication's been live since Day 2, so a fresh test needs an object
  that predates that. worth checking whether any Day 1 upload still
  exists and was never backfilled to backup, or documenting this as a
  known/understood limitation instead if no such object exists anymore.

**Replication: confirmed working via manual testing, twice. the
automated script exists but hasn't actually been run — until it is,
this isn't independently proven, only manually proven.**


## Summary

| Area | Status |
|---|---|
| Manual recovery test | PASS |
| recover.py | PASS (after 1 fix) |
| Manual replication test | PASS (x2) |
| check_replication.py | NOT RUN — has a known bug to fix first |
| No-backfill case (test 7) | NOT TESTED |