const dialog = {};

(function () {

  /* -------------------------------------------------------------------
  * ウィンドウ表示
  * ----------------------------------------------------------------- */
  dialog.show = function (title, msg, propertyObj) {
    // ウィンドウ枠を生成
    let frame = dialog._makeFrame(title, msg);
    // ボタンを生成
    let buttons = dialog._makeButtom(propertyObj);
    // ボタン領域にボタンを追加
    let btnarea = frame.getElementsByTagName('div').item(2);
    for (let i = 0; i < buttons.length; i++) {
      btnarea.appendChild(buttons[i]);
    }
    // ウィンドウ表示
    dialog._display(frame);
  };

  /* -------------------------------------------------------------------
  * ▼以降、内部処理用関数
  * ----------------------------------------------------------------- */

  /* -------------------------------------------------------------------
  * ウィンドウ削除処理
  * ----------------------------------------------------------------- */
  dialog._clear = function (evt) {
    // ダイアログウィンドウ削除
    let frame = document.getElementById('dialog_frame');
    frame.parentNode.removeChild(frame);
    // シャドー・レイヤー削除
    let shadow = document.getElementById('dialog_shadow');
    shadow.parentNode.removeChild(shadow);
  };

  /* -------------------------------------------------------------------
  * ウィンドウ表示処理
  * ----------------------------------------------------------------- */
  dialog._display = function (elm) {
    // 画面全体を覆うシャドー・レイヤーを生成表示
    dialog._makeShadowMask();
    // BODYタグ内にウィンドウを追加
    elm.style.visibility = 'hidden';
    document.body.appendChild(elm);
    // 位置をウィンドウ中央に移動
    dialog._setPositionCenter(elm);
    // ウィンドウを可視化
    elm.style.visibility = 'visible';
  };

  /* -------------------------------------------------------------------
  * ウィンドウ枠を組み立てる
  * ----------------------------------------------------------------- */
  dialog._makeFrame = function (title, msg) {
    // ウィンドウ枠を生成
    let frame = document.createElement('div');
    frame.id = 'dialog_frame';
    // タイトルバー生成
    let titlebar = document.createElement('div');
    titlebar.id = 'dialog_titlebar';
    titlebar.textContent = title;
    // メッセージ領域生成
    let msgarea = document.createElement('div');
    msgarea.id = 'dialog_msgarea';
    msgarea.innerHTML = msg;
    // ボタン領域生成
    let btnarea = document.createElement('div');
    btnarea.id = 'dialog_btnarea';
    // ウィンドウの組み立て
    frame.appendChild(titlebar);
    frame.appendChild(msgarea);
    frame.appendChild(btnarea);
    // 要素ノードオブジェクトを返す
    return frame;
  };

  /* -------------------------------------------------------------------
  * ボタンを生成
  * ----------------------------------------------------------------- */
  dialog._makeButtom = function (buttonPropertyArray) {
    let buttons = [];
    for (let i = 0; i < buttonPropertyArray.length; i++) {
      // ボタン用のタグを生成
      var btn = document.createElement('input');
      btn.type = 'button';
      btn.name = 'dialog_btn_' + i;
      btn.value = buttonPropertyArray[i].caption;
      btn.className = 'btn';
      // clickイベントリスナーをセット
      btn.addEventListener('click', dialog._clear, false);
      let callback = buttonPropertyArray[i].callback
      btn.addEventListener('click', callback, false);
      // BUTTONタグのノードオブジェクトを配列に追加
      buttons.push(btn);
    }
    return buttons;
  };

  /* -------------------------------------------------------------------
  * シャドー・レイヤーを生成・表示
  * ----------------------------------------------------------------- */
  dialog._makeShadowMask = function () {
    let shadow = document.createElement('div');
    shadow.id = 'dialog_shadow';
    document.body.appendChild(shadow);
    shadow.style.width = '100%';
    shadow.style.height = '100%';
  };

  /* -------------------------------------------------------------------
  * 要素をブラウザー表示領域中央に移動
  * ----------------------------------------------------------------- */
  dialog._setPositionCenter = function (elm) {
    // ブラウザー表示領域のサイズを取得
    let w = window.innerWidth;
    let h = window.innerHeight;
    // 中心に移動
    let left = (w - elm.offsetWidth) / 2;
    elm.style.left = parseInt(left) + 'px';
    let top = (h - elm.offsetHeight) / 2;
    elm.style.top = parseInt(top) + 'px';
  };


})();
