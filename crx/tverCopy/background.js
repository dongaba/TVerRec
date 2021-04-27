chrome.webRequest.onBeforeRequest.addListener(
    function (details) {
        //  console.log(details);
        var url = details['url'];
        var re2 = new RegExp("https?://");
        if (re2.test(url)) {
            //    console.log(url);
            var seiki = ".m3u8";
            var re = new RegExp(seiki, "i");
            if (re.test(url)) {
                var xhr = new XMLHttpRequest();
                xhr.open("GET", url, true);
                xhr.onreadystatechange = function () {
                    if (xhr.readyState == 4) {
                        var body = xhr.responseText;
                        var re = new RegExp(/\.ts/);
                        if (re.test(body)) { return; }
                        var re = new RegExp(/\.m3u8/);
                        if (re.test(body)) { ClipboardSetData(url); }
                    }
                }
                xhr.send();
            }
        }
    },
    { urls: ['<all_urls>'] },
    []
);

function ClipboardSetData(data) {
    var body = document.body;
    if (!body) return false;

    var text_area = document.createElement("textarea");
    text_area.value = data;
    body.appendChild(text_area);
    text_area.select();
    var result = document.execCommand("copy");
    body.removeChild(text_area);
    return result;
}

