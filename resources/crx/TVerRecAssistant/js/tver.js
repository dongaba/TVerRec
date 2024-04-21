//オブザーバの設定
const config = { attributes: false, childList: true, subtree: true };

//通信エラーの閉じるボタン
const button = document.querySelector(".button_button__GOl5m.error-modal_button__fgiuz");

// ミューテーションオブザーバーのコールバック関数
const callback = function (mutationsList) {
	for (const mutation of mutationsList) {
		if (mutation.type === "childList") {
			if (button) {
				button.click();
				break;
			}
		}
	}
};

//MutationObserverのインスタンスを作成
const observer = new MutationObserver(callback);

//監視を開始
observer.observe(document.body, config);
