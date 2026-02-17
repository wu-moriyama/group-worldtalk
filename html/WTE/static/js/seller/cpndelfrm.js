(function () {

dom.event.addEventListener(window, "load", init);

function init() {
	dom.event.addEventListener(document.forms.item(0), "submit", del_submit);
}

function del_submit(evt) {
	dom.event.preventDefault(evt);
	/* コールバック */
	var resAction = function() {
		var delBtn = document.getElementsByName("setBtn").item(0);
		delBtn.disabled = true;
		var frm = document.forms.item(0);
		frm.submit();
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
	var msg = "本当に削除してもよろしいですか？ よろしければ「はい」を押してください。";
	/* ダイアログ表示 */
	dialog.show(title, msg, buttonProperties);
}

})();
