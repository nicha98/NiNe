/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "AppDelegate.h"
#import "ViewController.h"

#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIROptions.h>
#import <FirebaseDynamicLinks/FIRDynamicLinks.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [FIRApp configure];

  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  UINavigationController *navController = [[UINavigationController alloc]
      initWithRootViewController:[[ViewController alloc] initWithNibName:nil bundle:nil]];
  self.window.rootViewController = navController;
  [self.window makeKeyAndVisible];

#ifdef DEBUG
  [FIRDynamicLinks performDiagnosticsWithCompletion:nil];
#endif  // DEBUG

  return YES;
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<NSString *, id> *)options {
  FIRDynamicLink *dynamicLink = [[FIRDynamicLinks dynamicLinks] dynamicLinkFromCustomSchemeURL:url];

  if (dynamicLink) {
    [self _showDynamicLinkInfo:dynamicLink];
  }
  return YES;
}

- (BOOL)application:(UIApplication *)application
              openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication
           annotation:(id)annotation {
  return [self application:application openURL:url options:@{}];
}

- (BOOL)application:(UIApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:
#if __has_include(<UIKit/UIUserActivity.h>)
          (void (^)(NSArray<id<UIUserActivityRestoring>> *_Nullable))restorationHandler {
#else
          (void (^)(NSArray *))restorationHandler {
#endif
  BOOL handled = [[FIRDynamicLinks dynamicLinks]
      handleUniversalLink:userActivity.webpageURL
               completion:^(FIRDynamicLink *_Nullable dynamicLink, NSError *_Nullable error) {
                 [self _showDynamicLinkInfo:dynamicLink];
               }];

  if (!handled) {
    // Show the deep link URL from userActivity.
    NSLog(@"Unhandled link %@", userActivity.webpageURL);
  }

  return handled;
}

- (void)_showDynamicLinkInfo:(FIRDynamicLink *)dynamicLink {
  NSLog(@"Got dynamic link %@", dynamicLink);

  UIAlertController *alertVC = [UIAlertController
      alertControllerWithTitle:@"Got Dynamic Link!"
                       message:[NSString stringWithFormat:
                                             @"URL [%@], matchType [%ld], minimumAppVersion [%@]",
                                             dynamicLink.url, (unsigned long)dynamicLink.matchType,
                                             dynamicLink.minimumAppVersion]
                preferredStyle:UIAlertControllerStyleAlert];
  [alertVC addAction:[UIAlertAction actionWithTitle:@"Dismiss"
                                              style:UIAlertActionStyleCancel
                                            handler:NULL]];
  [self.window.rootViewController presentViewController:alertVC animated:YES completion:NULL];
}

@end
