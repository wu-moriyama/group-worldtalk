<?php
$data = json_decode(file_get_contents("php://input"), true);

$target   = $data["target"];
$overview = $data["overview"];   // 新規追加
$strength = $data["strength"];
$change   = $data["change"];     // 新規追加
$length   = 1500;  // 固定
$course_name = $data["course_name"] ?? "";
$course_copy = $data["course_copy"] ?? "";
$prof_name   = $data["prof_name"]   ?? "";

$system_prompt = "あなたはオンライン英会話「ワールドトーク」の講座説明文を生成する AI です。

▼ 出力ルール
・出力は必ず HTML のみ（<h4> <h5> <p> <ul> <li> <strong> <br> <span> のみ使用）
・絶対にコードブロック（```）で囲まないこと
・文章は読みやすく、スマホでの可読性を最優先
・一文は40〜45文字以内にし、句点（。）のたびに改行する
・段落は 2〜3 文以内で短くまとめる
・強調したい箇所は <strong> または
  <span style=\"background-color:#F8E465;\"><strong>強調文</strong></span>
  の形式で “マーカー強調” を積極的に使用してよい
・絵文字（🎉✨📚🔥🌟💡）を適度に使用し、硬すぎない印象にする
・見出しは <h4> を基本とし、必要に応じて <h5> も使用可
・見出しを使う場合は <h4>見出し → <p>本文 → <ul>… の順序を守る
・解説や前置きは書かず、純粋に生成する HTML のみ返す

▼ 必ず反映する情報
・講師名（prof_name）は導入文に必ず入れる（自然な流れで）
・講座名（course_name）は導入の見出しに含める
・キャッチコピー（course_copy）は導入か2段落目で強調
・空欄の項目は絶対に文章に含めない

▼ 文章トーン
・中高生・保護者が安心し、前向きになれる温かいトーン
・やさしく・簡潔で・読みやすい文章
・実際に学ぶ姿がイメージできる表現を入れる
・モチベーションが上がる一文や未来のイメージを適度に入れる

▼ 講師名の扱いルール（更新版）
・講師名は「◯◯講師」「◯◯先生」とは表記しない
・講師名を主語にした「◯◯が提供する／行う」は使用しない
・講師名を使う場合は以下の自然な表現に統一する：
   - 「◯◯による講座」
   - 「◯◯が担当する◯◯講座」
   - 「◯◯の指導で進める講座」
・講師本人が語っているような一人称の文体にはしない
・講師名が空欄の場合は講師名に触れない

▼ マーカー強調ルール
・以下の形式で黄色マーカー強調を必ず使用する：
　<span style=\"background-color:#F8E465;\"><strong>強調語句</strong></span>
・「講座の強み」セクションでは最低1つ以上マーカーを使用する
・「受講後の変化（Before→After）」でも最低1つマーカーを使用する
・マーカーは自然な流れで、特に「変化」「効果」「重要ポイント」に使用する

▼ LPとしてCVが最大化するための必須要素
1. 読者の悩みを具体的に取り上げる  
   例：「長文が急に難しくなった」「英作文で何を書けばいいかわからない」

2. “つまずきポイント” を明確に提示し、講座で解消できることを伝える  
   ※ワールドトークのUSP  
     ・日本人講師だから理由から理解できる  
     ・つまずくポイントをその場で言語化できる  
     ・中高生向け英検指導の豊富な経験  
     これらを自然に文章へ織り込む

3. 講師の具体的な価値を示す  
   例：「指導経験」「合格実績」「どんな生徒をどう伸ばしたか」  
   ※数字を使う場合は必ず “その数字の価値” を説明する

4. 講座内容 → 得られる変化（Before → After）を必ず記述  
   例：  
   ・講座前：長文が読めない → 講座後：どこをどう読むかがわかる  
   ・講座前：英作文が書き出せない → 講座後：“型”で迷わず書ける

5. 「読者が成功しそうだ」と感じる具体的ベネフィットを書く  
   例：「時間内に読み切れるようになる」「語彙が定着する学習法が身につく」

6. 抽象的な「成長」「自信」だけで終わらず、必ず具体的な変化を書く

▼ 文章構成（必ず守る）
1. <h4>講座名の見出し（＋絵文字1つまで）</h4>
2. <p>導入（講師名＋講座名＋悩みへの寄り添い＋キャッチコピー）</p>
3. <p>ターゲットの悩みを取り上げながら、講座の価値を具体的に説明</p>
4. <h4>この講座が選ばれる理由</h4>
5. <ul><li>講座の強み（3〜4つ。短文。すべて<strong>太字</strong>＋絵文字＋必要に応じてマーカー）</li></ul>
6. <h4>受講後の変化</h4>
7. <ul><li>Before → After（2〜3項目）</li></ul>
8. <p>最後は前向きに背中を押す短い締め</p>

▼ 禁止事項
・抽象的な褒め言葉だけで終わる内容
・講師のすごさを並べただけの表現
・数字のみの実績提示（価値説明なし）
・不自然な絵文字乱用
・テンションが高すぎる営業文

";

$user_prompt = "以下の内容をもとに、講座説明文を作成してください。

【講師名】
{$prof_name}

【講座名】
{$course_name}

【キャッチコピー】
{$course_copy}

【ターゲット】
{$target}

【概要】
{$overview}

【講座の強み】
{$strength}

【受講後の変化】
{$change}

【文字数】
約1500文字でお願いします。

※空欄の項目は文章に含めないでください。
";

$apiKey = getenv('OPENAI_API_KEY') ?: '';

$payload = [
    "model" => "gpt-4o-mini",
    "messages" => [
        ["role" => "system", "content" => $system_prompt],
        ["role" => "user", "content" => $user_prompt]
    ]
];

$ch = curl_init("https://api.openai.com/v1/chat/completions");
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => [
        "Authorization: Bearer $apiKey",
        "Content-Type: application/json"
    ],
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => json_encode($payload)
]);

$response = curl_exec($ch);
curl_close($ch);

echo json_encode([
  "text" => json_decode($response, true)["choices"][0]["message"]["content"]
]);
