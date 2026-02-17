(function () {

dom.event.addEventListener(window, "load", init);

function init() {
	dom.event.addEventListener(document.forms.item(0), "submit", del_submit);
	dom.event.addEventListener(document.getElementById("confirm"), "click", confirm_click);
	document.getElementsByName("setBtn").item(0).disabled = true;
}

function confirm_click() {
	if(document.getElementById("confirm").checked == true) {
		document.getElementsByName("setBtn").item(0).disabled = false;
	} else {
		document.getElementsByName("setBtn").item(0).disabled = true;
	}
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
	var title = "退会の最終確認";
	/* メッセージ */
	var msg = "本当に退会手続きをしてもよろしいですか？ よろしければ「はい」を押してください。";
	/* ダイアログ表示 */
	dialog.show(title, msg, buttonProperties);
}

})();
