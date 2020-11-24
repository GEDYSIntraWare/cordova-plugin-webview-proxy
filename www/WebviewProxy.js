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

module.exports = new WebviewProxy();