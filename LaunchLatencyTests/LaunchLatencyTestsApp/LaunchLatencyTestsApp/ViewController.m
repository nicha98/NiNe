//
//  ViewController.m
//  LaunchLatencyTestsApp
//
//  Created by Maksym Malyhin on 2020-02-13.
//  Copyright © 2020 Google Inc. All rights reserved.
//

#import "ViewController.h"
#import <Firebase/Firebase.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  [self sendNetworkRequest];
}

- (void)sendNetworkRequest {
  NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"https://google.com"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    NSLog(@"Request finished.");
    [self sendNetworkRequest];
  }];

  [task resume];
}


@end
