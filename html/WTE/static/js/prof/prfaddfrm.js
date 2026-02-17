(function () {

dom.event.addEventListener(window, "load", init);

var names = [
	'prof_company',
	'prof_dept',
	'prof_title',
	'prof_firstname',
	'prof_lastname',
	'prof_handle',
	'prof_email',
	'prof_pass',
	'prof_skype_id',
	'prof_addr1',
	'prof_addr2',
	'prof_addr3',
	'prof_addr4',
	'prof_hp',
	'prof_video_url',
	'prof_associate1',
	'prof_associate2',
	'prof_intro',
	'prof_intro2',
	'prof_memo',
	'prof_memo2',
	'prof_audio_url',
	'prof_video_url',
	'prof_app1',
	'prof_app2',
	'prof_app3',
	'prof_app4'
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
