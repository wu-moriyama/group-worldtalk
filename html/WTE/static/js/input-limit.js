// テキストボックスおよびテキストエリアからフォーカスが外れたときに、
// 入力された文字のうち全角の英数字および記号を半角に変換する。
//
// 対象の input および textarea は、class 属性に inputlimit から
// 始まるクラストークンを含んだもの。
// <input class="inputlimit">

(function () {


  // class属性値に'inputlimit'がセットされたテキストボックスにイベントリスナーをセット
  let input_list = document.querySelectorAll('input');
  for (let i = 0; i < input_list.length; i++) {
    let el = input_list.item(i);
    if (el.className.match(/(^|\s)inputlimit/)) {
      el.addEventListener('blur', textInputCheck, false);
    }
  }
  // class属性値に'inputlimit'がセットされたテキストエリアにイベントリスナーをセット
  let tarea_list = document.querySelectorAll('textarea');
  for (let i = 0; i < tarea_list.length; i++) {
    let el = tarea_list.item(i);
    if (el.className.match(/(^|\s)inputlimit/)) {
      el.addEventListener('blur', textInputCheck, false);
    }
  }

  /* ------------------------------------------------------------ */
  /* 入力文字の半角変換 */
  /* ------------------------------------------------------------ */
  function textInputCheck(event) {
    let el = event.currentTarget;
    if (!el) {
      return;
    }
    let v = el.value;
    if (!v) {
      return;
    }
    v = v.replace(/[！-～]/g, function (s) {
      return String.fromCharCode(s.charCodeAt(0) - 0xFEE0);
    });
    v = v.replace(/”/g, "\"")
      .replace(/’/g, "'")
      .replace(/‘/g, "`")
      .replace(/￥/g, "\\")
      .replace(/　/g, " ")
      .replace(/〜/g, "~");
    el.value = v;
  }

})();
