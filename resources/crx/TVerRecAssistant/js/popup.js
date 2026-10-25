/*global chrome*/

// TVerのページが公開しているSDK(window.TVer)から認証情報を取得する。
// 通信のブロックやURLの解析は行わない。
// https://tver.jp/ および *.tver.jp のURLかどうかを判定する(正規表現ではなくURL APIで判定)
const isTVerUrl = (url) => {
	try {
		const { protocol, hostname } = new URL(url);
		return protocol === "https:" && (hostname === "tver.jp" || hostname.endsWith(".tver.jp"));
	} catch {
		return false;
	}
};
const $ = (id) => document.getElementById(id);

let currentText = "";

// TVerのページ(MAIN world)内で実行される関数。外部の変数は参照できない。
async function readTVerStatus() {
	const tver = window.TVer;
	if (!tver || typeof tver.getStatus !== "function") {
		return { ok: false, reason: "sdk" };
	}
	try {
		if (typeof tver.waitForInit === "function") {
			await Promise.race([
				tver.waitForInit(),
				new Promise((resolve) => setTimeout(resolve, 3000)),
			]);
		}
		const status = await tver.getStatus();
		let sid;
		if (status.login) {
			sid = status.session_id;
			if (!sid && typeof tver.getSessionID === "function") {
				sid = await tver.getSessionID();
			}
		}
		return {
			ok: true,
			login: Boolean(status.login),
			uid: status.platform_uid,
			token: status.platform_token,
			sid: sid,
		};
	} catch (e) {
		return { ok: false, reason: "error", message: String(e) };
	}
}

function setButtons({ open = false, copy = false, refresh = false }) {
	$("open").hidden = !open;
	$("copy").hidden = !copy;
	$("refresh").hidden = !refresh;
}

function clearValues() {
	currentText = "";
	for (const id of ["uid", "token", "sid"]) {
		$(id).textContent = "";
	}
}

function showStatus(text) {
	$("status").textContent = text;
}

function showResult(result) {
	// TVer IDにログイン中はmember_sidのみ、未ログインの場合はplatform_uidとplatform_tokenを使用する
	if (result.login && result.sid) {
		$("status").textContent = "TVer IDにログイン中です。member_sid を user_settings.ps1 に設定してください。";
		$("sid").textContent = `member_sid : ${result.sid}`;
		currentText = `$script:myMemberSID = '${result.sid}'`;
	} else if (!result.login && result.uid && result.token) {
		$("status").textContent = "未ログインです。platform_uid と platform_token を user_settings.ps1 に設定してください。";
		$("uid").textContent = `platform_uid : ${result.uid}`;
		$("token").textContent = `platform_token : ${result.token}`;
		currentText = `$script:myPlatformUID = '${result.uid}'\n$script:myPlatformToken = '${result.token}'`;
	} else {
		showStatus("認証情報を取得できませんでした。ページの読み込み完了後に再取得してください。");
		setButtons({ refresh: true });
		return;
	}
	setButtons({ copy: true, refresh: true });
}

async function load() {
	clearValues();
	setButtons({});
	showStatus("読み込み中...");

	const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
	if (!tab || !tab.url || !isTVerUrl(tab.url)) {
		showStatus("このページはTVerのページではありません。TVerのページを開いた状態で実行してください。");
		setButtons({ open: true });
		return;
	}

	try {
		const [injection] = await chrome.scripting.executeScript({
			target: { tabId: tab.id },
			world: "MAIN",
			func: readTVerStatus,
		});
		const result = injection && injection.result;
		if (result && result.ok) {
			showResult(result);
		} else if (result && result.reason === "sdk") {
			showStatus("TVerのSDKが見つかりません。TVer側の仕様が変更された可能性があります。");
			setButtons({ refresh: true });
		} else {
			showStatus(`取得に失敗しました。${(result && result.message) || ""}`);
			setButtons({ refresh: true });
		}
	} catch (e) {
		showStatus(`取得に失敗しました。${e}`);
		setButtons({ refresh: true });
	}
}

$("open").addEventListener("click", () => {
	chrome.tabs.create({ url: "https://tver.jp/mypage/fav" });
	window.close();
});

$("refresh").addEventListener("click", load);

$("copy").addEventListener("click", async () => {
	try {
		await navigator.clipboard.writeText(currentText);
		$("copy").textContent = "コピーしました";
		setTimeout(() => {
			$("copy").textContent = "user_settings.ps1用にコピー";
		}, 1500);
	} catch (e) {
		showStatus(`コピーに失敗しました。${e}`);
	}
});

load();
