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
