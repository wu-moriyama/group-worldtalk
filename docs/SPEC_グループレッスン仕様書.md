# ワールドトーク グループレッスンシステム 仕様書

## 1. プロジェクト概要

### 1.1 サービス概要

**ワールドトーク**はオンライン英会話サービスであり、本リポジトリ（group.worldtalk）はその**グループレッスン**を実施するためのシステムである。

- **マンツーマンレッスン**: 元々ワールドトークの本システムで、1対1の予約・決済・レッスン管理を行っている。
- **グループレッスン**: 上記のマンツーマン用のDB・アプリを流用し、「無理やり」グループ仕様で運用している。

### 1.2 技術スタック（現行）

| 項目 | 内容 |
|------|------|
| DB | MariaDB 10.5（データベース名: `wte`） |
| バックエンド | Perl（FCC フレームワーク）、CGI |
| フロント | HTML / AdminLTE 等 |
| メール | テンプレート（tmpls）＋Sendmail/SMTP |

### 1.3 主なユーザー・画面

- **会員（受講生）**: マイページ（mypage.cgi）でコース一覧・スケジュール表示・予約・予約確認・ポイント/クーポン決済
- **講師（prof）**: 講師画面（prof.cgi）でコース登録・スケジュール登録・レッスン一覧・レッスン報告
- **管理者（Admin）**: 管理画面で会員・講師・コース・レッスン・売上・ポイント等の管理

---

## 2. 現行データベース構造とグループレッスンの扱い

### 2.1 関連テーブル一覧

| テーブル名 | 役割 |
|------------|------|
| **courses** | 授業（コース）マスタ。マンツーマン用コースとグループ用コースが混在。`course_group_flag` でグループ判別。 |
| **lessons** | **1件 = 1回のレッスン「1講師×1会員×1日時」**。マンツーマンは1枠1件、グループは「1回の集団授業」に対して**受講者ごとに1件ずつ**レコードが立つ。 |
| **schedules** | 講師の開講枠。1枠 = 30分単位。マンツーマンは `lsn_id` で予約済みか紐づく。グループは `group_id` を持ち、`lsn_id` は常に0。 |
| **group_schedules** | グループ用の「1回の開講スロット」。1レコード = 1回のグループレッスン枠（日時・コース・定員）。`lsn_id` は未使用(0)。 |
| **members** | 会員マスタ |
| **profs** | 講師マスタ |
| **mbracts** | 会員のポイント/クーポン消費履歴（`lsn_id` でレッスンに紐づく） |
| **cards** | 決済（購入）履歴 |
| **sellers** | 販売元（運営等） |

### 2.2 現行のグループレッスン用カラム（courses）

- `course_group_flag` : グループレッスンかどうか（1=グループ）
- `course_group_upper` : 定員の上限（例: 10）
- `course_group_limit` : 定員の下限（未使用または0のことが多い）
- その他: `course_meeting_url`（Zoom/Meet URL）、`course_mail_s`/`course_mail_e`（開始・終了メール文面）、`course_syllabus`、`course_total_lessons` など

### 2.3 現行フロー（グループレッスン）

#### 2.3.1 講師がグループ枠を登録するとき（SchaddsetAction.pm）

1. 日付・開始〜終了時刻・コース・定員（`g_ct`）を入力。
2. **group_schedules** に1件 INSERT（`prof_id`, `course_id`, `group_count`, `sch_stime`, `sch_etime`）。`group_count` は定員。
3. 登録した時間帯を **30分単位** に分割し、**schedules** にその数だけ INSERT。
   - 各レコード: `prof_id`, `course_id`, `group_id`（上記で採番されたID）, `group_start_flag`（先頭枠のみ1）, `group_count`（定員のコピー）, `lsn_id`=0。

結果: **1回のグループレッスン** = **group_schedules 1件** + **schedules 複数件**（例: 1時間なら2件）。

#### 2.3.2 会員がグループレッスンを予約するとき（LsnrsvsetAction.pm + Lesson.pm）

1. 会員は「空き枠」として表示されている **schedules** のうち、そのグループの**先頭スロットの sch_id** を選んで予約する（複数スロット分の sch_id のリストが渡る）。
2. **lessons** に **1件 INSERT**（`prof_id`, `member_id`, `seller_id`, `course_id`, `lsn_stime`, `lsn_etime`, 料金・支払種別など）。
   - つまり「同じ日時・同じコース」のグループレッスンに10人参加していれば、**lessons に10件**（member_id だけ違う）が並ぶ。
