// ルールの有効化
function enableRule() {
	chrome.declarativeNetRequest.updateEnabledRulesets(
		{ enableRulesetIds: ["ruleset"] },
		() => {}
	);
	console.log("TVerRec Assistant: Rule Enabled");
}
// ルールの無効化
function disableRule() {
	chrome.declarativeNetRequest.updateEnabledRulesets(
		{ disableRulesetIds: ["ruleset"] },
		() => {}
	);
	console.log("TVerRec Assistant: Rule Disabled");
}

// 保存処理
function saveStorage(platform_uid, platform_token) {
	chrome.storage.local.set({
		key_uid: platform_uid,
		key_token: platform_token,
	});
	chrome.storage.local.get(console.log);
}

//クエリパラメータの処理
function getSearchParams(search) {
	const params = new URLSearchParams(search);
	let result = {};
	for (const [key, value] of params) {
		result[key] = value;
	}
	return result;
}

//ローカルストレージの変更時にコンソールメッセージ
chrome.storage.onChanged.addListener((changes, namespace) => {
	for (let [key, { oldValue, newValue }] of Object.entries(changes)) {
		console.log(
			`TVerRec Assistant: Storage key "${key}" in namespace "${namespace}" changed.`,
			`TVerRec Assistant: Old value was "${oldValue}", new value is "${newValue}".`
		);
	}
});

//アクティブなタブを切り替えたとき
chrome.tabs.onActivated.addListener(function (activeInfo) {
	chrome.tabs.get(activeInfo.tabId, function (tab) {
		setAction(tab.url);
	});
});

//タブの情報に変更があったとき
chrome.tabs.onUpdated.addListener((tabId, change, tab) => {
	if (tab.active && change.url) {
		setAction(change.url);
	}
});

//アクティブタブによってポップアップを変える
function setAction(url) {
	console.log(`TVerRec Assistant: active page = "${url}"`);
	const pattern = /^https:\/\/tver.jp\//;
	if (pattern.test(url)) {
		chrome.action.setPopup({ popup: "html/popup.html" });
	} else {
		chrome.action.setPopup({ popup: "html/error.html" });
	}
}

//ネットワークリクエストに関するイベントを監視
chrome.declarativeNetRequest.onRuleMatchedDebug.addListener((e) => {
	console.log("TVerRec Assistant: Connection Blocked by TVerRec");

	const url = new URL(e.request.url);

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
			console.log("TVerRec Assistant: URL:", e.request.url);
			const searchParams = getSearchParams(url.search);
			console.log("TVerRec Assistant: Param Array:", searchParams);
			if (
				searchParams.platform_uid !== undefined &&
				searchParams.platform_token !== undefined
			) {
				console.log("TVerRec Assistant: Add below to user_settings.ps1");
				console.log(`	$script:my_platform_uid = '${searchParams.platform_uid}'`);
				console.log(
					`	$script:my_platform_token = '${searchParams.platform_token}'`
				);
				saveStorage(searchParams.platform_uid, searchParams.platform_token);
				disableRule(); // UID と TOKEN を取得したらルールを解除
			}
		}
	}
});

//メッセージが受信された時にルール有効化
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
	if (message.action === "enableRule") {
		enableRule();
		sendResponse({ status: true, data: "ルールを有効化しました" });
	}
});
