(function () {
  document.addEventListener('DOMContentLoaded', function () {
    initModal();
    let frm_el_list = document.querySelectorAll('form');
    for (let i = 0; i < frm_el_list.length; i++) {
      let frm_el = frm_el_list.item(i);
      frm_el.addEventListener('submit', submitForm, false);
    }
  }, false);

  function submitForm(event) {
    let modal_el = document.getElementById('form-guard-modal');
    modal_el.hidden = false;
  }

  function initModal() {
    // Insert the keyframes of CSS animation
    let sheets = document.styleSheets;
    if(sheets.length == 0) {
        let style_el = document.createElement('style');
        style_el.appendChild(document.createTextNode(''));
        document.head.appendChild(style_el);
    }
    let sheet = sheets.item(sheets.length - 1);
    let rule_text = '@keyframes ani-round { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }';
    sheet.insertRule(rule_text, sheet.rules ? sheet.rules.length : sheet.cssRules.length);

    // Create a `div` element
    let div_el = document.createElement('div');
    div_el.id = 'form-guard-modal';
    div_el.hidden = true;
    let ds = div_el.style;
    ds.position = 'fixed';
    ds.top = '0px';
    ds.left = '0px';
    ds.width = '100%';
    ds.height = '100%';
    ds.backgroundColor = 'rgba(0, 0, 0, 0.4)';
    ds.color = 'white';

    // Create an `img` element
    let img_el = document.createElement('img');
    img_el.src = getLoadingImageData();
    img_el.width = 48;
    img_el.height = 48;
    let is = img_el.style;
    is.position = 'absolute';
    is.top = '50%';
    is.left = '50%';
    is.transform = 'translate(-50%, -50%)';
    is.animation = 'ani-round 3s linear infinite';

    // Insert the `div` element at the bottom of the `body` element
    div_el.appendChild(img_el);
    document.body.appendChild(div_el);
  }

  function getLoadingImageData() {
    return 'data:image/svg+xml, <svg aria-hidden="true" focusable="false" data-prefix="fas" data-icon="spinner" class="svg-inline--fa fa-spinner fa-w-16" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path fill="white" d="M304 48c0 26.51-21.49 48-48 48s-48-21.49-48-48 21.49-48 48-48 48 21.49 48 48zm-48 368c-26.51 0-48 21.49-48 48s21.49 48 48 48 48-21.49 48-48-21.49-48-48-48zm208-208c-26.51 0-48 21.49-48 48s21.49 48 48 48 48-21.49 48-48-21.49-48-48-48zM96 256c0-26.51-21.49-48-48-48S0 229.49 0 256s21.49 48 48 48 48-21.49 48-48zm12.922 99.078c-26.51 0-48 21.49-48 48s21.49 48 48 48 48-21.49 48-48c0-26.509-21.491-48-48-48zm294.156 0c-26.51 0-48 21.49-48 48s21.49 48 48 48 48-21.49 48-48c0-26.509-21.49-48-48-48zM108.922 60.922c-26.51 0-48 21.49-48 48s21.49 48 48 48 48-21.49 48-48-21.491-48-48-48z"></path></svg>';
  }

})();