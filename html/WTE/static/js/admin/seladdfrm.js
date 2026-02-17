(function () {

dom.event.addEventListener(window, "load", init);

var names = [
	'seller_code',
	'seller_name',
	'seller_company',
	'seller_email',
	'seller_pass',
	'seller_dept',
	'seller_title',
	'seller_lastname',
	'seller_firstname',
	'seller_addr1',
	'seller_addr2',
	'seller_addr3',
	'seller_addr4',
	'seller_url',
	'seller_memo',
	'seller_memo2'
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
		var max_char_num = document.getElementById(names[i] + "_max_char_num");
		var n = elm.value.length;
		var max = parseInt(max_char_num.innerHTML);
		if(n > max) {
			n = '<span class="caution">' + n + '</span>';
		}
		char_num.innerHTML = n;
	}
}

})();