3. グループの場合: その **sch_id リスト** の各 schedule に対して  
   `UPDATE schedules SET group_count = group_count - 1` のみ実行。  
   **lsn_id は更新しない**（グループでは schedules.lsn_id は常に0のまま）。

#### 2.3.3 キャンセル時（Lesson.pm member_cancel_set）

1. **lessons** の該当レコードをキャンセル扱いに更新。
2. そのレッスンの `course_id` と `lsn_stime` で **schedules** から `group_id` を取得。
3. 同じ `group_id` を持つ **schedules** 全件に対して `group_count = group_count + 1` で戻す。

### 2.4 現行構造で「無理している」点（課題）

1. **lessons が「1対1」前提**
   - 1回のグループレッスン = 同じ (course_id, lsn_stime, lsn_etime) の **lessons が定員分だけ重複**。
   - 「1回のグループレッスン」を1つの実体として扱えず、集計・一覧・キャンセル時も「同じ日時・同じコースの lessons をかき集める」必要がある。

2. **schedules の二重役割**
   - マンツーマン: 1枠 = 1 schedule、予約で `lsn_id` が立つ。
   - グループ: 1回の開講 = 同じ `group_id` の schedule が複数（30分刻み）、`lsn_id` は使わず `group_count` の増減のみ。
   - 空き状況の判定が「group_count > 0」と「lsn_id = 0」で分岐し、コードが分かりにくい。

3. **group_schedules と lessons のつながりが弱い**
   - `group_schedules` には `lsn_id` カラムがあるが未使用（0のまま）。
   - 「この group_schedules に誰が申し込んでいるか」を出すには、`group_schedules` → `schedules`（group_id）→ 同じ course_id + sch_stime の **lessons** を検索する必要があり、冗長で整合性も取りにくい。

4. **定員管理の冗長性**
   - 定員（残り枠）が **schedules** の `group_count` に「同じ group_id の全行に同じ値」で持たれており、1行だけ見ればよいが、更新時は複数行をまとめて扱う必要がある。

5. **集計・レポート**
   - 「あるグループレッスン回の参加者一覧」「あるコースの全回の出席状況」などは、lessons を course_id + 日時でグルーピングする必要があり、パフォーマンス・保守性ともに不利。

---

## 3. グループレッスン用DB設計案（新規・改修）

以下は、**グループレッスンに特化したテーブルを用意し、レッスン管理をそこで行う**ための案である。  
マンツーマン用の **lessons / schedules** は現行のまま残し、グループのみ新テーブルで扱う形を想定する。

### 3.1 方針

- **グループ専用の「開講スロット」と「申込」を明確に分離**する。
- 1回のグループレッスン = **1スロット**。参加者 = そのスロットへの**申込 N 件**。
- 既存の **courses** はそのまま利用（グループ用コースのマスタとして）。必要に応じて `course_id` で紐づける。
- 既存の **lessons** は、**マンツーマン専用**とする。グループ用の「出席・支払い・報告」は新テーブルで管理し、必要なら後から lessons と連携（履歴用に1行だけ入れる等）は検討可能。

### 3.2 新規テーブル案

#### 3.2.1 グループ開講スロット（例: `group_lesson_slots`）

| カラム名 | 型 | 説明 |
|----------|-----|------|
| slot_id | BIGINT UNSIGNED PK AUTO_INCREMENT | スロットID |
| course_id | BIGINT UNSIGNED NOT NULL | コース（courses.course_id） |
| prof_id | BIGINT UNSIGNED NOT NULL | 講師（profs.prof_id） |
| slot_stime | DATETIME NOT NULL | 開始日時 |
| slot_etime | DATETIME NOT NULL | 終了日時 |
| capacity_max | SMALLINT UNSIGNED NOT NULL | 定員 |
| capacity_current | SMALLINT UNSIGNED NOT NULL DEFAULT 0 | 現在の申込数（予約数） |
| status | TINYINT UNSIGNED NOT NULL DEFAULT 1 | 1=受付中, 2=終了, 3=中止 等 |
| cdate | INT UNSIGNED NOT NULL | 作成日時（Unix time） |
| mdate | INT UNSIGNED NOT NULL DEFAULT 0 | 更新日時 |

- 1レコード = **1回のグループレッスン枠**。
- 空き状況は `capacity_current < capacity_max` で判定可能。
- 既存の **group_schedules** と **schedules（group_id 付き）** の「1回の開講」に相当する情報を、この1テーブルに集約するイメージ。

