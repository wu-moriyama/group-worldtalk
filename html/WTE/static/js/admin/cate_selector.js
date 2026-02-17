(function () {

var selects = {};
var xhr;

dom.event.addEventListener(window, "load", function(){
	for( var i=1; i<=4; i++ ) {
		var sel = document.getElementById("cate" + i);
		if( ! sel ) { continue; }
		selects[i] = sel;
		if(i < 4) {
			dom.event.addEventListener(sel, "change", cate_change);
		}
	}
	xhr = get_xhr();
	
});

function cate_change(evt) {
	var sel = dom.event.target(evt);
	var selected_id = sel.value;
	//
	var selected_layer = 1;
	var m = sel.id.match(/^cate(\d+)$/);
	if( m ) {
		selected_layer = parseInt(m[1]);
		if(selected_layer < 1) { selected_layer = 1; }
		if(selected_layer > 3) { selected_layer = 3; }
	}
	//
	var target_layer = selected_layer + 1;
	var target_sel = selects[target_layer];
	//
	for( var i=target_layer; i<=4; i++ ) {
		selects[i].innerHTML = '<option value=""></option>';
	}
	//
	var url = "?m=ctglstajx&cate_id=" + selected_id;
	xhr.open('GET', url, true);
	xhr.onreadystatechange = function() {
		if( xhr.readyState != 4 || xhr.status != 200) { return; }
		target_sel.innerHTML = "";
		var data = xhr.responseText;
		var lines = data.split(/\n+/);
		var op = document.createElement("option");
		op.value = "";
		op.appendChild( document.createTextNode("選択してください") );
		target_sel.appendChild(op);
		for( var i=0; i<lines.length; i++ ) {
			var line = lines[i];
			if(lines == "") { continue; }
			var parts = line.split(/\t/);
			var id = parts[0];
			var title = parts[1];
			if( ! id || id.match(/[^\d]/) || ! title ) { continue; }
			var op = document.createElement("option");
			op.value = id;
			op.appendChild( document.createTextNode(title) );
			target_sel.appendChild(op);
		}
		//target_sel.focus();
	};
	xhr.send(null);
	target_sel.innerHTML = '<option value="">now loading...</option>';
}

/* -------------------------------------------------------------------
* XMLHttpRequest
* ----------------------------------------------------------------- */
function get_xhr() {
	var o = null;
	if(window.XMLHttpRequest) {
		o = new XMLHttpRequest();
	} else if(window.ActiveXObject) {
		try {
			o = new window.ActiveXObject("Msxml2.XMLHTTP.3.0");
		} catch(e) {
			return null;
		}
	}
	return o;
}

})();
