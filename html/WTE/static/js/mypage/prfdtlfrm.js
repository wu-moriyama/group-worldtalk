(function () {

var loading_html = "";
var calendar_el = null;

$(document).ready(function(){
	calendar_el = $('#calendar');
	loading_html = calendar_el.html();
	// URL
	var url = calendar_el.attr('data-url');
	// カレンダーをロード
	loadCalendar(url);
});

function loadCalendar(url) {
	if( ! url ) { return null; }
	calendar_el.html(loading_html);
	$.ajax({
		url: url,
		type: 'GET',
		cache: false,
		dataType: 'html',
		success: loadCalendarSuccess,
		error: loadCalendarError
	});
}

function loadCalendarSuccess(data) {
	calendar_el.empty();
	calendar_el.html(data);
	$('#last_month_link,#next_month_link').click( function(event) {
		event.preventDefault();
		loadCalendar(event.target.href);
	});
}

function loadCalendarError(jqXHR, textStatus, errorThrown) {
	calendar_el.empty();
	calendar_el.html(textStatus);
}

})();
