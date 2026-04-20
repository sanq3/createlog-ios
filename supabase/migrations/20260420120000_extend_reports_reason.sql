-- Extend reports.reason CHECK to include copyright / impersonation.
-- Existing allowed: spam, harassment, inappropriate, misinformation, other.
-- Adding: copyright (DMCA 必須), impersonation (なりすまし、SNS 業界標準)。
-- Swift 側 ReportReason enum と 1:1 対応させる。

ALTER TABLE "public"."reports"
  DROP CONSTRAINT IF EXISTS "reports_reason_check";

ALTER TABLE "public"."reports"
  ADD CONSTRAINT "reports_reason_check"
  CHECK ("reason" = ANY (ARRAY[
    'spam'::text,
    'harassment'::text,
    'inappropriate'::text,
    'misinformation'::text,
    'copyright'::text,
    'impersonation'::text,
    'other'::text
  ]));
