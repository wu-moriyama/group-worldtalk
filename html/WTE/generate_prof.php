<?php
$data = json_decode(file_get_contents("php://input"), true);

$prof_name    = $data["prof_name"]    ?? "";
$achievements = $data["achievements"] ?? "";
$strengths    = $data["strengths"]    ?? "";
$length       = $data["length"]       ?? 250; // 初期値 500文字

$system_prompt = "あなたはオンライン英会話『ワールドトーク』の講師プロフィール文を生成するAIです。

▼ 出力ルール
・出力は必ず HTML（<p> <ul> <li> <strong> <br> のみ使用）
・絶対にコードブロック（```）で囲まない
・文章は読みやすく柔らかいトーンにする
・強調したい箇所は <strong> または
  <span style=\"background-color:#F8E465;\"><strong>強調文</strong></span>
  の形式で “マーカー強調” を積極的に使用してよい
・絵文字（🎉✨📚🔥🌟💡）を適度に使用し、硬すぎない印象にする
・プロフィールとして自然で信頼感のある文体にする
・解説や前置きは不要。生成された HTML のみ返すこと。

▼ 文章構成（必ず守る）
1. <p>導入文：講師名を自然に入れて、どんな指導スタイルか簡潔に紹介</p>
2. <p>これまでの実績（上で与えられた情報を要約）</p>
3. <ul><li>強みを3つ程度、箇条書きで</li></ul>
4. <p>最後に「どんな方におすすめか」「どんなレッスンになるか」をまとめる</p>
";

$user_prompt = "以下の内容をもとに、250文字程度の講師プロフィール文（HTML）を生成してください。

【講師名】
{$prof_name}

【実績（資格・経歴・講師歴など）】
{$achievements}

【強み（3つ程度）】
{$strengths}

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
