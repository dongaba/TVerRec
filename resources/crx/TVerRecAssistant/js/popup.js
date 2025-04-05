/*global chrome*/

// ストレージからデータを読み込む関数
function readStorage() {
	chrome.storage.local.get(null, (data) => {
		const { key_uid, key_token, key_sid } = data;
		if ((key_uid && key_token) || key_sid) {
			console.log(`TVerRec Assistant: platform_uid = ${key_uid}`);
			console.log(`TVerRec Assistant: platform_token = ${key_token}`);
			console.log(`TVerRec Assistant: member_sid = ${key_sid}`);
			const uidElement = document.getElementById("uid");
			const tokenElement = document.getElementById("token");
			const sidElement = document.getElementById("sid");
			if (uidElement) {
				uidElement.innerText = `platform_uid : ${key_uid}`;
			}
			if (tokenElement) {
				tokenElement.innerText = `platform_token : ${key_token}`;
			}
			if (sidElement) {
				sidElement.innerText = `member_sid : ${key_sid}`;
			}
		}
	});
}

// ストレージのクリア
function clearStorage() {
	chrome.storage.local.clear();
}

// ボタンクリック時に実行する処理を定義
document.getElementById("refresh").addEventListener("click", async () => {
	clearStorage();
	console.log(
		"TVerRec Assistant: platform_uid, platform_token and member_sid cleared"
	);

	//ルールを有効化
	chrome.runtime.sendMessage(
		{ action: "enablePlatformRule", data: "" },
		function () {
			window.close();
		}
	);
	chrome.runtime.sendMessage(
		{ action: "enableMemberRule", data: "" },
		function () {
			window.close();
		}
	);

	//新規タブでTVerを開く
	chrome.tabs.create({ url: "https://tver.jp/mypage/fav" });

	readStorage();
});

// ストレージからデータを読み込む
readStorage();
