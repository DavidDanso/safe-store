# Build Log
Log of all terraform runs and deployment activities.


## Day 1 — Primary Bucket

- versioning/encryption/PAB: no issues.
- HTTP deny test failed first try — Resource ARN was missing the /* object
  ARN, only had the bucket ARN. added it, fixed.
- encryption header deny: fine first try.
- confirmed SSE-S3 via head-object.
- console upload separately failed — console doesn't send the encryption
  header by default. fixed by switching to "override encryption" in the
  upload UI.


## Day 2 — Backup Bucket & Replication

- replication attempt #1: InvalidRequest, DeleteMarkerReplication must be
  set explicitly (even to disable). added it — matches ADR-001.
- logging failed: CrossLocationLoggingProhibited. logs bucket must be
  same-region as what it's logging. single shared logs bucket doesn't
  work. added a second logs bucket in eu-west-1. → ADR-004.
- replication attempt #2: MissingRequestBodyError. root cause: versioning
  wasn't fully propagated before replication config was sent, since it
  was all in one apply. fixed with depends_on on both versioning
  resources.
- apply succeeded. verified for real — uploaded to primary, waited,
  confirmed the file in backup via head-object.


## Day 3 — Lifecycle, Alarm & Scripts

### Slice 1 — Lifecycle

- two separate rules on primary (noncurrent version expiry + delete
  marker cleanup).
- caught backup missing the delete-marker rule — FR7 needs both rules on
  both buckets. added it.
- caught backup's policy only blocked PutObject, not Delete actions.
  hardened it to deny PutObject/DeleteObject/DeleteObjectVersion.
- same gap on the logs bucket — could upload directly myself. added a
  deny-except-logging-service statement. confirmed the missing-key
  behavior of StringNotEquals against AWS docs before trusting it.
- live test with a real 3MB file, lifecycle timers dropped to 1 day
  temporarily. upload/encrypt/replicate/delete/restore all worked.
- tried manually deleting the test file from backup — denied by my own
  policy, as expected. left it, lifecycle will clean it up.
- timers still on 1 day — need to revert to 30/90 before Day 4.

**Logs bucket hardening broke log delivery — biggest issue of the day**
- after adding the deny-except-logging-service statement, logs stopped
  showing up entirely. checked everything: bucket policy live and
  correct, get-bucket-logging confirmed enabled on both source buckets,
  generated fresh test traffic, waited 6+ hours. still nothing.
- root cause: the hardening statement itself. S3's internal log delivery
  likely doesn't set aws:PrincipalServiceName the way a normal service
  call would — so the negated condition treated the missing key as "deny"
  and silently blocked every delivery attempt, no error anywhere.
  confirmed by AWS's own troubleshooting docs, which explicitly list
  "check for Deny statements" as a known cause.
- removed the statement from both logs bucket policies. logs started
  showing up immediately after.
- decided to leave it removed rather than tighten it further — the only
  identity that could exploit it is my own IAM user, who already has
  full account access, so the statement wasn't real protection. it had
  already caused a real outage on the one thing the bucket exists to do.
  logged as a deliberate tradeoff.

### Slice 2 — CloudWatch alarm

- primary alarm, 1GB threshold.
- added one for backup too (not required by PRD) — delete markers aren't
  replicated, so backup can hold more data than primary over time.
- caught a bug before applying — backup alarm had no provider =
  aws.backup, would've silently watched the wrong region forever. fixed.
- caught both alarms missing tags (same FR12 gap as before). fixed.
- same threshold on both buckets — noted as a talking point, not worth a
  second variable for this project's scope.
- waiting to confirm state flips to OK on the first daily metric.

### Slice 3 — Recovery script

- wrote recover.py: upload → delete → confirm gone → find delete marker
  → delete marker to restore → verify match → cleanup.
- first run: AccessDenied on put_object — missing the encryption header
  again. third time hitting this exact issue (CLI, console, boto3 now).
  fixed with ServerSideEncryption='AES256'.
- caught a real bug before running for real — was grabbing
  delete_markers[0], not guaranteed to be the current one if a past run
  left extra markers behind. switched to filtering on IsLatest.
- tightened Prefix matches with an explicit key == KEY_NAME filter —
  harmless now, defensive if this script is ever reused with a dynamic
  filename.
- ran clean after fixes: full pass, real output — upload, delete, 404
  confirmed, marker found and removed, restore confirmed, size + content
  matched, cleanup left the bucket clean.

### Slice 4 — Replication check script
not started.