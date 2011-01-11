
#import "AppDelegate.h"
#import <Growl/Growl.h>

@implementation AppDelegate

@synthesize window, webView;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification { 
  [webView setMainFrameURL:@"https://irccloud.com"];
  [webView setFrameLoadDelegate:self];
  [webView setPolicyDelegate:self];
  [webView setUIDelegate:self];

  // listen for title changes
  [webView addObserver:self
            forKeyPath:@"mainFrameTitle"
               options:NSKeyValueObservingOptionNew
               context:NULL];

  // seems you have to kickstart the GrowlApplicationBridge :|
  [GrowlApplicationBridge setGrowlDelegate:nil];
}

#pragma mark -

- (void)titleDidChange:(NSString *)title {
  NSUInteger unread = 0;

  if ([[title substringToIndex:1] isEqualToString:@"*"]) {
    title = [title substringFromIndex:2];
  } else if ([[title substringToIndex:1] isEqualToString:@"("]) {
    NSRange range = [title rangeOfString:@")"];
    range.length = range.location - 1;
    range.location = 1;
    unread = [[title substringWithRange:range] intValue];
    title = [title substringFromIndex:range.location + range.length + 2];
  }

  NSString *badge = nil;
  if (unread > 0) {
    badge = [NSString stringWithFormat:@"%d", unread];
  }

  NSRange pipepos = [title rangeOfString:@" | IRCCloud" options:NSBackwardsSearch];
  if (pipepos.location != NSNotFound) {
    title = [title substringToIndex:pipepos.location];
  }

  if (!badge) {
    [[[NSApplication sharedApplication] dockTile] setBadgeLabel:badge];
  }
  [window setTitle:title];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if ([keyPath isEqualToString:@"mainFrameTitle"]) {
    [self titleDidChange:[change valueForKey:@"new"]];
  }
}

#pragma mark FrameLoadDelegate

- (void)webView:(WebView *)sender didClearWindowObject:(WebScriptObject *)windowScriptObject forFrame:(WebFrame *)frame {
  [windowScriptObject setValue:self forKey:@"webkitNotifications"];
}

#pragma mark WebPolicyDelegate

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request
   newFrameName:(NSString *)frameName decisionListener:(id <WebPolicyDecisionListener>)listener {
  // route all links that request a new window to default browser
  [listener ignore];
  [[NSWorkspace sharedWorkspace] openURL:[request URL]];
}

#pragma mark WebUIDelegate

- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
  NSInteger result = NSRunAlertPanel(@"Please confirm", message, @"Yes", @"No", nil);
  return result == NSAlertDefaultReturn;
}

#pragma mark WebkitNotifications

- (int)checkPermission {
  // always grant permission (0 = allow, 1 = unknown, 2 = denied)
  return 0;
}

- (void)createNotificationWithIcon:(NSString *)icon title:(NSString *)title message:(NSString *)message {
  NSString *badge = [[[NSApplication sharedApplication] dockTile] badgeLabel];
  if (!badge || [badge isEqualToString:@""]) {
    badge = @"0";
  }
  int unread = [badge intValue] + 1;
  NSString *newBadge = [NSString stringWithFormat:@"%d", unread];
  [[[NSApplication sharedApplication] dockTile] setBadgeLabel:newBadge];
	
  // this is a lazy implementation of notifications. works as long every notification in the
  // irccloud app calls notification.show() directly after creating it
  [GrowlApplicationBridge notifyWithTitle:title
                              description:message
                         notificationName:@"IRCCloudMessage"
                                 iconData:nil
                                 priority:0
                                 isSticky:NO
                             clickContext:nil];
}

+(NSString *)webScriptNameForSelector:(SEL)sel {
  if (sel == @selector(checkPermission)) {
    return @"checkPermission";
  } else if (sel == @selector(createNotificationWithIcon:title:message:)) {
    return @"createNotification";
  }
  return nil;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)sel {
  if (sel == @selector(checkPermission) || sel == @selector(createNotificationWithIcon:title:message:)) {
    return NO;
  }
  return YES;
}

@end
