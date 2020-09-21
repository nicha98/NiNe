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

#import <Foundation/Foundation.h>

#import "FSTImmutableSortedSet.h"

@class FSTDocumentKey;

NS_ASSUME_NONNULL_BEGIN

/** Convenience type for a set of keys, since they are so common. */
typedef FSTImmutableSortedSet<FSTDocumentKey *> FSTDocumentKeySet;

@interface FSTImmutableSortedSet (FSTDocumentKey)

/** Returns a new set using the DocumentKeyComparator. */
+ (FSTDocumentKeySet *)keySet;

@end

NS_ASSUME_NONNULL_END
