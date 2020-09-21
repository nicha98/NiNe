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

typedef NS_ENUM(NSInteger, FIRMessagingMessageCode) {
  // FIRMessaging+FIRApp.m
  kFIRMessagingMessageCodeFIRApp000 = 1000,  // I-FCM001000
  kFIRMessagingMessageCodeFIRApp001 = 1001,  // I-FCM001001
  // FIRMessaging.m
  kFIRMessagingMessageCodeMessagingPrintLibraryVersion = 2000,  // I-FCM002000
  kFIRMessagingMessageCodeMessaging001 = 2001,                  // I-FCM002001
  kFIRMessagingMessageCodeMessaging002 = 2002,                  // I-FCM002002 - no longer used
  kFIRMessagingMessageCodeMessaging003 = 2003,                  // I-FCM002003
  kFIRMessagingMessageCodeMessaging004 = 2004,                  // I-FCM002004
  kFIRMessagingMessageCodeMessaging005 = 2005,                  // I-FCM002005
  kFIRMessagingMessageCodeMessaging006 = 2006,                  // I-FCM002006 - no longer used
  kFIRMessagingMessageCodeMessaging007 = 2007,                  // I-FCM002007 - no longer used
  kFIRMessagingMessageCodeMessaging008 = 2008,                  // I-FCM002008 - no longer used
  kFIRMessagingMessageCodeMessaging009 = 2009,                  // I-FCM002009
  kFIRMessagingMessageCodeMessaging010 = 2010,                  // I-FCM002010
  kFIRMessagingMessageCodeMessaging011 = 2011,                  // I-FCM002011
  kFIRMessagingMessageCodeMessaging012 = 2012,                  // I-FCM002012
  kFIRMessagingMessageCodeMessaging013 = 2013,                  // I-FCM002013
  kFIRMessagingMessageCodeMessaging014 = 2014,                  // I-FCM002014
  kFIRMessagingMessageCodeMessaging015 = 2015,                  // I-FCM002015
  kFIRMessagingMessageCodeMessaging016 = 2016,                  // I-FCM002016 - no longer used
  kFIRMessagingMessageCodeMessaging017 = 2017,                  // I-FCM002017
  kFIRMessagingMessageCodeMessaging018 = 2018,                  // I-FCM002018
  kFIRMessagingMessageCodeRemoteMessageDelegateMethodNotImplemented = 2019,  // I-FCM002019
  kFIRMessagingMessageCodeSenderIDNotSuppliedForTokenFetch = 2020,           // I-FCM002020
  kFIRMessagingMessageCodeSenderIDNotSuppliedForTokenDelete = 2021,          // I-FCM002021
  kFIRMessagingMessageCodeAPNSTokenNotAvailableDuringTokenFetch = 2022,      // I-FCM002022
  kFIRMessagingMessageCodeTokenDelegateMethodsNotImplemented = 2023,         // I-FCM002023
  kFIRMessagingMessageCodeTopicFormatIsDeprecated = 2024,
  kFIRMessagingMessageCodeDirectChannelConnectionFailed = 2025,
  kFIRMessagingMessageCodeInvalidClient = 2026,
  // FIRMessagingClient.m
  kFIRMessagingMessageCodeClient000 = 4000,  // I-FCM004000
  kFIRMessagingMessageCodeClient001 = 4001,  // I-FCM004001
  kFIRMessagingMessageCodeClient002 = 4002,  // I-FCM004002
  kFIRMessagingMessageCodeClient003 = 4003,  // I-FCM004003
  kFIRMessagingMessageCodeClient004 = 4004,  // I-FCM004004
  kFIRMessagingMessageCodeClient005 = 4005,  // I-FCM004005
  kFIRMessagingMessageCodeClient006 = 4006,  // I-FCM004006
  kFIRMessagingMessageCodeClient007 = 4007,  // I-FCM004007
  kFIRMessagingMessageCodeClient008 = 4008,  // I-FCM004008
  kFIRMessagingMessageCodeClient009 = 4009,  // I-FCM004009
  kFIRMessagingMessageCodeClient010 = 4010,  // I-FCM004010
  kFIRMessagingMessageCodeClient011 = 4011,  // I-FCM004011
  kFIRMessagingMessageCodeClientInvalidState = 4012,
  kFIRMessagingMessageCodeClientInvalidStateTimeout = 4013,

  // DO NOT USE 5000 - 5023
  // FIRMessagingContextManagerService.m
  kFIRMessagingMessageCodeContextManagerService000 = 6000,  // I-FCM006000
  kFIRMessagingMessageCodeContextManagerService001 = 6001,  // I-FCM006001
  kFIRMessagingMessageCodeContextManagerService002 = 6002,  // I-FCM006002
  kFIRMessagingMessageCodeContextManagerService003 = 6003,  // I-FCM006003
  kFIRMessagingMessageCodeContextManagerService004 = 6004,  // I-FCM006004
  kFIRMessagingMessageCodeContextManagerService005 = 6005,  // I-FCM006005
  // FIRMessagingDataMessageManager.m
  // DO NOT USE 7000 - 7013

  // FIRMessagingPendingTopicsList.m
  kFIRMessagingMessageCodePendingTopicsList000 = 8000,  // I-FCM008000
  // FIRMessagingPubSub.m
  kFIRMessagingMessageCodePubSub000 = 9000,  // I-FCM009000
  kFIRMessagingMessageCodePubSub001 = 9001,  // I-FCM009001
  kFIRMessagingMessageCodePubSub002 = 9002,  // I-FCM009002
  kFIRMessagingMessageCodePubSub003 = 9003,  // I-FCM009003
  kFIRMessagingMessageCodePubSubArchiveError = 9004,
  kFIRMessagingMessageCodePubSubUnarchiveError = 9005,

  // DO NOT USE 100000 - 100005

  // FIRMessagingRegistrar.m
  kFIRMessagingMessageCodeRegistrar000 = 11000,  // I-FCM011000
  // FIRMessagingRemoteNotificationsProxy.m
  kFIRMessagingMessageCodeRemoteNotificationsProxy000 = 12000,             // I-FCM012000
  kFIRMessagingMessageCodeRemoteNotificationsProxy001 = 12001,             // I-FCM012001
  kFIRMessagingMessageCodeRemoteNotificationsProxyAPNSFailed = 12002,      // I-FCM012002
  kFIRMessagingMessageCodeRemoteNotificationsProxyMethodNotAdded = 12003,  // I-FCM012003
  // DO NOT USE 13000 -13010
  // FIRMessagingRmqManager.m
  kFIRMessagingMessageCodeRmqManager000 = 14000,  // I-FCM014000
  // DO NOT USE 15000 - 15016
  // DO NOT USE 16000 - 16008
  // FIRMessagingTopicOperation.m
  kFIRMessagingMessageCodeTopicOption000 = 17000,                  // I-FCM017000
  kFIRMessagingMessageCodeTopicOption001 = 17001,                  // I-FCM017001
  kFIRMessagingMessageCodeTopicOption002 = 17002,                  // I-FCM017002
  kFIRMessagingMessageCodeTopicOptionTopicEncodingFailed = 17003,  // I-FCM017003
  kFIRMessagingMessageCodeTopicOperationEmptyResponse = 17004,     // I-FCM017004
  // FIRMessagingUtilities.m
  kFIRMessagingMessageCodeUtilities000 = 18000,  // I-FCM018000
  kFIRMessagingMessageCodeUtilities001 = 18001,  // I-FCM018001
  kFIRMessagingMessageCodeUtilities002 = 18002,  // I-FCM018002
  // FIRMessagingAnalytics.m
  kFIRMessagingMessageCodeAnalytics000 = 19000,                         // I-FCM019000
  kFIRMessagingMessageCodeAnalytics001 = 19001,                         // I-FCM019001
  kFIRMessagingMessageCodeAnalytics002 = 19002,                         // I-FCM019002
  kFIRMessagingMessageCodeAnalytics003 = 19003,                         // I-FCM019003
  kFIRMessagingMessageCodeAnalytics004 = 19004,                         // I-FCM019004
  kFIRMessagingMessageCodeAnalytics005 = 19005,                         // I-FCM019005
  kFIRMessagingMessageCodeAnalyticsInvalidEvent = 19006,                // I-FCM019006
  kFIRMessagingMessageCodeAnalytics007 = 19007,                         // I-FCM019007
  kFIRMessagingMessageCodeAnalyticsCouldNotInvokeAnalyticsLog = 19008,  // I-FCM019008

  // FIRMessagingExtensionHelper.m
  kFIRMessagingServiceExtensionImageInvalidURL = 20000,
  kFIRMessagingServiceExtensionImageNotDownloaded = 20001,
  kFIRMessagingServiceExtensionLocalFileNotCreated = 20002,
  kFIRMessagingServiceExtensionImageNotAttached = 20003,

  // FIRMessagingCodedInputStream.m
  kFIRMessagingCodeInputStreamInvalidParameters = 21000,

};
