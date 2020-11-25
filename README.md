# cordova-plugin-webview-proxy

> Work in progress plugin.
## Cordova Plugin to proxy http(s) requests on iOS without CORS and Cookie restrictions

With this plugin you can do requests to remote servers just like you would do normally. Cookies and CORS restrictions don't apply here because the requests is performed by native code.

You just need to change the URL:

```javascript
const response = await fetch(window.WebviewProxy.convertProxyUrl(url));
console.debug(response);
```

This plugin uses the WKURLSchemeHandler provided by WKWebView. It requires a Work in Progress Integration in cordova-ios: https://github.com/apache/cordova-ios/pull/1030
