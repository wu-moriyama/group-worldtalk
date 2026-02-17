(function () {

dom.event.addEventListener(window, "load", init);

var names = [
	'cd_subject',
	'cd_body'
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
	var tmp_load_btn = document.getElementById("tmp_load_btn");
	dom.event.addEventListener(tmp_load_btn, "click", load_template);
	//
	dom.event.addEventListener(document.getElementById("cd_target"), "change", change_cd_target);
	change_cd_target();
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

function change_cd_target() {
	var target = document.getElementById("cd_target").value;
	var cd_specialties_box = document.getElementById("cd_specialties_box")
	if(target == "1") {
		cd_specialties_box.style.display = "";
	} else {
		cd_specialties_box.style.display = "none";
	}
}

function load_template() {
	var cd_target = document.getElementById("cd_target");
	if( ! cd_target.value.match(/^(1|2|3)$/) ) {
		alert("配信対象を選択してください。");
		return;
	}
	var cd_subject = document.getElementById("cd_subject");
	var cd_body = document.getElementById("cd_body");
	if( cd_subject.value != "" || cd_body.value != "" ) {
		var res = confirm("サブジェクトおよび本文がすでにセットされています。雛形に置き換えてもよろしいですか？");
		if(res == false) { return; }
	}
	cd_subject.value = document.getElementById("cd_subject_" + cd_target.value).value;
	cd_body.value = document.getElementById("cd_body_" + cd_target.value).value;
}

})();
