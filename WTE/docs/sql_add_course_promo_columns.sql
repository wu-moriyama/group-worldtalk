-- 講座プロモーション用カラム追加（講座の概要・強み・ターゲット・効果・先生メッセージ）
-- 既存DB用。新規インストールの wte.sql に含める場合はこの定義をマージしてください。
ALTER TABLE `courses`
  ADD COLUMN `course_overview` text DEFAULT NULL COMMENT '講座の概要' AFTER `course_intro`,
  ADD COLUMN `course_strength` text DEFAULT NULL COMMENT '講座の強み・特徴' AFTER `course_overview`,
  ADD COLUMN `course_target` text DEFAULT NULL COMMENT '想定しているターゲット' AFTER `course_strength`,
  ADD COLUMN `course_effect` text DEFAULT NULL COMMENT '講座で得られる効果' AFTER `course_target`,
  ADD COLUMN `course_message` text DEFAULT NULL COMMENT '先生からのメッセージ' AFTER `course_effect`;
