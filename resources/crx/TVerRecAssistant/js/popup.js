function clearStorage() {
	chrome.storage.local.clear();
}

function readStorage() {
	chrome.storage.local.get(null, (data) => {
		console.log(`platform_uid = ${data.key_uid}`);
		console.log(`platform_token = ${data.key_token}`);
		document.getElementById("uid").innerText = "platform_uid = " + data.key_uid;
		document.getElementById("token").innerText =
			"platform_token = " + data.key_token;
	});
}

readStorage();


