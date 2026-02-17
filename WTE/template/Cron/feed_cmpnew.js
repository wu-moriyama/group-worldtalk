conban_cmpnew({
	"title": "コンテンツ・バンク　新着コンペ",
	"link": "http://www.conban.jp/cb/cmpnew",
	"updated": "%cdate%",
	"entry": [<TMPL_LOOP NAME="list_loop">
		{
			"title": %j_cmp_title%,
			"link": "http://www.conban.jp/cb/cmpdtl/%cmp_id%",
			"id": "http://www.conban.jp/cb/cmpdtl/%cmp_id%",
			"published": "%cmp_cdate%",
			"author": { "name": %j_seller_company% },
			"summary": %j_cmp_summary%
		}<TMPL_UNLESS NAME="__last__">,</TMPL_UNLESS></TMPL_LOOP>
	]
})