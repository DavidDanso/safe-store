# Build Log
Log of all terraform runs and deployment activities.


## Day 1 — Primary Bucket

versioning/encryption/PAB — no issues, straight in.

policy took longer than it should have. ran the http deny test, expected
AccessDenied, got a successful upload instead. spent like 10 min confused
before noticing my Resource array on EnforceHTTPS only had the bucket arn,
not the /* object arn too. added it, retested, denied. ok.

encryption header deny — fine first try.

uploaded test file, head-object shows ServerSideEncryption: AES256. good.

console upload test (separate from CLI test above): tried uploading
aws-cert.png through the S3 console normally, got Access denied. turned out
the console's default upload doesn't send the x-amz-server-side-encryption
header — it relies on the bucket's default encryption instead, which my
policy doesn't check for, only the header in the request itself. fix: in
the upload screen, Properties > Server-side encryption settings > switch
from "use bucket default" to "override" > SSE-S3. re-uploaded, worked.
good real-world proof of the tradeoff from choosing the strict header-check
policy over relying on default encryption alone.


## Day 2 — Backup Bucket & Replication

rough day.

replication config #1: InvalidRequest, DeleteMarkerReplication must be
specified. didn't know this was mandatory even to disable it. added
delete_marker_replication { status = "Disabled" }. matches ADR-001 anyway
so not a real change, just had to make it explicit in code.

logging: CrossLocationLoggingProhibitted. did not know logs bucket has to
be same-region as whatever it's logging. original plan (one logs bucket)
doesn't work. had to decide — drop backup logging entirely (it's a SHOULD
not MUST) or spin up a second logs bucket in eu-west-1. went with the
second bucket, didn't like the idea of backup being a total blind spot.
-> ADR-004

replication config #2, different error this time: MissingRequestBodyError,
empty request body. this one was annoying because nothing looked wrong.
turned out to be a race — versioning wasn't fully done propagating before
replication config got sent, since everything was in the same apply. added
depends_on for both versioning resources. fixed.

apply finally clean.

didn't trust "apply succeeded" = replication actually works, so tested for
real: put-object to primary w/ sse flag, waited ~3 min, head-object on
backup for the same key. it was there. confirmed, not assumed.


## Day 3 — Lifecycle, Alarm & Scripts

### Slice 1 — Lifecycle rules

wrote two separate rules for primary (noncurrent version expiration +
delete marker cleanup) instead of jamming both into one rule — id on a
combined rule would've been misleading, and AWS evaluates them the same
either way so no reason to combine.

caught myself missing the delete-marker rule on backup — only had
noncurrent version expiration there. FR7 says both rules on both buckets,
not just primary. added it.

while looking at backup's lockdown, realized the policy only denied
PutObject, not DeleteObject/DeleteObjectVersion. if backup's supposed to
be fully read-only, someone could still delete straight from it and leave
a delete marker sitting there forever with nothing cleaning it up.
hardened the policy to deny all three write-type actions, not just
PutObject.

same thing occurred to me about the logs bucket — nothing was stopping me
from uploading straight into it myself. added a deny statement blocking
everyone except the logging service, same idea as backup's lockout but
using aws:PrincipalServiceName since the trusted party here is a service,
not a role. double-checked the negated-operator behavior before trusting
it — StringNotEquals with a missing key evaluates true (denies), which is
what you want, confirmed against AWS docs since this isn't obvious.

did a live test with real data before starting the scripts — 3mb file
instead of the kb-sized synthetic ones. dropped lifecycle timers to 1 day
temporarily so i wasn't waiting a month to see cleanup actually happen.
upload, encryption check, replication check, delete + verify delete
marker — all fine.

tried cleaning the test file out of backup afterward through the console,
got denied — DeleteObjectVersion, explicit deny, resource policy. took a
second to realize that's my own hardened policy doing exactly what it's
supposed to, not a bug. left the file, lifecycle will clean it up once
timers are back to normal.

lifecycle timers still on 1 day — need to flip back to 30/90 before Day 4.

### Slice 2 — CloudWatch alarm

primary alarm straightforward, 1GB threshold, way above anything test
files will hit.

added one for backup too, even though PRD only asked for primary.
reasoning: delete markers aren't replicated (ADR-001), so backup can hold
onto stuff primary's already cleaned up — sizes can diverge over time,
so primary-only monitoring could miss something abnormal happening
specifically on backup. free to add, so did it. worth a line in an ADR
since it's extending scope on purpose, not just extra effort for its own
sake.

caught a bug before applying — backup alarm had no provider = aws.backup
set, so it would've been created in the wrong region entirely.
CloudWatch metrics are regional, and BucketSizeBytes for backup only
exists in eu-west-1. would've sat at INSUFFICIENT_DATA forever, silently
broken, no error at apply time to catch it. added the provider line.

also caught both alarms missing tags — same FR12 gap i already hit once
on the IAM policy. added tags to both.

used the same threshold for both buckets instead of giving backup its own
higher number. backup could arguably justify a higher threshold given the
divergence reasoning above, but not worth a second variable + ADR for a
project this size on this timebox — noted as a talking point instead of
implementing it.

currently here — alarm applied, waiting to confirm it flips to OK once
the first daily metric lands.

### Slice 3 — Recovery script

wrote recover.py — upload, delete, head_object check, list versions, find
delete marker, delete the marker to restore, verify restored file matches
original, cleanup.

hit AccessDenied on the very first put_object call. same root cause as
day 1's console upload — script wasn't sending the
x-amz-server-side-encryption header, my policy denies any PutObject
without it. third time hitting this exact issue now (CLI, console, boto3),
starting to just expect it by default whenever i write a new client
against this bucket. added ServerSideEncryption='AES256' to the call,
fixed.

before running it for real, went back through the version-lookup logic
and found a real bug — was grabbing delete_markers[0] and assuming it's
the current one. works fine on a clean run, but if a previous test left
the bucket messy (partial failure, cleanup never ran), there could be
multiple delete markers and [0] isn't guaranteed to be the active one.
switched to filtering on IsLatest instead, since that's the actual flag
S3 uses to mark what's current — don't want to trust list order.

also tightened the Prefix=KEY_NAME matches — Prefix does partial matching,
not exact, so added an explicit key == KEY_NAME filter on top. harmless
right now since the filename's fixed and nothing else in the bucket
shares that prefix, but wanted it defensive in case this script ever gets
reused with a dynamic filename later.

ran it after the fixes. upload → delete → confirmed 404 → found the
current delete marker → deleted the marker → confirmed restored → size
and content both matched the original → cleanup ran, bucket left clean.
full pass, real output, not assumed.

### Slice 4 — Replication check script
not started.