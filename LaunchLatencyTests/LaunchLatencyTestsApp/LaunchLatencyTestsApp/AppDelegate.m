//
//  AppDelegate.m
//  LaunchLatencyTestsApp
//
//  Created by Maksym Malyhin on 2020-02-13.
//  Copyright © 2020 Google Inc. All rights reserved.
//

#import "AppDelegate.h"
#import <Firebase/Firebase.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [FIRApp configure];
  return YES;
}

@end
