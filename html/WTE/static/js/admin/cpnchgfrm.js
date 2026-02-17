(function () {

dom.event.addEventListener(window, "load", init);

function init() {
	dom.event.addEventListener(document.getElementById("setBtn"), "click", chg_submit);
}

function chg_submit(evt) {
	var member_id = document.getElementById("member_id").value;
	var price = document.getElementById("cpnact_price").value;
	var type = document.getElementById("cpnact_type").value;
	if( ! member_id ) {
		alert("会員識別IDを指定してください。");
		return;
	}
	if( ! price ) {
		alert("チャージポイントを指定してください。");
		return;
	}
	if( type != "1" && type != "2" ) {
		alert("invaid parameter.");
		return;
	}
	var company = document.getElementById("ajax_member_company").firstChild.nodeValue;
	/* コールバック */
	var resAction = function() {
		var setBtn = document.getElementById("setBtn");
		setBtn.disabled = true;
		setBtn.form.submit();
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
	var title = "チャージの確認";
	/* メッセージ */
	var msg = "本当に「" + company + "」";
	if(type == "1") {
		msg += "に" + price + "ポイントを加算";
	} else {
		msg += "から" + price + "ポイントを減算";
	}
	msg += "してもよろしいですか？\n";
	msg += "よろしければ「はい」を押してください。";
	/* ダイアログ表示 */
	dialog.show(title, msg, buttonProperties);
	/* */
	return false;
}

})();
