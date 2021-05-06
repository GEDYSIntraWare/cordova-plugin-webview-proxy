#import <Cordova/CDV.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface WebviewProxy : CDVPlugin {
    
}

@property (nonatomic) NSMutableArray* stoppedTasks;

@end

@implementation WebviewProxy

- (void) pluginInitialize {
    NSLog(@"Proxy active on /_https_proxy and /_http_proxy_");
    self.stoppedTasks = [[NSMutableArray alloc] init];
}

- (BOOL) overrideSchemeTask: (id <WKURLSchemeTask>)urlSchemeTask {
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
        [request setTimeoutInterval:1800];
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if(error && (self.stoppedTasks == nil || ![self.stoppedTasks containsObject:urlSchemeTask])) {
                @try {
                    NSLog(@"WebviewProxy error: %@", error);
                    [urlSchemeTask didFailWithError:error];
                    return;
                } @catch (NSException *exception) {
                    NSLog(@"WebViewProxy send error exception: %@", exception.debugDescription);
                }
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
            @try {
                if(self.stoppedTasks == nil || ![self.stoppedTasks containsObject:urlSchemeTask]) {
                    [urlSchemeTask didReceiveResponse:response];
                    [urlSchemeTask didReceiveData:data];
                    [urlSchemeTask didFinish];
                } else {
                    NSLog(@"Task stopped %@", startPath);
                }
            } @catch (NSException *exception) {
                NSLog(@"WebViewProxy send response exception: %@", exception.debugDescription);
            } @finally {
                // Cleanup
                [self.stoppedTasks removeObject:urlSchemeTask];
            }
        }] resume];
        return  YES;
    }
    
    return NO;
}

- (void) stopSchemeTask: (id <WKURLSchemeTask>)urlSchemeTask {
    NSLog(@"Stop WevViewProxy %@", urlSchemeTask.debugDescription);
    [self.stoppedTasks addObject:urlSchemeTask];
}

@end
