/* global cordova */

function WebviewProxy() {
}

WebviewProxy.prototype.convertProxyUrl = function (path) {
    if (!path) {
        return path;
    }
    if (!window.CDV_ASSETS_URL) {
        //Android 10.x origin
        window.CDV_ASSETS_URL = location.origin
    }
    if (path.startsWith('http://')) {
        return window.CDV_ASSETS_URL + '/_http_proxy_' + encodeURIComponent(path.replace('http://', ''));
    }
    if (path.startsWith('https://')) {
        return window.CDV_ASSETS_URL + '/_https_proxy_' + encodeURIComponent(path.replace('https://', ''));
    }
    return path;
}

WebviewProxy.prototype.clearCookie = function (successCallback, errorCallback) {
    cordova.exec(successCallback, errorCallback, "WebviewProxy", "clearCookie", []);
}

module.exports = new WebviewProxy();