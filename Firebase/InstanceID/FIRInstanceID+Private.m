/*
 * Copyright 2019 Google
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

#if SWIFT_PACKAGE
#import "Firebase/InstanceID/Private/FIRInstanceID+Private.h"
#import "Firebase/InstanceID/Private/FIRInstanceID_Private.h"
#else
#import <FirebaseInstanceID/FIRInstanceID+Private.h>
#import <FirebaseInstanceID/FIRInstanceID_Private.h>
#endif

#if SWIFT_PACKAGE
@import FirebaseInstallations;
#else
#import <FirebaseInstallations/FirebaseInstallations.h>
#endif

#import "FIRInstanceIDAuthService.h"
#import "FIRInstanceIDDefines.h"
#import "FIRInstanceIDTokenManager.h"

@class FIRInstallations;

@interface FIRInstanceID ()

@property(nonatomic, readonly, strong) FIRInstanceIDTokenManager *tokenManager;

@end

@implementation FIRInstanceID (Private)

// This method just wraps our pre-configured auth service to make the request.
// This method is only needed by first-party users, like Remote Config.
- (void)fetchCheckinInfoWithHandler:(FIRInstanceIDDeviceCheckinCompletion)handler {
  [self.tokenManager.authService fetchCheckinInfoWithHandler:handler];
}

// TODO(#4486): Delete the method, `self.firebaseInstallationsID` and related
// code for Firebase 7 release.
- (NSString *)appInstanceID:(NSError **)outError {
  return self.firebaseInstallationsID;
}

#pragma mark - Firebase Installations Compatibility

/// Presence of this method indicates that this version of IID uses FirebaseInstallations under the
/// hood. It is checked by FirebaseInstallations SDK.
+ (BOOL)usesFIS {
  return YES;
}

@end
