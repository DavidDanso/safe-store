# Build Log
Log of all terraform runs and deployment activities.


## Day 1 — Primary Bucket

- versioning/encryption/PAB: no issues.
- HTTP deny test failed first try — Resource ARN was missing the /*
  object ARN. added it, fixed.
- encryption header deny: fine first try. confirmed SSE-S3 via
  head-object.
- console upload failed separately — console doesn't send the
  encryption header by default. fixed via "override encryption" in the
  upload UI.


## Day 2 — Backup Bucket & Replication

- replication #1: failed, DeleteMarkerReplication must be set explicitly
  even to disable it. added it — matches ADR-001.
- logging failed: logs bucket must be same-region as what it's logging.
  one shared logs bucket doesn't work. added a second logs bucket in
  eu-west-1. → ADR-004.
- replication #2: failed, empty request body. root cause: versioning
  wasn't fully propagated before replication config was sent in the same
  apply. fixed with depends_on on both versioning resources.
- apply succeeded. verified for real — uploaded to primary, waited,
  confirmed the file in backup.


## Day 3 — Lifecycle, Alarm & Scripts

### Slice 1 — Lifecycle

- two rules on primary (noncurrent version expiry + delete marker
  cleanup). caught backup missing the delete-marker rule, added it.
- hardened backup's policy to block Delete actions too, not just
  PutObject. same gap found on logs bucket — could upload directly
  myself, added a deny-except-logging-service statement.
- **that hardening broke log delivery entirely.** logs stopped showing
  up, 6+ hours, no error anywhere. root cause: S3's internal log
  delivery likely doesn't set aws:PrincipalServiceName, so the negated
  condition silently denied every delivery. removed the statement from
  both logs bucket policies — logs came back immediately. left it
  removed on purpose: the only one who could exploit the gap is my own
  IAM user, who already has full account access, so the "protection"
  wasn't real and had already caused a real outage. logged as a
  deliberate tradeoff.
- live test with a real 3MB file, timers dropped to 1 day temporarily —
  upload/encrypt/replicate/delete/restore all worked.
- ran a second live test specifically to prove lifecycle cleanup: 2
  files, each uploaded twice to create noncurrent versions. checked
  back after 2 days, still there — thought it was broken.
- turned out to be a timing misunderstanding, not a bug. AWS calculates
  from when the *second* upload happens (not the first), then rounds up
  to the next midnight UTC before the day-count even starts. so "1 day"
  is really closer to 2 full days before it's even eligible.
- checked back Aug 21 — noncurrent versions gone, confirmed with real
  screenshots. rule was correct the whole time; the delay was expected
  AWS behavior.
- still open: only tested noncurrent version expiration this way, not
  delete-marker cleanup specifically — that still needs its own direct
  test with an actual delete.
- timers still on 1 day — need to revert to 30/90 before Day 4.

### Slice 2 — CloudWatch alarm

- primary alarm, 1GB threshold. added one for backup too (not required
  by PRD) — delete markers aren't replicated, so backup can hold more
  data than primary over time, sizes can diverge.
- caught a bug before applying — backup alarm had no provider =
  aws.backup, would've silently watched the wrong region forever. fixed.
- caught both alarms missing tags (same FR12 gap as before). fixed.
- same threshold on both buckets — noted as a talking point, not worth a
  second variable for this project's scope.
- showed INSUFFICIENT_DATA for a while — expected, this metric only
  reports once a day. resolves on its own once the first data point
  lands.

### Slice 3 — Recovery script

- wrote recover.py: upload → delete → confirm gone → find delete marker
  → delete marker to restore → verify match → cleanup.
- first run: AccessDenied — missing the encryption header again, same
  issue as CLI and console before it. fixed with
  ServerSideEncryption='AES256'.
- caught a real bug before running for real — was grabbing
  delete_markers[0], not guaranteed to be the current one. switched to
  filtering on IsLatest instead.
- tightened Prefix matches with an explicit key == KEY_NAME filter,
  defensive for future reuse with a dynamic filename.
- ran clean after fixes: full pass, real output, upload through cleanup
  all confirmed working.

### Slice 4 — Replication check script
not started.