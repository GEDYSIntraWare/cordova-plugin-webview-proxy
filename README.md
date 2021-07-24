# cordova-plugin-webview-proxy

> Work in progress plugin.
## Cordova Plugin to proxy http(s) requests on iOS without CORS and Cookie restrictions

With this plugin you can do requests to remote servers just like you would do normally. Cookies and CORS restrictions don't apply here because the requests is performed by native code.

You just need to change the URL:

```javascript
const response = await fetch(window.WebviewProxy.convertProxyUrl(url));
console.debug(response);
```

#### To delete all Cookies use this:
```javascript
window.WebviewProxy.clearCookie();
```

# Make sure you are using a custom scheme with your iOS platform

This plugin uses the WKURLSchemeHandler provided by WKWebView. It requires the latest version of cordova-ios.

**You enable the custom scheme by setting these preferences in config.xml**

```xml
<preference name="scheme" value="app" />
<preference name="hostname" value="testapp"/>
```
# Testing this plugin

[This test app](https://github.com/NiklasMerz/cors-cookie-proxy-test-app) with custom pages and a simple backend is helpful for testing and developing this plugin.