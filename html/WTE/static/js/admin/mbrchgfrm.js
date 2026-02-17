(function () {

dom.event.addEventListener(window, "load", init);

function init() {
	dom.event.addEventListener(document.getElementById("setBtn"), "click", chg_submit);
}

function chg_submit(evt) {
	var member_id = document.getElementById("member_id").value;
	var price = document.getElementById("mbract_price").value;
	var reason = document.getElementById("mbract_reason").value;
	if( ! member_id ) {
		alert("会員識別IDを指定してください。");
		return;
	}
	if( ! price ) {
		alert("チャージポイントを指定してください。");
		return;
	}
	price = parseInt(price);
	//
	if( reason.match(/[^\d]/) ) {
		alert("入出金摘要に不正な値がセットされています。");
		return;
	}
	reason = parseInt(reason);
	var type = 1;
	if(reason >= 50) {
		type = 2;
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
	/* 保持ポイント */
	var member_point = parseInt( document.getElementById('member_point').innerHTML.replace(',', '') );
	/* タイトル */
	var title = "チャージの確認";
	/* メッセージ */
	var msg = "本当に「" + company + "」";
	if(type == "1") {
		msg += "に" + price + "ポイントを加算";
		member_point += price;
	} else {
		msg += "から" + price + "ポイントを減算";
		member_point -= price;
	}
	msg += "してもよろしいですか？\n";
	msg += "処理後の保持ポイントは " + member_point + " pt になります。\n";
	msg += "よろしければ「はい」を押してください。";
	/* ダイアログ表示 */
	dialog.show(title, msg, buttonProperties);
	/* */
	return false;
}

})();
