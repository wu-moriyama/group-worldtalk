$(document).ready(function(){
	$('.replace').each(function(){
		var txt = $(this).html();
		$(this).html(
			txt.replace(/ビジネス日本語/g,'Business Japanese')
			   .replace(/観光/g,'Sightseeing')
			   .replace(/JLPT対策/g,'Measure to Pass JLPT')
			   .replace(/日本留学の学習/g,'Overseas Studies in Japan')
			   .replace(/日常会話ができる/g,'Can manage daily conversations')
			   .replace(/日常会話/g,'Daily Conversation')
			   .replace(/その他/g,'Others')
			   .replace(/ビジネス/g,'Business')
			   .replace(/ビギナー/g,'Beginner')
			   .replace(/JLPT N1レベル/g,'JLPT N1 Level')
			   .replace(/JLPT N2レベル/g,'JLPT N2 Level')
			   .replace(/JLPT N3レベル/g,'JLPT N3 Level')
			   .replace(/JLPT N4レベル/g,'JLPT N4 Level')
			   .replace(/全く話せない/g,'Can\'t speak at all')
			   .replace(/単語が分かる程度/g,'Can understand words')
			   .replace(/簡単な会話ができる/g,'Can manage simple conversations')
			   .replace(/映画・音楽/g,'Movies & Music')
			   .replace(/スポーツ/g,'Sports')
			   .replace(/旅行/g,'Travel')
			   .replace(/読書/g,'Reading')
			   .replace(/グルメ・お酒/g,'Gourmet & Sake')
			   .replace(/美容・ファッション/g,'Beauty & Fashion')
			   .replace(/政治・経済/g,'Politics & Finance')
			   .replace(/外国語/g,'Foreign language')
			   .replace(/アニメ・マンガ/g,'Anime & Manga')
			   .replace(/ゲーム/g,'Games')
			   .replace(/アウトドア/g,'Outdoors')
		);
	});
	$('.replace2').each(function(){
		var txt2 = $(this).html();
		$(this).html(
			txt2.replace(/総合日本語初級前半/g,'Comprehensive Japanese Elementary Level 1')
			   .replace(/総合日本語初級後半/g,'Comprehensive Japanese Elementary Level 2')
			   .replace(/JLPT N1 総合コース/g,'JLPT N1 Comprehensive Course')
			   .replace(/JLPT N1 文字語彙・文法コース/g,'JLPT N1 Writing, Vocabulary and Grammar Course')
			   .replace(/JLPT N2 総合コース/g,'JLPT N2 Comprehensive Course')
			   .replace(/JLPT N2 文字語彙・文法コース/g,'JLPT N2 Writing, Vocabulary and Grammar Course')
			   .replace(/JLPT N3 総合コース/g,'JLPT N3 Comprehensive Course')
			   .replace(/JLPT N3 文字語彙・文法コース/g,'JLPT N3 Writing, Vocabulary and Grammar Course')
			   .replace(/JLPT N4 総合コース/g,'JLPT N4 Comprehensive Course')
			   .replace(/ビジネス日本語 初中級/g,'Business Japanese Beginner-Intermediate Level')
			   .replace(/ビジネス日本語 中級/g,'Business Japanese Intermediate Level')
		);
	});
});