(function () {

dom.event.addEventListener(window, "load", init);

function init() {
	dom.event.addEventListener(document.forms.item(0), "submit", del_submit);
	dom.event.addEventListener(document.getElementById("lsnbck"), "submit", lsnbck_submit);
}

function del_submit(evt) {
	dom.event.preventDefault(evt);
	/* コールバック */
	var resAction = function() {
		var setBtn = document.getElementsByName("setBtn").item(0);
		setBtn.disabled = true;
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
	var title = "編集の確認";
	/* メッセージ */
	var msg = "本当に送信してもよろしいですか？ よろしければ「はい」を押してください。";
	/* ダイアログ表示 */
	dialog.show(title, msg, buttonProperties);
}

function lsnbck_submit(evt) {
	dom.event.preventDefault(evt);
	/* コールバック */
	var resAction = function() {
		var setBtn = document.getElementById("pay_back");
		setBtn.disabled = true;
		var frm = document.getElementById("lsnbck");
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
	var title = "送信の確認";
	/* メッセージ */
	var msg = "本当に売上確定レッスンの払い戻し処理をしてもよろしいですか？ よろしければ「はい」を押してください。";
	/* ダイアログ表示 */
	dialog.show(title, msg, buttonProperties);
}

})();
