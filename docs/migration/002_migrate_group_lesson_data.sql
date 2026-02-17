-- ============================================================
-- Step 2: 既存データの移行
-- group_schedules → group_lesson_slots
-- lessons（グループ分）→ group_lesson_bookings
--
-- 実行前に必ずDBのバックアップを取ってください。
-- データベース名が wte であることを前提としています。
-- ============================================================

-- ------------------------------------------------------------
-- 1. 移行用の一時カラムを追加（group_id と slot_id の対応付けのため）
-- ------------------------------------------------------------
ALTER TABLE `group_lesson_slots`
  ADD COLUMN `migrated_group_id` bigint(20) UNSIGNED NULL DEFAULT NULL
  AFTER `slot_id`;

-- ------------------------------------------------------------
-- 2. group_schedules を group_lesson_slots に投入
--    capacity_current = その枠に紐づく「キャンセルされていない」lessons の件数
--    status = 終了日時を過ぎていれば 2（終了）、それ以外は 1（受付中）
-- ------------------------------------------------------------
INSERT INTO `group_lesson_slots` (
  `course_id`,
  `prof_id`,
  `slot_stime`,
  `slot_etime`,
  `capacity_max`,
  `capacity_current`,
  `status`,
  `cdate`,
  `mdate`,
  `migrated_group_id`
)
SELECT
  gs.`course_id`,
  gs.`prof_id`,
  gs.`sch_stime`,
  gs.`sch_etime`,
  gs.`group_count`,
  gs.`group_count` - IFNULL((
    SELECT COUNT(*)
    FROM `lessons` l
    WHERE l.`course_id` = gs.`course_id`
      AND l.`prof_id`  = gs.`prof_id`
      AND l.`lsn_stime` = gs.`sch_stime`
      AND l.`lsn_cancel` = 0
  ), 0),
  CASE WHEN gs.`sch_etime` < NOW() THEN 2 ELSE 1 END,
  gs.`sch_cdate`,
  0,
  gs.`group_id`
FROM `group_schedules` gs;

-- ------------------------------------------------------------
-- 3. lessons（グループ分）を group_lesson_bookings に投入
--    グループレッスン = group_schedules と course_id / prof_id / 開始時刻が一致するもの
--    status: キャンセル済み=3、それ以外=1（予約済）
-- ------------------------------------------------------------
INSERT INTO `group_lesson_bookings` (
  `slot_id`,
  `member_id`,
  `seller_id`,
  `pay_type`,
  `price`,
  `coupon_id`,
  `status`,
  `cancel_reason`,
  `cdate`,
  `mdate`
)
SELECT
  sl.`slot_id`,
  l.`member_id`,
  l.`seller_id`,
  l.`lsn_pay_type`,
  l.`lsn_prof_fee`,
  IFNULL(l.`coupon_id`, 0),
  CASE WHEN l.`lsn_cancel` = 0 THEN 1 ELSE 3 END,
  l.`lsn_cancel_reason`,
  l.`lsn_cdate`,
  l.`lsn_status_date`
FROM `lessons` l
INNER JOIN `group_schedules` gs
  ON l.`course_id` = gs.`course_id`
  AND l.`prof_id`  = gs.`prof_id`
  AND l.`lsn_stime` = gs.`sch_stime`
INNER JOIN `group_lesson_slots` sl
  ON sl.`migrated_group_id` = gs.`group_id`;

-- ------------------------------------------------------------
-- 4. 一時カラムを削除
-- ------------------------------------------------------------
ALTER TABLE `group_lesson_slots`
  DROP COLUMN `migrated_group_id`;

-- ------------------------------------------------------------
-- 確認用（実行後、件数を見たい場合にコメント解除して実行）
-- SELECT COUNT(*) AS slots_count FROM group_lesson_slots;
-- SELECT COUNT(*) AS bookings_count FROM group_lesson_bookings;
-- ------------------------------------------------------------
