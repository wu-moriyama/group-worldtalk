# 休講日（course_holiday_dates）機能 設計メモ

## 要件整理

- **休講日**：講座開始日〜講座終了日の「間」にある日付で、その日はレッスンを実施しない。
- **複数日**を指定できる（例：毎週火曜だが 3/15, 3/22 だけ休講など）。
- **一括予約（lsnalladd / add_bulk_from_course）**で、休講日はスキップして日程を生成したい。

## 現状の一括登録の動き

- `Lesson.pm` の `get_course_schedule_preview($course_id)` が以下で日程を生成している。
  - `course_start_date` から 1 日ずつ進める。
  - 各日が `course_weekday_mask` に含まれる曜日なら `@schedule_dates` に追加。
  - `course_total_lessons` 件たまるまで繰り返し（上限 3 年分）。
- `course_end_date` は**現在ループの終了条件に使っていない**（件数で打ち切り）。
- この `@schedule_dates` を `add_bulk_from_course` が利用して lessons / group_lesson_slots を登録。

## データ設計案

### 案A：courses に 1 カラム追加（推奨）

| カラム名 | 型 | 説明 |
|----------|-----|------|
| `course_holiday_dates` | TEXT | 休講日を複数格納。区切りは改行またはカンマ。例: `2025-03-15\n2025-03-22` または `2025-03-15,2025-03-22` |

- **メリット**: マイグレーションが 1 カラム追加だけ。既存の Course 取得・保存の流れにそのまま載せやすい。
- **保存形式**: 1 行 1 日付（`YYYY-MM-DD`）の改行区切りを推奨。パース・バリデーションが単純。

### 案B：別テーブル course_holidays

| テーブル | カラム |
|----------|--------|
| course_holidays | course_id, holiday_date (DATE), など |

- **メリット**: 正規化され、「この日は休講か」の検索がしやすい。
- **デメリット**: テーブル追加・JOIN・一括登録時の取得が増える。Admin/Prof のフォームで「複数行の追加・削除」の扱いが必要。

**まずは案Aで進めるのが実装コスト・運用のバランスが良い**と考えられます。

---

## バリデーション（Course.pm）

- `course_holiday_dates` を改行 or カンマで split し、各要素をトリム。
- 各要素について:
  - 形式は `YYYY-MM-DD` のみ許可。
  - **講座開始日以上・講座終了日以下**であることを必須にする（開始日・終了日が未設定の場合はエラー or スキップで方針を決める）。
- 重複日付は保存前にユニーク化してよい。

---

## Lesson.pm の変更（一括予約で休講日スキップ）

`get_course_schedule_preview` 内で:

1. `course_holiday_dates` をパースし、休講日の集合（例: `Set::Scalar` や `map { $_ => 1 }` のハッシュ）を用意。
2. 既存の `while` ループで「曜日マスクにヒットした日」を `push` する直前に、
   - `$t_date->ymd` が休講日集合に含まれるなら **何もせずに `$t_date += ONE_DAY` して次へ**。
   - 含まれない場合だけ `push` と `$found_count++` を行う。

これで「開催曜日・開催時間」はそのままで、**休講日だけ一括予約の日程から外れます**。

（必要なら、`course_end_date` を超えたらループを打ち切る処理も同時に入れられます。）

---

## UI 案（複数日をどう入れるか）

### 1. テキストエリア（1 行 1 日付）【実装簡単・推奨】

- ラベル「休講日（1行に1日付で YYYY-MM-DD）」
- `<textarea>` に例を placeholder 表示: `2025-03-15` 改行 `2025-03-22`
- 保存時・表示時に「開始日〜終了日の間」と形式のバリデーション。
- **メリット**: 実装が軽い。Admin / Prof の couadd・coumod の「講座開始日・終了日」の近く（または「開催曜日・開催時間」の下）に 1 項目追加するだけ。
- **デメリット**: 日付の手入力が中心になる（コピペや手打ち）。

### 2. 日付ピッカー＋「追加」でリスト表示

- 日付を 1 つ選んで「追加」ボタン → リストに追加。各行に削除ボタン。
- 送信時は配列 or 改行区切りテキストで送る。
- **メリット**: 操作が直感的。誤入力が減る。
- **デメリット**: JS の実装量が増える。既存の flatpickr 等を流用可能。

### 3. 繰り返し入力（複数 input type="date"）

- 「休講日1」「休講日2」… とフィールドを並べ、必要なら「もう1件追加」で input を動的追加。
- **メリット**: フォームの見た目が分かりやすい。
- **デメリット**: 空の input の扱い、最大件数、並び順の考慮が必要。

---

## 実装の順序提案

1. **DB**: `courses` に `course_holiday_dates` (TEXT NULL) を追加。
2. **Course.pm**:  
   - テーブル定義・input_check で `course_holiday_dates` を扱う。  
   - パースと「開始日〜終了日の間」のバリデーションを追加。
3. **Lesson.pm**: `get_course_schedule_preview` で休講日をパースし、該当する日は `@schedule_dates` に含めない。
4. **Admin**: Coumodfrm / Couaddfrm に「休講日」を追加（講座開始日・終了日・開催曜日・開催時間の近く）。まずは **textarea（1行1日付）** でよい。
5. **Prof**: 同様に couadd / coumod に「休講日」の textarea を追加。
6. （任意）プレビューや一括登録確認画面で「休講日を除いた日程」が分かるように表示。
7. ~~（任意）UI を「日付ピッカー＋リスト」に差し替え。~~ → **実装済み（日付ピッカー＋追加ボタン＋バッジリスト＋削除）**

---

## 実装済み（要 DB マイグレーション）

- **DB**: `wte.sql` の CREATE TABLE に `course_holiday_dates` を追加。既存DB用に `docs/sql_add_course_holiday_dates.sql` で ALTER を実行すること。
- **Course.pm**: table_cols / csv_cols / input_check（開始日〜終了日の間・YYYY-MM-DD・重複除去）。
- **Lesson.pm**: `get_course_schedule_preview` で休講日をパースし、該当日は `@schedule_dates` に含めない。
- **Admin**: Coumodfrm / Couaddfrm に休講日ブロック（flatpickr 日付のみ＋「追加」＋バッジリスト＋hidden textarea）。
- **Prof**: Couaddfrm / Coumodfrm に同様の休講日UI。
- **各 Set/Frm Action**: `course_holiday_dates` を in_names または初期値に追加済み。

---

## 補足

- **講座終了日**を `get_course_schedule_preview` のループ終了条件に含めるかは別チケットでもよい。休講日とは独立した仕様。
- 休講日は「日」単位で持つ想定。同一日の複数時間帯を個別に休講にする必要があれば、その時点で設計を見直す（現状は 1 日単位で十分と仮定）。
