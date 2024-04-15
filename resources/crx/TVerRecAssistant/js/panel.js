// 保存処理
function saveStorage(platform_uid, platform_token) {
	chrome.storage.local.set({ key_uid: platform_uid, key_token: platform_token }, () => {
		chrome.storage.local.get(null, (items) => {
			console.log(items);
		});
	});
}

// テーブルのクリア処理
function clearTable() {
    const table = document.getElementById("dataTable");
    while (table.rows.length > 1) { table.deleteRow(1); }
    chrome.storage.local.clear();
    console.clear();
}

//クエリパラメータの処理
function getSearchParams(search) {
	const params = new URLSearchParams(search);
	let result = {};
	for (const [key, value] of params) {
		result[key] = decodeURIComponent(value);
	}
	return result;
}

//リクエスト終了時
chrome.devtools.network.onRequestFinished.addListener((req) => {
	const requrl = req.request.url;
	var url = new URL(requrl);

	if (url.host.includes("tver.jp") && !url.host.includes("statics.tver.jp")) {
		const excludedExtensions = [
			".js",
			".css",
			".png",
			".svg",
			".ico",
			".json",
			".html",
		];
		if (!excludedExtensions.some((ext) => url.pathname.endsWith(ext))) {
			console.log("URL:", req.request.url);
			const searchParams = getSearchParams(url.search);
			console.log("	Origin:", url.origin);
			console.log("	Path:", url.pathname);
			console.log("	Param Text:", url.search);
			console.log("	Param Array:", searchParams);

			if (searchParams.platform_uid && searchParams.platform_token) {
				updateTable(searchParams);
				saveStorage(searchParams.platform_uid, searchParams.platform_token);
			}

			chrome.runtime.sendMessage({
				message: "panel.jsからbackground.jsに送るメッセージ",
			});
		}
	}
});

// テーブル更新処理
function updateTable(searchParams) {
    const table = document.getElementById("dataTable");
    insertRow(table, "platform_uid", searchParams.platform_uid);
    insertRow(table, "platform_token", searchParams.platform_token);
}

// テーブルに行を挿入するヘルパー関数
function insertRow(table, key, value) {
    const row = table.insertRow();
    row.insertCell().textContent = key;
    row.insertCell().textContent = value;
    row.insertCell().textContent = `$script:my_${key} = '${value}'`;
}

// メッセージが受信された時に実行する処理
chrome.runtime.onMessage.addListener((message) => {
	console.log(message.message);
});
