chrome.storage.onChanged.addListener((changes, namespace) => {
	for (let [key, { oldValue, newValue }] of Object.entries(changes)) {
		console.log(
			`Storage key "${key}" in namespace "${namespace}" changed.`,
			`Old value was "${oldValue}", new value is "${newValue}".`
		);
	}
});

// メッセージが受信された時に実行する処理
chrome.runtime.onMessage.addListener((message, sender) => {
	console.log(message.message);

	// const tabId = sender.tab.id;

	// if (tabId) {
	// 	// panel.jsにメッセージを送信
	// 	chrome.tabs.sendMessage(tabId, {
	// 		message: "panel.jsに送るメッセージ",
	// 	});
	// }
});

// ルールの無効化
function disableRule() {
	chrome.declarativeNetRequest.updateEnabledRulesets(
		{ disableRulesetIds: ["ruleset"] },
		() => {}
	);
	console.log("TVerRec Assistant: Rule Disabled");
}

// ルールの有効化
function enableRule() {
	chrome.declarativeNetRequest.updateEnabledRulesets(
		{ enableRulesetIds: ["ruleset"] },
		() => {}
	);
	console.log("TVerRec Assistant: Rule Enabled");
	disableRule();
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

// ネットワークリクエストに関するイベントを監視
chrome.declarativeNetRequest.onRuleMatchedDebug.addListener((e) => {
	console.log("TVerRec Assistant: Connection Blocked by TVerRec");
	console.log(e.request.url);

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
			console.log("	URL:", e.request.url);
			const searchParams = getSearchParams(url.search);
			console.log("	Param Array:", searchParams);
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
