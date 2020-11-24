#import <Cordova/CDV.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface WebviewProxy : CDVPlugin {

}

@end

@implementation WebviewProxy

- (BOOL) handleSchemeURL: (id <WKURLSchemeTask>)urlSchemeTask {
    NSLog(@"New plugin");
    return  YES;
}

- (void) pluginInitialize {
    NSLog(@"Proxy active on /_https_proxy");
}

- (void) load:(CDVInvokedUrlCommand*)command {
    NSLog(@"dummy");
}
@end
