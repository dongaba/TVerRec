function checkIframeLoaded() {

	// Get a handle to the iframe element
	var iframe = document.getElementById('enqueteframe');
	var iframeDoc = iframe.contentDocument || iframe.contentWindow.document;

	// Check if loading is complete
	if (iframeDoc.readyState == 'complete') {
		//iframe.contentWindow.alert("Hello");
		iframe.contentWindow.onload = function () {
			alert("I am loaded");
		};
		// The loading is complete, call the function we want executed once the iframe is loaded
		//whrite_here_custome_code();
		return;
	}

	// If we are here, it is not loaded. Set things up so we check   the status again in 100 milliseconds
	window.setTimeout(checkIframeLoaded, 100);
}


function ReplaceEnquete() {

	//既存コード削除
	var base1 = document.getElementById("enquete");
	base1.innerHTML = "";

	//独自コード追加
	var obj1 = document.createElement("div");
	obj1.setAttribute("class", "eqbg");
	obj1.setAttribute("onclick", "enquete.closeEnquete()");
	obj1.setAttribute("style", "display: block");
	obj1.setAttribute("id", "eqbg");
	base1.appendChild(obj1);

	var obj2 = document.createElement("div");
	obj2.setAttribute("class", "eqform");
	obj2.setAttribute("style", "display: block");
	obj2.setAttribute("id", "eqform");
	base1.appendChild(obj2);

	var base2 = document.getElementById("eqform");
	base2.innerHTML = "";

	var obj3 = document.createElement("iframe");
	obj3.setAttribute("src", "https://tver.jp/enquete/index.html");
	obj3.setAttribute("frameBorder", "0");
	obj3.setAttribute("scrolling", "yes");
	obj3.setAttribute("id", "enqueteframe");
	obj3.setAttribute("style", "display: inline");
	base2.appendChild(obj3);

}

window.addEventListener('load', function () {
	//アンケート存在チェック
	if (document.getElementById("enquete") != null) {

		//Test Code
		//		window.alert('アンケート検知！');

		//アンケート差し替え
		//		ReplaceEnquete();		//差し替えは成功する

		//iframeの読み込みを待ってアンケート回答
		//		checkIframeLoaded();		//でもiframe内のオブジェクトは操作できなかった。ChromeのデバッガのConsoleでは動くので、コードは正しいはず。

		//再読込したらアンケートが消える
		location.reload();

	}
})

