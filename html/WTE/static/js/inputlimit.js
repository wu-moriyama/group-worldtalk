(function () {

dom.event.addEventListener(window, "load", init);

/* グローバル変数の初期化 */
var params = new Object;

/* ------------------------------------------------------------ */
/* HTML文書が読み込まれたときに実行させる処理 */
/* ------------------------------------------------------------ */
function init() {
	/* テキストボックスのリストを取得 */
	var inputs = document.getElementsByTagName("INPUT");
	/* class属性値に'inputlimit'がセットされたテキストボックスに */
	/* イベントリスナーをセット */
	for( var i=0; i<inputs.length; i++ ) {
		var elm = inputs.item(i);
		if(elm.className.match(/(^|\s)inputlimit_([a-z]+)(\s|$)/)) {
			/* 入力開始時の処理 */
			dom.event.addEventListener(elm, "focus", textInputStart);
			/* 入力終了時の処理 */
			dom.event.addEventListener(elm, "blur", textInputEnd);
			/* IME起動を禁止（Internet Explorerのみ有効） */
			elm.style.imeMode = 'disabled';
		}
	}
	/* テキストエリアのリストを取得 */
	var tareas = document.getElementsByTagName("TEXTAREA");
	/* class属性値に'inputlimit'がセットされたテキストボックスに */
	/* イベントリスナーをセット */
	for( var i=0; i<tareas.length; i++ ) {
		var elm = tareas.item(i);
		if(elm.className.match(/(^|\s)inputlimit_([a-z]+)(\s|$)/)) {
			/* 入力開始時の処理 */
			dom.event.addEventListener(elm, "focus", textInputStart);
			/* 入力終了時の処理 */
			dom.event.addEventListener(elm, "blur", textInputEnd);
			/* IME起動を禁止（Internet Explorerのみ有効） */
			elm.style.imeMode = "disabled";
		}
	}
}

/* ------------------------------------------------------------ */
/* 入力開始処理 */
/* ------------------------------------------------------------ */
function textInputStart(evt) {
	var target = dom.event.target(evt);
	dom.event.addEventListener(target, "keydown", textInputCheck);
	dom.event.addEventListener(target, "keyup", textInputCheck);
	params["target"] = target;
	textInputCheck();
}

/* ------------------------------------------------------------ */
/* 入力終了処理
/* ------------------------------------------------------------ */
function textInputEnd(evt) {
	var target = dom.event.target(evt);
	dom.event.removeEventListener(target, "keydown", textInputCheck);
	dom.event.removeEventListener(target, "keyup", textInputCheck);
	textInputCheck();
	params["target"] = null;
}

/* ------------------------------------------------------------ */
/* 入力文字のチェック */
/* ------------------------------------------------------------ */
function textInputCheck(evt) {
	var elm = params["target"];
	if( ! elm ) { return; }
	var tarea_flag = false;
	if(elm.nodeName == "TEXTAREA") {
		tarea_flag = true;
	}
	var mt = elm.className.match(/(^|\s)inputlimit_([a-z]+)(\s|$)/);
	var selector = mt[2];
	var re;
	var re_g;
	if(selector == 'datetime') {
		re = /[^\d\:\/\s]/;
		re_g = /[^\d\:\/\s]/g;
		if(tarea_flag) {
			re = /[^\d\:\/\s\n\r]/;
			re_g = /[^\d\:\/\s\n\r]/g;
		}
	} else if(selector == 'dateiso') {
		re = /[^\d\-\s]/;
		re_g = /[^\d\-\s]/g;
		if(tarea_flag) {
			re = /[^\d\-\s\n\r]/;
			re_g = /[^\d\-\s\n\r]/g;
		}
	} else if(selector == 'date') {
		re = /[^\d\/]/;
		re_g = /[^\d\/]/g;
		if(tarea_flag) {
			re = /[^\d\/\n\r]/;
			re_g = /[^\d\/\n\r]/g;
		}
	} else if(selector == 'time') {
		re = /[^\d\:]/;
		re_g = /[^\d\:]/g;
		if(tarea_flag) {
			re = /[^\d\:\n\r]/;
			re_g = /[^\d\:\n\r]/g;
		}
	} else if(selector == 'num') {
		re = /[^\d]/;
		re_g = /[^\d]/g;
		if(tarea_flag) {
			re = /[^\d\n\r]/;
			re_g = /[^\d\n\r]/g;
		}
	} else if(selector == 'alpha') {
		re = /[^a-zA-Z\-\_]/;
		re_g = /[^a-zA-Z\-\_]/g;
		if(tarea_flag) {
			re = /[^a-zA-Z\-\_\n\r]/;
			re_g = /[^a-zA-Z\-\_\n\r]/g;
		}
	} else if(selector == 'alphanum') {
		re = /[^\da-zA-Z\-\_]/;
		re_g = /[^\da-zA-Z\-\_]/g;
		if(tarea_flag) {
			re = /[^\da-zA-Z\-\_\n\r]/;
			re_g = /[^\da-zA-Z\-\_\n\r]/g;
		}
	} else if(selector == 'url') {
		re = /[^\da-zA-Z\-\_\.\&\?\%\;\/\:]/;
		re_g = /[^\da-zA-Z\-\_\.\&\?\%\;\:\/\:]/g;
		if(tarea_flag) {
			re = /[^\da-zA-Z\-\_\.\&\?\%\;\/\:\n\r]/;
			re_g = /[^\da-zA-Z\-\_\.\&\?\%\;\:\/\:\n\r]/g;
		}
	} else if(selector == 'host') {
		re = /[^\da-zA-Z\-\_\.]/;
		re_g = /[^\da-zA-Z\-\_\.]/g;
		if(tarea_flag) {
			re = /[^\da-zA-Z\-\_\.\n\r]/;
			re_g = /[^\da-zA-Z\-\_\.\n\r]/g;
		}
	} else if(selector == 'ascii') {
		re = /[^\x20-\x7e]/;
		re_g = /[^\x20-\x7e]/g;
		if(tarea_flag) {
			re = /[^\x20-\x7e\n\r]/;
			re_g = /[^\x20-\x7e\n\r]/g;
		}
	}
	if(! re) { return false; }
	/* 半角英数以外の文字を除外 */
	if( elm && elm.value && elm.value.match(re) ) {
		/* 数字以外の文字の位置を特定 */
		var pos = elm.value.search(re);
		/* 数字以外の文字を削除 */
		elm.value = elm.value.replace(re_g, '');
		/* カーソルの位置を変更 */
		if(elm.setSelectionRange) {
			/* Firefox,Opera,Safariの場合 */
			elm.setSelectionRange(pos,pos); 
		} else if(elm.createTextRange) {
			/* Internet Explorerの場合 */
			var range = elm.createTextRange();
			range.move('character', pos);
			range.select();
		}
	}
}

})();
