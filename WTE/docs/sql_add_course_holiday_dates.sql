-- 休講日用カラム追加（既存DB用）
-- 新規インストールの wte.sql には既に含まれています。
ALTER TABLE `courses`
  ADD COLUMN `course_holiday_dates` text DEFAULT NULL COMMENT '休講日（1行1日付 YYYY-MM-DD、改行区切り）' AFTER `course_material_drive_url`;
