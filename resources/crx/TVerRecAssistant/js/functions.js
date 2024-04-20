//クエリパラメータの処理
function getSearchParams(search) {
	const params = new URLSearchParams(search);
	let result = {};
	for (const [key, value] of params) {
		result[key] = value;
	}
	return result;
}

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

// ストレージのクリア
function clearStorage() {
	chrome.storage.local.clear();
}

// 保存処理
function saveStorage(platform_uid, platform_token) {
	chrome.storage.local.set({
		key_uid: platform_uid,
		key_token: platform_token,
	});
	chrome.storage.local.get(console.log);
}

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
