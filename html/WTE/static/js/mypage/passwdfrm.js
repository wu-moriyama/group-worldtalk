(function () {

dom.event.addEventListener(window, "load", init);

var names = [
	'member_pass',
	'member_pass_new1',
	'member_pass_new2'
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