#### 3.2.2 グループレッスン申込（例: `group_lesson_bookings`）

| カラム名 | 型 | 説明 |
|----------|-----|------|
| booking_id | BIGINT UNSIGNED PK AUTO_INCREMENT | 申込ID |
| slot_id | BIGINT UNSIGNED NOT NULL | 上記スロットID |
| member_id | BIGINT UNSIGNED NOT NULL | 会員（members.member_id） |
| seller_id | BIGINT UNSIGNED NOT NULL | 販売元（sellers.seller_id） |
| pay_type | TINYINT UNSIGNED NOT NULL | 1=ポイント, 2=クーポン 等 |
| price | INT UNSIGNED NOT NULL | 支払い単価（ポイント or 金額） |
| coupon_id | BIGINT UNSIGNED NOT NULL DEFAULT 0 | 使用クーポンID |
| status | TINYINT UNSIGNED NOT NULL DEFAULT 1 | 1=予約済, 2=出席済, 3=キャンセル 等 |
| cancel_reason | TEXT | キャンセル理由（任意） |
| cdate | INT UNSIGNED NOT NULL | 申込日時 |
| mdate | INT UNSIGNED NOT NULL DEFAULT 0 | 更新日時 |

- 1レコード = **1人分の申込**。
- 「この回に誰が参加しているか」は `slot_id` で一覧できる。
- ポイント/クーポン消費は既存 **mbracts** に `booking_id` や「グループ用」の reason を足して紐づけるか、別テーブルで管理するかは要件次第。

#### 3.2.3 既存テーブルとの対応

- **group_schedules**  
  - 役割は **group_lesson_slots** に吸収。マイグレーションでデータ移行後、廃止または「参照用」に残すか検討。
- **schedules（group_id あり）**  
  - グループ用の枠表示・予約フローは **group_lesson_slots** 基準に変更。既存 schedules の group 関連は段階的に廃止するか、並行期間中は両方更新するかで対応。
- **lessons**  
  - グループ用の新規予約では **lessons に挿入しない**。既存のグループ用 lessons は、移行時に **group_lesson_bookings** へ対応するレコードを生成し、履歴参照用に lessons を残すかどうかは要件次第。

### 3.3 運用イメージ（新設計後）

1. **講師がグループ枠を登録**  
   - **group_lesson_slots** に1件 INSERT（course_id, prof_id, 開始・終了、定員）。  
   - 既存の group_schedules + schedules への登録は行わない（または互換のため一時的に両方書く）。

2. **会員が予約**  
   - 空きがある **group_lesson_slots** を選択。  
   - **group_lesson_bookings** に1件 INSERT。  
   - 該当 **group_lesson_slots** の `capacity_current` を +1。  
   - ポイント/クーポンは既存ロジックに合わせて mbracts 等で処理。

3. **キャンセル**  
   - **group_lesson_bookings** の status をキャンセルに更新。  
   - 該当 **group_lesson_slots** の `capacity_current` を -1。  
   - 返却処理は既存のポイント/クーポン仕様に合わせる。

4. **一覧・集計**  
   - 「あるコースの今後のグループレッスン一覧」: group_lesson_slots を course_id・日時で検索。  
   - 「ある回の参加者一覧」: group_lesson_bookings を slot_id で検索。  
   - レポートや管理画面は、これらのテーブルを主軸に実装可能。

---

## 4. 改修時の進め方（推奨）

1. **Phase 1: 新テーブル追加とマイグレーション**
   - `group_lesson_slots` / `group_lesson_bookings` を作成。
   - 既存の **group_schedules** および **schedules（group_id 付き）** と **lessons（グループ分）** から、スロット・申込データを移行するスクリプトを用意。
   - 移行後も既存テーブルのデータは一定期間残し、参照のみに使う。

2. **Phase 2: アプリの二本立て**
   - グループレッスン用の「枠登録」「予約」「キャンセル」「一覧」を、新テーブルを読む/書くように実装（新画面または既存画面の分岐）。
   - 既存の group_schedules / schedules / lessons を触るグループ用処理は、段階的に新テーブル用に切り替え。

3. **Phase 3: 旧グループ用データの廃止**
   - すべてのグループ関連処理が新テーブル経由になったら、グループ用の **schedules** 登録・**group_schedules** の新規作成を止める。
   - **lessons** へのグループ用の新規 INSERT を止める。
   - 必要に応じて **group_schedules** を削除またはアーカイブ用にリネーム。

