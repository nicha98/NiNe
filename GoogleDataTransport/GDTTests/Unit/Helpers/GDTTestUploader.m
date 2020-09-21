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

#import "GDTTests/Unit/Helpers/GDTTestUploader.h"

@implementation GDTTestUploader

- (void)uploadPackage:(GDTUploadPackage *)package
           onComplete:(GDTUploaderCompletionBlock)onComplete {
  if (_uploadEventsBlock) {
    _uploadEventsBlock(package, onComplete);
  } else if (onComplete) {
    onComplete(kGDTTargetCCT, [GDTClock snapshot], nil);
  }
  [package completeDelivery];
}

- (void)appWillBackground:(nonnull UIApplication *)app {
}

- (void)appWillForeground:(nonnull UIApplication *)app {
}

- (void)appWillTerminate:(UIApplication *)application {
}

@end
