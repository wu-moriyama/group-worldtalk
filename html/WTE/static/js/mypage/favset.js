(function () {

var processing = false;

$(document).ready(function(){
	var fav_set_list = $('a.wte_fav_set');
	// clickイベントリスナー
	fav_set_list.click( function(event) {
		event.preventDefault();
		if( processing === true ) { return; }
		reqFavSet($(this));
	});
});

function reqFavSet(fav_set) {
	var url = fav_set.attr('href');
	if( ! url ) { return; }
	if( ! fav_set.hasClass('wte_fav_set') ) { return; }
	$.ajax({
		url: url,
		type: 'GET',
		cache: false,
		dataType: 'text',
		success: function(data) {
			if( data.match(/^0/) ) {
				fav_set.removeClass('wte_prof_fav_on');
			} else if( data.match(/^1/) ) {
				fav_set.addClass('wte_prof_fav_on');
			} else {
				fav_set.text('処理エラー');
			}
			processing = false;
		},
		error: function(jqXHR, textStatus, errorThrown) {
			fav_set.text('処理エラー');
			processing = false;
		}
	});
}

})();
