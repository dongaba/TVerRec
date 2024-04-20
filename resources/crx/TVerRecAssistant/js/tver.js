// 監視対象の設定
const config = { attributes: false, childList: true, subtree: true };

// ミューテーションオブザーバーのコールバック関数
const callback = function (mutationsList, observer) {
	for (const mutation of mutationsList) {
		if (mutation.type === "childList") {
			//通信エラーの閉じるボタン
			const button = document.querySelector(
				".button_button__GOl5m.error-modal_button__fgiuz"
			);
			if (button) {
				button.click();
				// 必要ならば監視を解除
				//observer.disconnect();
				break;
			}
		}
	}
};

// ミューテーションオブザーバーのインスタンスを作成
const observer = new MutationObserver(callback);

// 監視を開始する
observer.observe(document.body, config);
