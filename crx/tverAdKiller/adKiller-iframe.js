
window.addEventListener('load', function () {

	//Test Code
	//window.alert('アンケート無効化！');

	document.getElementById('birth').value = "198007";
	document.getElementsByName('gender')[0].click();
	document.getElementById('zip').value = "1540012";
	document.getElementsByClassName('submit')[0].click();

	//閉じる
	document.getElementsByClassName('cancel')[0].click();

})
