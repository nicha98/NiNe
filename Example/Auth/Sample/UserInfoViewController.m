/*
 * Copyright 2017 Google
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

#import "UserInfoViewController.h"

#import "FIRUser.h"
#import "FIRUserInfo.h"
#import "FIRUserMetadata.h"
#import "StaticContentTableViewManager.h"

/** @fn stringWithBool
    @brief Converts a boolean value to a string for display.
    @param boolValue the boolean value.
    @return The string form of the boolean value.
 */
static NSString *stringWithBool(BOOL boolValue) {
  return boolValue ? @"YES" : @"NO";
}

/** @fn stringFromDate
    @brief Converts a NSDate va to a string for display.
    @param date The NSDate instance.
    @return The string form of the NSDate instance.
 */
static NSString *stringFromDate(NSDate *date) {
  if (!date) {
    return @"nil";
  }
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  dateFormatter.dateStyle = NSDateFormatterShortStyle;
  dateFormatter.timeStyle = NSDateFormatterShortStyle;
  return [dateFormatter stringFromDate:date];
}

@implementation UserInfoViewController {
  FIRUser *_user;
}

- (instancetype)initWithUser:(FIRUser *)user {
  self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil];
  if (self) {
    _user = user;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self loadTableView];
}

- (void)loadTableView {
  NSMutableArray<StaticContentTableViewSection *> *sections = [@[
    [StaticContentTableViewSection sectionWithTitle:@"User" cells:@[
      [StaticContentTableViewCell cellWithTitle:@"anonymous" value:stringWithBool(_user.anonymous)],
      [StaticContentTableViewCell cellWithTitle:@"Creation date"
                                          value:stringFromDate(_user.metadata.creationDate)],
      [StaticContentTableViewCell cellWithTitle:@"Last sign in date"
                                          value:stringFromDate(_user.metadata.lastSignInDate)],
      [StaticContentTableViewCell cellWithTitle:@"emailVerified"
                                          value:stringWithBool(_user.emailVerified)],
      [StaticContentTableViewCell cellWithTitle:@"refreshToken" value:_user.refreshToken],
    ]]
  ] mutableCopy];
  [sections addObject:[self sectionWithUserInfo:_user]];
  for (id<FIRUserInfo> userInfo in _user.providerData) {
    [sections addObject:[self sectionWithUserInfo:userInfo]];
  }
  _tableViewManager.contents = [StaticContentTableViewContent contentWithSections:sections];
}

- (StaticContentTableViewSection *)sectionWithUserInfo:(id<FIRUserInfo>)userInfo {
  return [StaticContentTableViewSection sectionWithTitle:userInfo.providerID cells:@[
    [StaticContentTableViewCell cellWithTitle:@"uid" value:userInfo.uid],
    [StaticContentTableViewCell cellWithTitle:@"displayName" value:userInfo.displayName],
    [StaticContentTableViewCell cellWithTitle:@"photoURL" value:[userInfo.photoURL absoluteString]],
    [StaticContentTableViewCell cellWithTitle:@"email" value:userInfo.email],
    [StaticContentTableViewCell cellWithTitle:@"phoneNumber" value:userInfo.phoneNumber]
  ]];
}

- (IBAction)done:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
}

@end
