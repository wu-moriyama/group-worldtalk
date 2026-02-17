(function () {

dom.event.addEventListener(window, "load", init);

function init() {
	var del_link_list = dom.core.getElementsByClassName(document, "del_link");
	for( var i=0; i<del_link_list.length; i++ ) {
		var elm = del_link_list.item(i);
		dom.event.addEventListener(elm, "click", del_submit);
	}
}

function del_submit(evt) {
	dom.event.preventDefault(evt);
	var target = dom.event.target(evt);
	if(target.nodeName != "A") {
		target = target.parentNode;
	}
	if(target.nodeName != "A") {
		return;
	}
	var m = target.id.match(/^del_link_(\d+)$/);
	var dct_id = m[1];
	var dct_title = document.getElementById("dct_title_"+dct_id).firstChild.nodeValue;
	/* コールバック */
	var resAction = function() {
		document.location.href = target.href;
	};
	/* ボタン情報 */
	var buttonProperties = new Array(
		{
			"caption":"はい",
			"callback":resAction
		},
		{
			"caption":"いいえ",
			"callback":function() {}
		}
	);
	/* タイトル */
	var title = "削除の確認";
	/* メッセージ */
	var msg = "本当に「" + dct_title + "」を削除してもよろしいですか？ よろしければ「はい」を押してください。";
	/* ダイアログ表示 */
	dialog.show(title, msg, buttonProperties);
}

})();
