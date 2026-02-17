$(function() {

	// レッスン完了報告フォーム
	$('#repo_form').submit( function(event) {
		// 完了状況
		var repo = $('input[name=lsn_member_repo]:checked').val();
		if( ! repo ) {
			alert('Please report the state of the lesson.');
			return false;
		}
		var repo_caption = $('input[name=lsn_member_repo]:checked').parent().text();
		if( ! repo_caption ) {
			repo_caption = repo;
		}
		// 説明
		var note = $('#lsn_member_repo_note').val();
		if( ! note && parseInt(repo) > 1 ) {
			alert('Please explain the situcation briefly if your lessons was not complied with or in troubles.');
			return false;
		} else if( note.length > 140 ) {
			alert('Please input the explanation within 140 words.');
			return false;
		}
		// レッスンの評価
		var rating = $('input[name=lsn_member_repo_rating]:checked').val();
		if( ! rating ) {
			alert('Please input a lesson evaluation.');
			return false;
		}
		// 感想
		var review = $('#lsn_review').val();
		if( ! review ) {
//			alert('感想を入力してください。');
//			return false;
		} else if( review.length > 140 ) {
			alert('Please input a feedback within 300 words.');
			return false;
		}
		// 確認画面表示
		var msg = "Submit the report below?\n";
		msg += "─────────────────────\n";
		msg += "The state of the lesson: " + repo_caption + "\n";
		msg += "─────────────────────\n";
		msg += "The explanation: " + note + "\n";
		msg += "─────────────────────\n";
		msg += "Lesson evaluation: " + rating + "\n";
		msg += "─────────────────────\n";
		msg += "Lesson feedback: " + review + "\n";
		var res = window.confirm(msg);
		if( res === true ) {
			$('#repo_btn').attr('disabled', 'disabled');
			$('#repo_btn').val('in progress.');
			return true;
		} else {
			return false;
		}
	});
	// メッセージ・フォーム
	$('#msg_form').submit( function(event) {
		var v = $('#msg_content').val();
		if( ! v ) {
			alert('Please input a messsage.');
			return false;
		} else if( v.length > 1000 ) {
			alert('Please input a message within 1000 words.');
			return false;
		}
		var res = window.confirm("Are you sure you want to send the following message?\n─────────────────────\n" + v);
		if( res === true ) {
			$('#msg_btn').attr('disabled', 'disabled');
			$('#msg_btn').val('in progress.');
			return true;
		} else {
			return false;
		}
	});
	// キャンセル・フォーム
	$('#cancel_form').submit( function(event) {
		var v = $('#lsn_cancel_reason').val();
		if( ! v ) {
			alert('Please input the reason of the cancellation.');
			return false;
		} else if( v.length > 140 ) {
			alert('Please input the reason of the cancellation within 140 words.');
			return false;
		}
		var res = window.confirm("Cancel the lesson?\n─────────────────────\n" + v);
		if( res === true ) {
			$('#cancel_btn').attr('disabled', 'disabled');
			$('#cancel_btn').val('in progress.');
			return true;
		} else {
			return false;
		}
	});
	// クチコミ・フォーム
	$('#buz_form').submit( function(event) {
		var v = $('#buz_content').val();
		if( ! v ) {
			alert('Please input a teacher review.');
			return false;
		} else if( v.length > 300 ) {
			alert('Please input the review within 300 words.');
			return false;
		}
		var res = window.confirm("Are you sure you want to send a teacher review?\n─────────────────────\n" + v);
		if( res === true ) {
			$('#buz_btn').attr('disabled', 'disabled');
			$('#buz_btn').val('in progress.');
			return true;
		} else {
			return false;
		}
	});

});
