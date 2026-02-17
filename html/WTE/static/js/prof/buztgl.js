(function () {

var processing = false;

$(document).ready(function(){
	var buztgl_list = $('a.buztgl');
	// clickイベントリスナー
	buztgl_list.click( function(event) {
		event.preventDefault();
		if( processing === true ) { return; }
		reqBuzTglSet($(this));
	});
});

function reqBuzTglSet(buztgl) {
	var url = buztgl.attr('href');
	if( ! url ) { return; }
	if( ! buztgl.hasClass('buztgl') ) { return; }
	var buz_id = buztgl.attr('data-id');
	if( ! buz_id ) { return; }
	var span = $('#buz_' + buz_id);
	//
	buztgl.text('処理中...');
	$.ajax({
		url: url,
		type: 'GET',
		cache: false,
		dataType: 'text',
		success: function(data) {
			if( data.match(/^0/) ) {
				buztgl.text( buztgl.attr('data-caption-0') );
				span.text( span.attr('data-caption-0') );
				span.attr( 'class', span.attr('data-class-0') );
			} else if( data.match(/^1/) ) {
				buztgl.text( buztgl.attr('data-caption-1') );
				span.text( span.attr('data-caption-1') );
				span.attr( 'class', span.attr('data-class-1') );
			} else {
				buztgl.text('処理エラー');
			}
			processing = false;
		},
		error: function(jqXHR, textStatus, errorThrown) {
			buztgl.text('処理エラー');
			processing = false;
		}
	});
}

})();
