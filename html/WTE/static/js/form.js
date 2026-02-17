(function () {

dom.event.addEventListener(window, "load", init);
var label_map = new Object();

function init() {
	var frms = document.forms;
	for( var i=0; i<frms.length; i++ ) {
		dom.event.addEventListener(frms.item(i), "submit", submitForm);
	}
	if(frms.length > 0) {
		for( var j=0; j<frms.length; j++ ) {
			var ctrls = frms.item(j).elements;
			for( var k=0; k<ctrls.length; k++ ) {
				var ctrl = ctrls.item(k);
				if( ( ctrl.nodeName == "INPUT" && ctrl.type.match(/^(text|password)$/) ) || ctrl.nodeName == "TEXTAREA" || ctrl.nodeName == "SELECT" ) {
					dom.event.addEventListener(ctrl, "focus", ctrlFocus);
					dom.event.addEventListener(ctrl, "blur", ctrlBlur);
				}
			}
		}
		/*
		var ctrls = frms.item(0).elements;
		for( var i=0; i<ctrls.length; i++ ) {
			var elm = ctrls.item(i);
			if( elm.disabled == true ) { continue; }
			if( elm.nodeName == "TEXTAREA" || elm.nodeName == "SELECT" || (elm.nodeName == "INPUT" && elm.type == "text") ) {
				elm.focus();
				// カーソルの位置を変更
				if( elm.nodeName == "TEXTAREA" || (elm.nodeName == "INPUT" && elm.type == "text") ) {
					if(elm.setSelectionRange) {
						// Firefox,Opera,Safariの場合
						elm.setSelectionRange(elm.value.length,elm.value.length); 
					} else if(elm.createTextRange) {
						// Internet Explorerの場合
						var range = elm.createTextRange();
						range.move('character', elm.value.length);
						range.select();
					}
				}
				break;
			} else if( elm.nodeName == "INPUT" && (elm.type == "checkbox" || elm.type == "radio") ) {
				elm.focus();
				break;
			}
		}
		*/
	}
	buttonDisabled(false);
}

function ctrlFocus(e) {
	dom.event.preventDefault(e)
	var ctrl = dom.event.target(e);
	if( ! ctrl.className.match(/(^|\s)err(\s|$)/) ) {
		ctrl.style.backgroundColor = "#f9fbfd";
		ctrl.style.border = "1px solid #7db8e1";
	}
}

function ctrlBlur(e) {
	dom.event.preventDefault(e)
	var ctrl = dom.event.target(e);
	if( ! ctrl.className.match(/(^|\s)err(\s|$)/) ) {
		ctrl.style.backgroundColor = "#fbfbfb";
		ctrl.style.border = "1px solid #dadada";
		ctrl.style.borderTop = "1px solid #c0c0c0";
	}
}

function submitForm(e) {
	dom.event.preventDefault(e)
	buttonDisabled(true);
	var f = dom.event.target(e);
	if(f.nodeName != 'FORM') {
		f = f.form;
	}
	f.submit();
}

function buttonDisabled(disabled) {
	var inputs = document.getElementsByTagName("INPUT");
	for( var i=0; i<inputs.length; i++ ) {
		var elm = inputs.item(i);
		if(elm.type == "submit" || elm.type == "reset" || elm.type == "image") {
			elm.disabled = disabled;
		}
	}
	var btns = document.getElementsByTagName("BUTTON");
	for( var i=0; i<btns.length; i++ ) {
		var elm = btns.item(i);
		elm.disabled = disabled;
	}
}

})();
