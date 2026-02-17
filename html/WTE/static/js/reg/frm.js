(function () {

dom.event.addEventListener(window, "load", init);

var names = [
	'member_company',
	'member_dept',
	'member_title',
	'member_firstname',
	'member_lastname',
	'member_handle',
	'member_email',
	'member_pass',
	'member_pass2',
	'member_hpm',
	'member_emailm',
	'member_hp',
	'member_rmda'
];

function init() {
	for( var i=0; i<names.length; i++ ) {
		var elm = document.getElementById(names[i]);
		dom.event.addEventListener(elm, "keyup", count_char_num);
		dom.event.addEventListener(elm, "focus", count_char_num);
		dom.event.addEventListener(elm, "blur", count_char_num);
	}
	count_char_num();
	//
	for( var i=0; i<=1; i++ ) {
		var rdo = document.getElementById("member_com_"+i);
		dom.event.addEventListener(rdo, "click", com_change);
	}
	com_change();
}

function com_change() {
	var box = document.getElementById("com_box");
	if( document.getElementById("member_com_1").checked == true ) {
		box.style.display = "";
	} else {
		box.style.display = "none";
	}
}

function count_char_num() {
	for( var i=0; i<names.length; i++ ) {
		var elm = document.getElementById(names[i]);
		if( ! elm ) { continue; }
		var char_num = document.getElementById(names[i] + "_char_num");
		if( ! char_num ) { continue; }
		var max_char_num = document.getElementById(names[i] + "_max_char_num");
		if( ! max_char_num ) { continue; }
		var min_char_num = document.getElementById(names[i] + "_min_char_num");
		var n = elm.value.length;
		var max = parseInt(max_char_num.innerHTML);
		var min = 0;
		if(min_char_num) {
			min = parseInt(min_char_num.innerHTML);
		}
		if(n > max || n < min) {
			n = '<span class="caution">' + n + '</span>';
		}
		char_num.innerHTML = n;
	}
}

})();
