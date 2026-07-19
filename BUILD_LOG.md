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

## Day 2 — Backup Bucket, Replication & IAM Role

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

## Day 3 — Logging & Lifecycle Policies, Verification

[pending]