//リロード
function reload() {
	//	location.reload();
	location.href = ("https://tver.jp");
}

// ボタンクリック時に実行する処理を定義
document.getElementById("refresh").addEventListener("click", async () => {
	clearStorage();
	console.log("TVerRec Assistant: platform_uid and platform_token cleared");
	chrome.runtime.sendMessage(
		{ action: "enableRule", data: "" },
		function (response) {
			window.close();
		}
	);
	let [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
	chrome.scripting.executeScript({
		target: { tabId: tab.id },
		function: reload,
	});
	readStorage();
});

// ストレージからデータを読み込む
readStorage();
