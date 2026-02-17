$(function() {

	// レッスン完了報告フォーム
	$('#repo_form').submit( function(event) {
		// 完了状況
		var repo = $('input[name=lsn_member_repo]:checked').val();
		if( ! repo ) {
			alert('レッスンの完了状況を選択してください。');
			return false;
		}
		var repo_caption = $('input[name=lsn_member_repo]:checked').parent().text();
		if( ! repo_caption ) {
			repo_caption = repo;
		}
		// 説明
		var note = $('#lsn_member_repo_note').val();
		if( ! note && parseInt(repo) > 1 ) {
			alert('説明を入力してください。');
			return false;
		} else if( note.length > 140 ) {
			alert('説明は140文字内で入力してください。');
			return false;
		}
		// レッスンの評価
		var rating = $('input[name=lsn_member_repo_rating]:checked').val();
		if( ! rating ) {
			alert('レッスンの評価を選択してください。');
			return false;
		}
		// 感想
		var review = $('#lsn_review').val();
		if( ! review ) {
//			alert('感想を入力してください。');
//			return false;
		} else if( review.length > 140 ) {
			alert('感想は140文字内で入力してください。');
			return false;
		}
		// 確認画面表示
		var msg = "以下の通り報告を送信しても良いですか？\n";
		msg += "─────────────────────\n";
		msg += "状況：" + repo_caption + "\n";
		msg += "─────────────────────\n";
		msg += "説明：" + note + "\n";
		msg += "─────────────────────\n";
		msg += "評価：" + rating + "\n";
		msg += "─────────────────────\n";
		msg += "感想：" + review + "\n";
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
	// クチコミ・フォーム
	$('#buz_form').submit( function(event) {
		var v = $('#buz_content').val();
		if( ! v ) {
			alert('クチコミを入力してください。');
			return false;
		} else if( v.length > 300 ) {
			alert('クチコミは300文字内で入力してください。');
			return false;
		}
		var res = window.confirm("以下のクチコミを送信しても良いですか？\n─────────────────────\n" + v);
		if( res === true ) {
			$('#buz_btn').attr('disabled', 'disabled');
			$('#buz_btn').val('送信中...');
			return true;
		} else {
			return false;
		}
	});

});
