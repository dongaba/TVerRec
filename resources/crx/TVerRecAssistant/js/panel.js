// 保存処理
function saveStorage(platform_uid, platform_token) {
	chrome.storage.local.set({ key_uid: platform_uid });
	chrome.storage.local.set({ key_token: platform_token });
	chrome.storage.local.get(console.log);
}

//クリア
function clearTable() {
	const table = document.getElementById("dataTable");
	var row_num = table.rows.length;
	for (let i = row_num; i > 1; i--) {
		row_num = table.rows.length;
		table.deleteRow(row_num - 1);
	}
	chrome.storage.local.clear();
	console.clear();
}

//クエリパラメータの処理
function getSearchParams(search) {
	var params = {};
	var search = search.substr(1);
	if (search === "") {
		return params;
	}
	search.split("&").forEach((str) => {
		var arr = str.split("=");
		if (arr[0] !== "") {
			params[arr[0]] = arr[1] !== undefined ? decodeURIComponent(arr[1]) : "";
		}
	});
	return params;
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
		const hasExcludedExtension = excludedExtensions.some((ext) =>
			url.pathname.endsWith(ext)
		);

		if (!hasExcludedExtension) {
			console.log("URL:", requrl);
			var searchParams = getSearchParams(url.search);
			console.log("	Origin:", url.origin);
			console.log("	Path:", url.pathname);
			console.log("	Param Text:", url.search);
			console.log("	Param Array:", searchParams);
			console.log("		platform_uid:", searchParams.platform_uid);
			console.log("		platform_token:", searchParams.platform_token);
		}

		if (
			searchParams !== undefined &&
			searchParams.platform_uid !== undefined &&
			searchParams.platform_token !== undefined
		) {
			const table = document.getElementById("dataTable");
			const row1 = table.insertRow();
			const col1_1 = row1.insertCell();
			const col1_2 = row1.insertCell();
			const col1_3 = row1.insertCell();
			col1_1.innerHTML = "platform_uid";
			col1_2.innerHTML = searchParams.platform_uid;
			col1_3.innerHTML =
				"$script:my_platform_uid = '" + searchParams.platform_uid + "'";
			const row2 = table.insertRow();
			const col2_1 = row2.insertCell();
			const col2_2 = row2.insertCell();
			const col2_3 = row2.insertCell();
			col2_1.innerHTML = "platform_token";
			col2_2.innerHTML = searchParams.platform_token;
			col2_3.innerHTML =
				"$script:my_platform_token = '" + searchParams.platform_token + "'";
			saveStorage(searchParams.platform_uid, searchParams.platform_token);
		}

		// background.jsにメッセージを送信
		chrome.runtime.sendMessage({
			message: "panel.jsからbackground.jsに送るメッセージ",
		});
	}
});

// メッセージが受信された時に実行する処理
chrome.runtime.onMessage.addListener((message) => {
	console.log(message.message);
});
