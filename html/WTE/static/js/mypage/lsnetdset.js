$(function() {
	
	// レッスン完了報告フォーム
	$('form.lsn_etd_form').submit( function(event) {
		// 確認画面表示
		var msg = "本当に延長してもよろしいですか？";
		var res = window.confirm(msg);
		if( res === true ) {
			$('.lsn_etd_btn').attr('disabled', 'disabled');
			$('.lsn_etd_btn').val('送信中...');
			return true;
		} else {
			return false;
		}
	});

});
