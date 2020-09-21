# 2020-01 -- v 4.2.0
- [added] Added watchOS support for Firebase Messaging. This enables FCM push notification function on watch only app or independent watch app. (#4016)

# 2019-12 -- v4.1.10
- [fixed] Fix component startup time. (#4137)

# 2019-11-19 -- v4.1.9
- [changed] Moved message queue delete operation to a serial queue to avoid race conditions in unit tests. (#4236)

# 2019-11-05 -- v4.1.8
- [changed] Moved reliable message queue database operation off main thread. (#4053)

# 2019-10-22 -- v4.1.7
- [fixed] Fixed IID and Messaging container instantiation timing issue. (#4030)
- [changed] Internal cleanup and remove migration logic from document folder to application folder. (#4033, #4045)

# 2019-10-08 -- v4.1.6
- [changed] Internal cleanup. (#3857)

# 2019-09-23 -- v4.1.5
- [fixed] Mute FCM deprecated warnings with Xcode 11 and min iOS >= 10. (#3857)

# 2019-09-03 -- v4.1.4
- [fixed] Fixed notification open event is not logged when scheduling a local timezone message. (#3670, #3638)
- [fixed] Fixed FirebaseApp.delete() results in unusable Messaging singleton. (#3411)

# 2019-08-20 -- v4.1.3
- [changed] Cleaned up the documents, unused macros, and folders. (#3490, #3537, #3556, #3498)
- [changed] Updated the header path to pod repo relative. (#3527)
- [fixed] Fixed singleton functionality after a FirebaseApp is deleted and recreated. (#3411)

# 2019-08-08 -- v4.1.2
- [fixed] Fixed hang when token is not available before topic subscription and unsubscription. (#3438)

# 2019-07-18 -- v4.1.1
- [fixed] Fixed Xcode 11 tvOS build issue - (#3216)

# 2019-06-18 -- v4.1.0
- [feature] Adding macOS support for Messaging. You can now send push notification to your mac app with Firebase Messaging.(#2880)

# 2019-06-04 -- v4.0.2
- [fixed] Disable data protection when opening the Rmq2PeristentStore. (#2963)

# 2019-05-21 -- v4.0.1
- [fixed] Fixed race condition checkin is deleted before writing during app start. This cleans up the corrupted checkin and fixes #2438. (#2860)
- [fixed] Separete APNS proxy methods in GULAppDelegateSwizzler so developers don't need to swizzle APNS related method unless explicitly requested, this fixes #2807. (#2835)
- [changed] Clean up code. Remove extra layer of class. (#2853)

# 2019-05-07 -- v4.0.0
- [removed] Remove deprecated `useMessagingDelegateForDirectChannel` property.(#2711) All direct channels (non-APNS) messages will be handled by `messaging:didReceiveMessage:`. Previously in iOS 9 and below, the direct channel messages are handled in `application:didReceiveRemoteNotification:fetchCompletionHandler:` and this behavior can be changed by setting `useMessagingDelegateForDirectChannel` to true. Now that all messages by default are handled in `messaging:didReceiveMessage:`. This boolean value is no longer needed. If you already have set useMessagingDelegateForDirectChannel to YES, or handle all your direct channel messages in `messaging:didReceiveMessage:`. This change should not affect you.
- [removed] Remove deprecated API to connect direct channel. (#2717) Should use `shouldEstablishDirectChannel` property instead.
- [changed] `GULAppDelegateSwizzler` is used for the app delegate swizzling. (#2683)

# 2019-04-02 -- v3.5.0
- [added] Add image support for notification. (#2644)

# 2019-03-19 -- v3.4.0
- [added] Adding community support for tvOS. (#2428)

# 2019-03-05 -- v3.3.2
- [fixed] Replaced `NSUserDefaults` with `GULUserDefaults` to avoid potential crashes. (#2443)

# 2019-02-20 -- v3.3.1
- [changed] Internal code cleanup.

# 2019-01-22 -- v3.3.0
- [changed] Use the new registerInternalLibrary API to register with FirebaseCore. (#2137)

# 2018-10-25 -- v3.2.1
- [fixed] Fixed an issue where messages failed to be delivered to the recipient's time zone. (#1946)

# 2018-10-09 -- v3.2.0
- [added] Now you can access the message ID of FIRMessagingRemoteMessage object. (#1861)
- [added] Add a new boolean value useFIRMessagingDelegateForDirectMessageDelivery if you
  want all your direct channel data messages to be delivered in
  FIRMessagingDelegate. If you don't use the new flag, for iOS 10 and above,
  direct channel data messages are delivered in
  `FIRMessagingDelegate messaging:didReceiveMessage:`; for iOS 9 and below,
  direct channel data messages are delivered in Apple's
  `AppDelegate application:didReceiveRemoteNotification:fetchCompletionHandler:`.
  So if you set the useFIRMessagingDelegateForDirectMessageDelivery to true,
  direct channel data messages are delivered in FIRMessagingDelegate across all
  iOS versions. (#1875)
- [fixed] Fix an issue that callback is not triggered when topic name is invalid. (#1880)

# 2018-08-28 -- v3.1.1
- [fixed] Ensure NSUserDefaults is persisted properly before app close. (#1646)
- [changed] Internal code cleanup. (#1666)

# 2018-07-31 -- v3.1.0
- [fixed] Added support for global Firebase data collection flag. (#1219)
- [fixed] Fixed an issue where Messaging wouldn't properly unswizzle swizzled delegate
  methods. (#1481)
- [fixed] Fixed an issue that Messaging doesn't compile inside app extension. (#1503)

# 2018-07-10 -- v3.0.3
- [fixed] Fixed an issue that client should suspend the topic requests when token is not available and resume the topic operation when the token is generated.
- [fixed] Corrected the deprecation warning when subscribing to or unsubscribing from an invalid topic. (#1397)
- [changed] Removed unused heart beat time stamp tracking.

# 2018-06-12 -- v3.0.2
- [added] Added a warning message when subscribing to topics with incorrect name formats.
- [fixed] Silenced a deprecation warning in FIRMessaging.

# 2018-05-29 -- v3.0.1
- [fixed] Clean up a few deprecation warnings.

# 2018-05-08 -- v3.0.0
- [removed] Remove deprecated delegate property `remoteMessageDelegate`, please use `delegate` instead.
- [removed] Remove deprecated method `messaging:didRefreshRegistrationToken:` defined in FIRMessagingDelegate protocol, please use `messaging:didReceiveRegistrationToken:` instead.
- [removed] Remove deprecated method `applicationReceivedRemoteMessage:` defined in FIRMessagingDelegate protocol, please use `messaging:didReceiveMessage:` instead.
- [fixed] Fix an issue that data messages were not tracked successfully.

# 2018-04-01 -- v2.2.0
- [added] Add new methods that provide completion handlers for topic subscription and unsubscription.

# 2018-02-23 -- v2.1.1
- [changed] Improve documentation on the usage of the autoInitEnabled property.

# 2018-02-06 -- v2.1.0
- [added] Added a new property autoInitEnabled to enable and disable FCM token auto generation.
- [fixed] Fixed an issue where notification delivery would fail after changing language settings.

# 2017-09-26 -- v2.0.5
- [added] Added swizzling of additional UNUserNotificationCenterDelegate method, for
  more accurate Analytics logging.
- [fixed] Fixed a swizzling issue with unimplemented UNUserNotificationCenterDelegate
  methods.

# 2017-09-26 -- v2.0.4
- [fixed] Fixed an issue where the FCM token was not associating correctly with an APNs
  device token, depending on when the APNs device token was made available.
- [fixed] Fixed an issue where FCM tokens for different Sender IDs were not associating
  correctly with an APNs device token.
- [fixed] Fixed an issue that was preventing the FCM direct channel from being
  established on the first start after 24 hours of being opened.
- [changed] Clarified a log message about method swizzling being enabled.

# 2017-09-13 -- v2.0.3
- [fixed] Moved to safer use of NSAsserts, instead of lower-level `__builtin_trap()`
  method.
- [added] Added logging of the underlying error code for an error trying to create or
  open an internal database file.

# 2017-08-25 -- v2.0.2
- [changed] Removed old logic which was saving the SDK version to NSUserDefaults.

# 2017-08-07 -- v2.0.1
- [fixed] Fixed an issue where setting `shouldEstablishDirectChannel` in a background
  thread was triggering the Main Thread Sanitizer in Xcode 9.
- [changed] Removed some old logic related to logging.
- [changed] Added some additional logging around errors while method swizzling.

# 2017-05-03 -- v2.0.0
- [feature] Introduced an improved interface for Swift 3 developers
- [added] Added new properties and methods to simplify FCM token management
- [added] Added property, APNSToken, to simplify APNs token management
- [added] Added new delegate method to be notified of FCM token refreshes
- [added] Added new property, shouldEstablishDirectChannel, to simplify connecting
  directly to FCM

# 2017-03-31 -- v1.2.3

- [fixed] Fixed an issue where custom UNNotificationCenterDelegates may not have been
  swizzled (if swizzling was enabled)
- [fixed] Fixed a issue iOS 8.0 and 8.1 devices using scheduled notifications
- [changed] Improvements to console logging

# 2017-01-31 -- v1.2.2

- [fixed] Improved topic subscription logic for more reliable subscriptions.
- [fixed] Reduced memory footprint and CPU usage when subscribing to multiple topics.
- [changed] Better documentation in the public headers.
- [changed] Switched from ProtocolBuffers2 to protobuf compiler.

# 2016-10-12 -- v1.2.1

- [changed] Better documentation on the public headers.

# 2016-09-02 -- v1.2.0

- [added] Support the UserNotifications framework introduced in iOS 10.
- [added] Add a new API, `-applicationReceivedRemoteMessage:`, to FIRMessaging. This
  allows apps to receive data messages from FCM on devices running iOS 10 and
  above.

# 2016-07-06 -- v1.1.1

- [changed] Move FIRMessaging related plists to ApplicationSupport directory.

# 2016-05-04 -- v1.1.0

- [changed] Change flag to disable swizzling to *FirebaseAppDelegateProxyEnabled*.
- [changed] `-[FIRMessaging appDidReceiveMessage:]` returns FIRMessagingMessageInfo object.
- [fixed] Minor bug fixes.

# 2016-01-25 -- v1.0.2

- [changed] Accept topic names without /topics prefix.
- [fixed] Add Swift annotations to public static accessors.

# 2016-01-25 -- v1.0.0

- [feature] New Firebase messaging API.
