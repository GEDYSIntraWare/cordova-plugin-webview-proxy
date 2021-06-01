#import <Cordova/CDV.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface WebviewProxy : CDVPlugin {
    
}

@property (nonatomic) NSMutableArray* stoppedTasks;

- (void)clearCookies:(CDVInvokedUrlCommand*)command;
- (void)setCookie:(CDVInvokedUrlCommand*)command;
- (void)deleteCookie:(CDVInvokedUrlCommand*)command;

@end

@implementation WebviewProxy

- (void) pluginInitialize {
    NSLog(@"Proxy active on /_https_proxy and /_http_proxy_");
    self.stoppedTasks = [[NSMutableArray alloc] init];
}

- (BOOL) overrideSchemeTask: (id <WKURLSchemeTask>)urlSchemeTask {
    NSString * startPath = @"";
    NSURL * url = urlSchemeTask.request.URL;
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
        // create cookies for the requestUrl and merge them with the existing http header fields
        NSArray *requestCookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:requestUrl];
        NSDictionary * cookieHeaders = [NSHTTPCookie requestHeaderFieldsWithCookies:requestCookies];
        NSMutableDictionary * allHTTPHeaderFields = [cookieHeaders mutableCopy];
        [allHTTPHeaderFields addEntriesFromDictionary:urlSchemeTask.request.allHTTPHeaderFields];
        // we're taking care of cookies
        [request setHTTPShouldHandleCookies:NO];
        
        [request setHTTPMethod:method];
        [request setURL:requestUrl];
        if (body) {
            [request setHTTPBody:body];
        }
        [request setAllHTTPHeaderFields:allHTTPHeaderFields];
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
                            NSLog(@"set cookie %@:%@:%@", c.domain, c.name, c.value);
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

- (void)deleteCookie:(CDVInvokedUrlCommand *)command {
    NSMutableDictionary* options = [command.arguments objectAtIndex:0];
    
    if ([options objectForKey:@"domain"] == nil || [options objectForKey:@"name"] == nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    @try {
        NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in storage.cookies) {
            bool domainMatch = [cookie.domain isEqualToString: [options objectForKey:@"domain"]];
            bool nameMatch =[cookie.name isEqualToString: [options objectForKey:@"name"]];
            
            if (domainMatch && nameMatch && (([options objectForKey:@"path"] != nil && [cookie.path isEqualToString: [options objectForKey:@"path"]]) || [options objectForKey:@"path"] == nil)) {
                NSLog(@"deleteCookie(): removed cookie %@:%@:%@ from sharedHTTPCookieStorage", cookie.domain, cookie.name, cookie.value);
                [storage deleteCookie:cookie];
            }
        }
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    @catch (NSException *exception) {
        NSLog(@"WebViewProxy deleteCookie() exception: %@", exception.debugDescription);
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception.reason];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}

- (void)setCookie:(CDVInvokedUrlCommand *)command {
    @try {
        WKWebsiteDataStore* dataStore = [WKWebsiteDataStore defaultDataStore];
        WKHTTPCookieStore* cookieStore = dataStore.httpCookieStore;
        
        NSMutableDictionary* options = [command.arguments objectAtIndex:0];
        
        NSMutableDictionary *cookieProperties = [NSMutableDictionary dictionary];
        if ([options objectForKey:@"comment"] != nil) [cookieProperties setObject:[options objectForKey:@"comment"] forKey:NSHTTPCookieComment];
        if ([options objectForKey:@"commentUrl"] != nil)[cookieProperties setObject:[options objectForKey:@"commentUrl"] forKey:NSHTTPCookieCommentURL];
        if ([options objectForKey:@"discard"] != nil) [cookieProperties setObject:[options objectForKey:@"discard"] forKey:NSHTTPCookieDiscard];
        if ([options objectForKey:@"domain"] != nil) [cookieProperties setObject:[options objectForKey:@"domain"] forKey:NSHTTPCookieDomain];  // required
        if ([options objectForKey:@"expires"] != nil) [cookieProperties setObject:[options objectForKey:@"expires"] forKey:NSHTTPCookieExpires];
        if ([options objectForKey:@"maximumAge"] != nil) [cookieProperties setObject:[NSString stringWithFormat:@"%@",[options objectForKey:@"maximumAge"]]
                                                                              forKey:NSHTTPCookieMaximumAge];
        if ([options objectForKey:@"name"] != nil) [cookieProperties setObject:[options objectForKey:@"name"] forKey:NSHTTPCookieName];  // required
        if ([options objectForKey:@"domain"] != nil) [cookieProperties setObject:[options objectForKey:@"domain"] forKey:NSHTTPCookieOriginURL];  // reuse required domain
        if ([options objectForKey:@"path"] != nil) [cookieProperties setObject:[options objectForKey:@"path"] forKey:NSHTTPCookiePath]; // required
        if ([options objectForKey:@"port"] != nil) [cookieProperties setObject:[options objectForKey:@"port"] forKey:NSHTTPCookiePort];
        if (@available(iOS 13.0, *)) {
            if ([options objectForKey:@"sameSite"] != nil) [cookieProperties setObject:[options objectForKey:@"sameSite"] forKey:NSHTTPCookieSameSitePolicy];
        }
        if ([options objectForKey:@"secure"] != nil) [cookieProperties setObject:[options objectForKey:@"secure"] forKey:NSHTTPCookieSecure];
        if ([options objectForKey:@"value"] != nil) [cookieProperties setObject:[options objectForKey:@"value"] forKey:NSHTTPCookieValue];  // required
        if ([options objectForKey:@"version"] != nil) [cookieProperties setObject:[options objectForKey:@"version"] forKey:NSHTTPCookieVersion];
        
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
        NSLog(@"setCookie(): %@:%@:%@", cookie.domain, cookie.name, cookie.value);
        NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        [storage setCookie:cookie];
        
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            //running in background thread is necessary because setCookie otherwise fails
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [cookieStore setCookie:cookie completionHandler:^{
                    NSLog(@"set cookie %@:%@:%@", cookie.domain, cookie.name, cookie.value);
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }];
            });
        });
        
        
    }
    @catch (NSException *exception) {
        NSLog(@"WebViewProxy setCookie() exception: %@", exception.debugDescription);
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception.reason];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) clearCookies:(CDVInvokedUrlCommand*)command {
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    if (storage.cookies.count > 0) {
        for (NSHTTPCookie *cookie in storage.cookies) {
            NSLog(@"clearCookies(): removed cookie %@:%@:%@", cookie.domain, cookie.name, cookie.value);
            [storage deleteCookie:cookie];
        }
        NSLog(@"clearCookies(): all cookies cleared");
        
    } else {
        NSLog(@"clearCookies(): no cookies found to be cleared");
    }
    
    WKWebsiteDataStore* dataStore = [WKWebsiteDataStore defaultDataStore];
    WKHTTPCookieStore* cookieStore = dataStore.httpCookieStore;
    
    [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> * cookies) {
        if ([cookies count] == 0) {
            NSLog(@"no cookies to be removed");
        }
        dispatch_group_t group = dispatch_group_create();
        for (NSHTTPCookie* _c in cookies)
        {
            dispatch_group_enter(group);
            [cookieStore deleteCookie:_c completionHandler:^{
                NSLog(@"removed cookie %@:%@:%@ from defaultDataStore", _c.domain, _c.name, _c.value);
                dispatch_group_leave(group);
            }];
        };
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        });
    }];
}

@end
