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
	'member_skype_id',
	'member_addr1',
	'member_addr2',
	'member_addr3',
	'member_addr4',
	'member_hp',
	'member_associate1',
	'member_associate2',
	'member_intro',
	'member_comment',
	'member_memo',
	'member_memo2'
];

function init() {
	for( var i=0; i<names.length; i++ ) {
		var elm = document.getElementById(names[i]);
		dom.event.addEventListener(elm, "keyup", count_char_num);
		dom.event.addEventListener(elm, "focus", count_char_num);
		dom.event.addEventListener(elm, "blur", count_char_num);
	}
	count_char_num();
}

function count_char_num() {
	for( var i=0; i<names.length; i++ ) {
		var elm = document.getElementById(names[i]);
		var char_num = document.getElementById(names[i] + "_char_num");
		if( ! char_num ) { continue; }
		var max_char_num = document.getElementById(names[i] + "_max_char_num");
		if( ! max_char_num ) { continue; }
		var n = elm.value.length;
		var max = parseInt(max_char_num.innerHTML);
		if(n > max) {
			n = '<span class="caution">' + n + '</span>';
		}
		char_num.innerHTML = n;
	}
}

})();
