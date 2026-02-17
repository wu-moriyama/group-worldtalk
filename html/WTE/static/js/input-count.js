(function () {
  let frm_el_list = document.querySelectorAll('form');
  for (let i = 0; i < frm_el_list.length; i++) {
    let frm_el = frm_el_list.item(i);
    let ctl_el_list = frm_el.elements;
    for (let j = 0; j < ctl_el_list.length; j++) {
      let ctl_el = ctl_el_list.item(j);
      let id = ctl_el.id;
      if (!id) {
        continue;
      }
      let char_num_el = document.getElementById(id + '_char_num');
      if (!char_num_el) {
        continue;
      }
      let max_char_num_el = document.getElementById(id + '_max_char_num');
      if (!max_char_num_el) {
        continue;
      }
      countCharNum(id);
      ctl_el.addEventListener('keyup', triggerCountCharNum, false);
      ctl_el.addEventListener('focus', triggerCountCharNum, false);
      ctl_el.addEventListener('blur', triggerCountCharNum, false);
    }
  }

  function triggerCountCharNum(event) {
    let el = event.currentTarget;
    countCharNum(el.id);
  }

  function countCharNum(id) {
    let el = document.getElementById(id);
    let char_num_el = document.getElementById(id + '_char_num');
    let max_char_num_el = document.getElementById(id + '_max_char_num');
    let n = el.value.length;
    let max = parseInt(max_char_num_el.textContent, 10);
    if (n > max) {
      char_num_el.innerHTML = '<span class="caution">' + n + '</span>';
    } else {
      char_num_el.innerHTML = n;
    }
  }
})();