4. **Phase 4: 履歴・レポートの統一**
   - 管理画面・講師画面の「グループレッスン一覧」「参加者一覧」「売上」などを、すべて新テーブル（＋必要なら lessons/mbracts）ベースに統一。

---

## 5. 補足：主要ファイル一覧（グループ関連）

| ファイル | 役割 |
|----------|------|
| WTE/lib/FCC/Action/Prof/SchaddsetAction.pm | 講師がスケジュール（グループ枠含む）を登録 |
| WTE/lib/FCC/Action/Prof/SchdelsetAction.pm | 講師がスケジュール（グループ枠）を削除 |
| WTE/lib/FCC/Action/Mypage/LsnrsvsetAction.pm | 会員がレッスンを予約（グループ・マンツーマン共通） |
| WTE/lib/FCC/Class/Schedule.pm | schedules / group_schedules の取得・一覧・削除 |
| WTE/lib/FCC/Class/Lesson.pm | lessons の追加・キャンセル・group_count の増減 |
| WTE/lib/FCC/Class/Course.pm | courses の取得・一覧（course_group_flag 等） |
| WTE/lib/FCC/View/Prof/SchlstfrmView.pm | 講師スケジュール一覧（グループ枠表示） |

---

## 6. まとめ

- 現行システムは**マンツーマン用の lessons / schedules を流用**してグループレッスンを実装しており、**1回のグループレッスンが「複数 lessons」「複数 schedules + group_schedules」に分散**している。
- **グループレッスン専用の「スロット」と「申込」テーブル**（本仕様書の `group_lesson_slots` / `group_lesson_bookings`）を導入し、レッスン管理をそこで完結させることで、見通しの良い設計と運用が可能になる。
- 既存の **courses** / **members** / **profs** / **mbracts** 等はそのまま活用し、段階的な移行と切り替えで、サービスを止めずに改修できる。

以上を踏まえ、グループレッスン用DBの新規用意と、それに伴うアプリ改修を進めることを推奨する。

---

## 付録A: 新規テーブル CREATE 文（案）

```sql
-- グループレッスン開講スロット（1回の枠 = 1レコード）
CREATE TABLE `group_lesson_slots` (
  `slot_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `course_id` bigint(20) UNSIGNED NOT NULL,
  `prof_id` bigint(20) UNSIGNED NOT NULL,
  `slot_stime` datetime NOT NULL,
  `slot_etime` datetime NOT NULL,
  `capacity_max` smallint(5) UNSIGNED NOT NULL,
  `capacity_current` smallint(5) UNSIGNED NOT NULL DEFAULT 0,
  `status` tinyint(3) UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=受付中 2=終了 3=中止',
  `cdate` int(10) UNSIGNED NOT NULL,
  `mdate` int(10) UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`slot_id`),
  KEY `group_lesson_slots_course_id_idx` (`course_id`),
  KEY `group_lesson_slots_prof_id_idx` (`prof_id`),
  KEY `group_lesson_slots_slot_stime_idx` (`slot_stime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- グループレッスン申込（1人1回 = 1レコード）
CREATE TABLE `group_lesson_bookings` (
  `booking_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `slot_id` bigint(20) UNSIGNED NOT NULL,
  `member_id` bigint(20) UNSIGNED NOT NULL,
  `seller_id` bigint(20) UNSIGNED NOT NULL,
  `pay_type` tinyint(3) UNSIGNED NOT NULL COMMENT '1=ポイント 2=クーポン',
  `price` int(10) UNSIGNED NOT NULL,
  `coupon_id` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
  `status` tinyint(3) UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=予約済 2=出席済 3=キャンセル',
  `cancel_reason` text DEFAULT NULL,
  `cdate` int(10) UNSIGNED NOT NULL,
  `mdate` int(10) UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`booking_id`),
  KEY `group_lesson_bookings_slot_id_idx` (`slot_id`),
  KEY `group_lesson_bookings_member_id_idx` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```

---

## 付録B: 用語・略称

| 用語 | 説明 |
|------|------|
| WTE | 本システムのルートディレクトリ名（Web / アプリの実体） |
| FCC | 本システムで利用している Perl フレームワークのプレフィックス |
| prof | 講師（professor） |
| lsn | レッスン（lesson） |
| sch | スケジュール（schedule） |
| mbract | 会員の取引履歴（member action） |
| seller_id | 販売元（運営など）を表すID。courses に紐づく販売元と連携 |
