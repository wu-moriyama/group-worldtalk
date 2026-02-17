$(document).ready(function(){
	$("#ajax_seller_search_box").dialog({
		autoOpen: false,
		modal: true,
		overlay: {backgroundColor:'#000000', opacity: '0.3'},
		width: 500,
		height: 500,
		buttons: {
			'閉じる': function(evt) {
				$("#ajax_seller_search_box").dialog("close");
			}
		}
	});
});

function seller_searchbox_show() {
	var url = document.forms.item(0).action;
	var qstr = "";
	if(document.getElementById("s_seller_company")) {
		qstr = document.getElementById("s_seller_company").value;
	}
	$("#ajax_seller_search_box").dialog("open");
	$("#ajax_seller_search_box").html("now loading...");
	var params = {
		m: "sellstajx",
		s_seller_company: qstr,
		limit: 10
	};
	var cb = function(data) {
		$("#ajax_seller_search_box").html(data);
		$("#ajax_seller_search_box table.list tr").css("cursor", "pointer");
		$("#ajax_seller_search_box table.list tr").click(seller_list_click);
		$("#ajax_seller_search_box table.list tr").mouseout(seller_list_mouseout);
		$("#ajax_seller_search_box table.list tr").mouseover(seller_list_mouseover);
		$("#ajax_seller_search_box table.list tr").mousedown(seller_list_mousedown);
	}
	$.get(url, params, cb, "html");
}
function seller_list_mouseout(evt) {
	$(this).css("backgroundColor", "");
}
function seller_list_mouseover(evt) {
	$(this).css("backgroundColor", "#eeeeee");
}
function seller_list_mousedown(evt) {
	$(this).css("backgroundColor", "#dddddd");
}
function seller_list_click(evt) {
	var seller_id = $(this).find("td.seller_id").text();
	var seller_company = $(this).find("td.seller_company").text();
	$("#ajax_seller_search_box").dialog("close");
	$("#s_seller_id").attr("value", seller_id);
	$("#ajax_seller_company").text(seller_company);
}