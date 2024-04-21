// ストレージからデータを読み込む関数
function readStorage() {
	chrome.storage.local.get(null, (data) => {
		const { key_uid, key_token } = data;
		if (key_uid && key_token) {
			console.log(`TVerRec Assistant: platform_uid = ${key_uid}`);
			console.log(`TVerRec Assistant: platform_token = ${key_token}`);
			const uidElement = document.getElementById("uid");
			const tokenElement = document.getElementById("token");
			if (uidElement) {
				uidElement.innerText = `platform_uid : ${key_uid}`;
			}
			if (tokenElement) {
				tokenElement.innerText = `platform_token : ${key_token}`;
			}
		}
	});
}

// ボタンクリック時に実行する処理を定義
document.getElementById("refresh").addEventListener("click", async () => {
	clearStorage();
	console.log("TVerRec Assistant: platform_uid and platform_token cleared");

	//ルールを有効化
	chrome.runtime.sendMessage(
		{ action: "enableRule", data: "" },
		function (response) {
			window.close();
		}
	);

	//新規タブでTVerを開く
	chrome.tabs.create({ url: "https://tver.jp" });

	readStorage();
});

// ストレージからデータを読み込む
readStorage();
