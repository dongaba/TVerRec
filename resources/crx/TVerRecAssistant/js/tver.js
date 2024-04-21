//オブザーバの設定
const config = { attributes: false, childList: true, subtree: true };

//通信エラーの閉じるボタン
const button = document.querySelector(".button_button__GOl5m.error-modal_button__fgiuz");

// ミューテーションオブザーバーのコールバック関数
const callback = function (mutationsList, observer) {
	for (const mutation of mutationsList) {
		if (mutation.type === "childList") {

			if (button) {
				button.click();
				//必要がなくなったら監視を停止
				//observer.disconnect();

				break;
			}
		}
	}
};

//MutationObserverのインスタンスを作成
const observer = new MutationObserver(callback);

//監視を開始
observer.observe(document.body, config);
