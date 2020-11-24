#import <Cordova/CDV.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface WebviewProxy : CDVPlugin {
    
}

// TODO cancel running
@property (nonatomic) Boolean isRunning;

@end

@implementation WebviewProxy

- (BOOL) handleSchemeURL: (id <WKURLSchemeTask>)urlSchemeTask {
    self.isRunning = true;
    NSString * startPath = @"";
    NSURL * url = urlSchemeTask.request.URL;
    NSDictionary * header = urlSchemeTask.request.allHTTPHeaderFields;
    NSMutableString * stringToLoad = [NSMutableString string];
    [stringToLoad appendString:url.path];
    NSString * method = urlSchemeTask.request.HTTPMethod;
    NSData * body = urlSchemeTask.request.HTTPBody;
    
    if ([stringToLoad hasPrefix:@"/_http_proxy_"]||[stringToLoad hasPrefix:@"/_https_proxy_"]) {
        if(url.query) {
            [stringToLoad appendString:@"?"];
            [stringToLoad appendString:url.query];
        }                startPath = [stringToLoad stringByReplacingOccurrencesOfString:@"/_http_proxy_" withString:@"http://"];
        startPath = [startPath stringByReplacingOccurrencesOfString:@"/_https_proxy_" withString:@"https://"];
        NSLog(@"Proxy %@", startPath);
        NSURL * requestUrl = [NSURL URLWithString:startPath];
        WKWebsiteDataStore* dataStore = [WKWebsiteDataStore defaultDataStore];
        WKHTTPCookieStore* cookieStore = dataStore.httpCookieStore;
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setHTTPMethod:method];
        [request setURL:requestUrl];
        if (body) {
            [request setHTTPBody:body];
        }
        [request setAllHTTPHeaderFields:header];
        [request setHTTPShouldHandleCookies:YES];
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if(error) {
                NSLog(@"Proxy error: %@", error);
                [urlSchemeTask didFailWithError:error];
                return;
            }
            
            // set cookies to WKWebView
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if(httpResponse) {
                NSArray* cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[httpResponse allHeaderFields] forURL:response.URL];
                [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookies:cookies forURL:httpResponse.URL mainDocumentURL:nil];
                cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
                
                for (NSHTTPCookie* c in cookies)
                {
                    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                        //running in background thread is necessary because setCookie otherwise fails
                        dispatch_async(dispatch_get_main_queue(), ^(void){
                            [cookieStore setCookie:c completionHandler:nil];
                        });
                    });
                };
            }
            
            // Do not use urlSchemeTask if it has been closed in stopURLSchemeTask. Otherwise the app will crash.
            if(self.isRunning) {
                [urlSchemeTask didReceiveResponse:response];
                [urlSchemeTask didReceiveData:data];
                [urlSchemeTask didFinish];
            }
        }] resume];
        return  YES;
    }
    
    return NO;
}

- (void) pluginInitialize {
    NSLog(@"Proxy active on /_https_proxy");
}

- (void) load:(CDVInvokedUrlCommand*)command {
    NSLog(@"dummy");
}
@end
