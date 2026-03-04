-- 講座カリキュラム用カラム追加（JSON 方式）
-- 形式: {"columnType":"homework"|"goal", "rows":[{"day":1,"lesson":"...","col3":"..."}, ...]}
ALTER TABLE courses
  ADD COLUMN course_curriculum TEXT DEFAULT NULL
  COMMENT '講座カリキュラムJSON: columnType + rows[]'
  AFTER course_total_lessons;
