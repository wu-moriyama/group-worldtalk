(function () {

$(document).ready(function(){
	// レッスン完了報告フォーム
	$('#repo_form').submit( function(event) {
		// 完了状況
		var repo = $('input[name=lsn_prof_repo]:checked').val();
		if( ! repo ) {
			alert('レッスンの完了状況を選択してください。');
			return false;
		}
		var repo_caption = $('input[name=lsn_prof_repo]:checked').parent().text();
		if( ! repo_caption ) {
			repo_caption = repo;
		}
		// 説明
		var note = $('#lsn_prof_repo_note').val();
		if( ! note && parseInt(repo) > 1 ) {
			alert('説明を入力してください。');
			return false;
		} else if( note.length > 140 ) {
			alert('説明は140文字内で入力してください。');
			return false;
		}
		// 確認画面表示
		var msg = "以下の通り報告を送信しても良いですか？\n";
		msg += "─────────────────────\n";
		msg += "状況：" + repo_caption + "\n";
		msg += "─────────────────────\n";
		msg += "説明：" + note + "\n";
		msg += "─────────────────────\n";
		var res = window.confirm(msg);
		if( res === true ) {
			$('#repo_btn').attr('disabled', 'disabled');
			$('#repo_btn').val('送信中...');
			return true;
		} else {
			return false;
		}
	});
	// メッセージ・フォーム
	$('#msg_form').submit( function(event) {
		var v = $('#msg_content').val();
		if( ! v ) {
			alert('メッセージを入力してください。');
			return false;
		} else if( v.length > 1000 ) {
			alert('メッセージは1000文字内で入力してください。');
			return false;
		}
		var res = window.confirm("以下のメッセージを送信しても良いですか？\n─────────────────────\n" + v);
		if( res === true ) {
			$('#msg_btn').attr('disabled', 'disabled');
			$('#msg_btn').val('送信中...');
			return true;
		} else {
			return false;
		}
	});
	// キャンセル・フォーム
	$('#cancel_form').submit( function(event) {
		var v = $('#lsn_cancel_reason').val();
		if( ! v ) {
			alert('キャンセル理由を入力してください。');
			return false;
		} else if( v.length > 140 ) {
			alert('キャンセル理由は140文字内で入力してください。');
			return false;
		}
		var res = window.confirm("以下のキャンセルを申請しても良いですか？\n─────────────────────\n" + v);
		if( res === true ) {
			$('#cancel_btn').attr('disabled', 'disabled');
			$('#cancel_btn').val('送信中...');
			return true;
		} else {
			return false;
		}
	});
	// 進捗・フォーム
	$('#pre_form').submit( function(event) {
		var v = $('#prep_content').val();
		if( ! v ) {
			alert('レッスン進捗を入力してください。');
			return false;
		} else if( v.length > 1000 ) {
			alert('キャンセル理由は1000文字内で入力してください。');
			return false;
		}
		var res = window.confirm("以下のレッスン進捗を投稿しても良いですか？\n─────────────────────\n" + v);
		if( res === true ) {
			$('#prep_btn').attr('disabled', 'disabled');
			$('#prep_btn').val('送信中...');
			return true;
		} else {
			return false;
		}
	});
});

})();
