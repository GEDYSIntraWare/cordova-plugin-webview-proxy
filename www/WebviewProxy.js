/* global cordova */

function WebviewProxy() {
}

WebviewProxy.prototype.load = function (name, successCallback, errorCallback) {
  cordova.exec(
    successCallback,
    errorCallback,
    "WebviewProxy",
    "load",
    [name]
  );
};

WebviewProxy.prototype.setHostname = function (name, successCallback, errorCallback) {
  cordova.exec(
    successCallback,
    errorCallback,
    "WebviewProxy",
    "setHostname",
    [name]
  );
};

WebviewProxy.prototype.convertProxyUrl = function (path) {
  if (!path || !window.CDV_ASSETS_URL) {
      return path;
  }
  if (path.startsWith('http://')) {
      return window.CDV_ASSETS_URL + '/_http_proxy_' + encodeURIComponent(path.replace('http://', ''));
  }
  if (path.startsWith('https://')) {
      return window.CDV_ASSETS_URL + '/_https_proxy_' + encodeURIComponent(path.replace('https://', ''));
  }
  return path;
}

module.exports = new WebviewProxy();