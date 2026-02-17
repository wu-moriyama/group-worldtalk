(function () {

/*-----------------------------------------------------------------*/
/* HTML文書が読み込まれたときに実行させる処理 */
/*-----------------------------------------------------------------*/
/* loadイベントリスナーをセット */
addEventListener(window, 'load', initDocument);
function initDocument() {
	/* ボタン1 */
	var btn1 = document.getElementById('btn1');
	addEventListener(btn1, 'click', showDialog1);
	/* ボタン2 */
	var btn2 = document.getElementById('btn2');
	addEventListener(btn2, 'click', showDialog2);
	/* ボタン3 */
	var btn3 = document.getElementById('btn3');
	addEventListener(btn3, 'click', showDialog3);
}

/*-----------------------------------------------------------------*/
/* 1つボタンのダイアログを表示 */
/*-----------------------------------------------------------------*/
function showDialog1(evt) {
	/* ボタン情報 */
	var buttonProperties = new Array(
		{
			"caption":"はい",
			"callback":resAction
		}
	);
	/* タイトル */
	var title = "1つボタンダイアログ";
	/* メッセージ */
	var msg = "ボタンがひとつだけのダイアログです。";
	msg += "「はい」を押すと、ダイアログが消えます。";
	/* ダイアログ表示 */
	dialog.show(title, msg, buttonProperties);
}

/*-----------------------------------------------------------------*/
/* 2つボタンのダイアログを表示 */
/*-----------------------------------------------------------------*/
function showDialog2(evt) {
	/* ボタン情報 */
	var buttonProperties = new Array(
		{
			"caption":"はい",
			"callback":resAction
		},
		{
			"caption":"いいえ",
			"callback":resAction
		}
	);
	/* タイトル */
	var title = "2つボタンダイアログ";
	/* メッセージ */
	var msg = "ボタンが2つあるダイアログです。";
	msg += "「はい」「いいえ」のいずれかを押してください。";
	/* ダイアログ表示 */
	dialog.show(title, msg, buttonProperties);
}

/*-----------------------------------------------------------------*/
/* 3つボタンのダイアログを表示 */
/*-----------------------------------------------------------------*/
function showDialog3(evt) {
	/* ボタン情報 */
	var buttonProperties = new Array(
		{
			"caption":"選択A",
			"callback":resAction
		},
		{
			"caption":"選択B",
			"callback":resAction
		},
		{
			"caption":"選択C",
			"callback":resAction
		}
	);
	/* タイトル */
	var title = "3つボタンダイアログ";
	/* メッセージ */
	var msg = "ボタンが3つあるダイアログです。";
	msg += "いずれかのボタンを押してください。";
	/* ダイアログ表示 */
	dialog.show(title, msg, buttonProperties);
}

/* ダイアログウィンドウのボタンが押されたときに */
/* 実行するコールバック関数 */
function resAction(evt) {
	/* 押されたボタンのINPUTタグのノードオブジェクト */
	var btn = eventTarget(evt);
	/* 押されたボタンのname属性値とvalue属性値を表示 */
	var txt = "「" + btn.value + "」(" + btn.name + ")が押されました。";
	document.getElementById('res').firstChild.nodeValue = txt;
}

/*-------------------------------------------------------------------
* DOM関連
*------------------------------------------------------------------*/

function addEventListener(elm, type, func, useCapture) {
  if(! elm) { return false; }
  if(! useCapture) {
    useCapture = false;
  }
  if(elm.addEventListener) {
    elm.addEventListener(type, func, false);
  } else if(elm.attachEvent) {
    elm.attachEvent('on'+type, func);
  } else {
    return false;
  }
  return true;
}

function eventTarget(evt) {
  /* W3C DOM準拠ブラウザー */
  if(evt && evt.target) {
    /* Safari 1.3対策 */
    if(evt.target.nodeType == 3) {
      return evt.target.parentNode;
    } else {
      return evt.target;
    }
  /* Internet Explorer */
  } else if(window.event && window.event.srcElement) {
    return window.event.srcElement;
  /* それ以外 */
  } else {
    return null;
  }
}

})();
