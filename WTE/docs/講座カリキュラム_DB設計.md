# 講座カリキュラム DB設計案

## 要件整理

- **列**: 3列固定
  - パターンA: DAY | レッスン内容 | 宿題
  - パターンB: DAY | レッスン内容 | 到達目標
- **行**: 講座回数に応じて可変。UIで行の追加・削除が可能。
- **保存**: 一括で読み書きできればよい（行単位の検索・集計は不要）。

---

## 推奨: JSON 1列で保存

### 結論

**1本の TEXT/JSON 列に JSON で保存する方式を推奨します。**

- 列を「宿題／到達目標」で切り替え可能なまま、スキーマ変更なしで対応できる。
- 行数は自由に増減でき、UI の「追加・削除」と整合しやすい。
- 取得・保存は「1講座 = 1レコードの 1 カラム」だけ扱えばよく、実装が単純。

### テーブル変更（courses に追加）

```sql
-- 講座カリキュラム（JSON）
-- column_type: 'homework' = 3列目は「宿題」, 'goal' = 3列目は「到達目標」
-- rows: [{ "day": 1, "lesson": "内容", "col3": "宿題または到達目標" }, ...]
ALTER TABLE courses
  ADD COLUMN course_curriculum TEXT DEFAULT NULL
  COMMENT '講座カリキュラムJSON: { columnType, rows[] }'
  AFTER course_total_lessons;
```

- MySQL 5.7 以上なら `JSON` 型も使えますが、既存が TEXT 中心なら **TEXT** のままでも問題ありません（アプリで JSON 文字列として扱う）。

### JSON の形（案）

```json
{
  "columnType": "homework",
  "rows": [
    { "day": 1, "lesson": "導入・ガイダンス", "col3": "自己紹介シート記入" },
    { "day": 2, "lesson": "長文読解の型", "col3": "問題集 p.10-15" }
  ]
}
```

- **columnType**: `"homework"` → 3列目は「宿題」、`"goal"` → 3列目は「到達目標」。
- **rows**: 1行が 1 回分。`day` は表示用（DAY 列）、`lesson` はレッスン内容、`col3` は宿題または到達目標。
- 行の追加・削除は `rows` 配列の要素の増減だけで表現できる。

### 運用上の注意

- 保存前に `rows` の長さと `course_total_lessons` を揃えるかどうかは運用次第。
  - 揃える場合: 保存時に `course_total_lessons` を `rows.length` に更新する。
  - 揃えない場合: 講座回数は「回数」だけ、カリキュラムは「中身」だけ持つ（初期表示時だけ講座回数で行数を合わせるなど）。

---

## 別案: 正規化テーブル（参考）

「行ごとに検索・集計したい」「RDB らしく正規化したい」場合は、別テーブルもありです。

```sql
CREATE TABLE course_curriculum (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  course_id BIGINT UNSIGNED NOT NULL,
  ord SMALLINT UNSIGNED NOT NULL COMMENT '表示順',
  day_display VARCHAR(20) NOT NULL DEFAULT '' COMMENT 'DAY列表示（1, 2, 3 or Day1等）',
  lesson_content TEXT NOT NULL DEFAULT '',
  homework TEXT DEFAULT NULL COMMENT 'column_type=homeworkのとき',
  goal TEXT DEFAULT NULL COMMENT 'column_type=goalのとき',
  UNIQUE KEY (course_id, ord)
);
```

- 3列目を「宿題／到達目標」で切り替える場合は、`column_type` を courses 側に持たせ、表示時に `homework` か `goal` のどちらを使うか決める形になる。
- 行の追加・削除は `INSERT`/`DELETE` と `ord` の振り直しが必要で、UI とバックエンドの処理が JSON より重くなります。
- 今回の要件（一覧表示・編集が中心で、行キーでの検索がほぼ不要）であれば、**まずは JSON 1列で十分**だと思います。

---

## 実装ステップ案（JSON 方式）

1. **マイグレーション**  
   - 上記の `ALTER TABLE` で `course_curriculum` を追加。

2. **バックエンド**  
   - Course.pm: `course_curriculum` を読んでそのまま返す／受け取った JSON 文字列をそのまま保存。  
   - 必要なら「不正な JSON は保存しない」程度のバリデーションを追加。

3. **Prof フォーム（Couadd / Coumod）**  
   - Step.3「講座カリキュラム」に  
     - 列タイプ切替: ラジオなどで「宿題」「到達目標」を選択 → `columnType` に反映。  
     - テーブル UI: `rows` を編集。行追加・削除ボタンで `rows` の配列を操作。  
   - 送信時: 編集結果を `rows` + `columnType` にまとめて JSON 化し、`course_curriculum` として送る。

4. **表示側（サイト・マイページ）**  
   - `course_curriculum` をパースし、`columnType` に応じてヘッダーを「宿題」か「到達目標」にし、`rows` をテーブルで表示。

この順で進めれば、DB は「JSON 1列の追加」だけで、UI の追加・削除や列切り替えに柔軟に対応できます。
