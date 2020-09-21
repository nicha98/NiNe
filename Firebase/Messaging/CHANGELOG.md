# 2019-01-22 -- v3.3.0
- Use the new registerInternalLibrary API to register with FirebaseCore. (#2137)

# 2018-10-25 -- v3.2.1
- Fixed an issue where messages failed to be delivered to the recipient's time zone. (#1946)
- Internal code cleanup.

# 2018-10-09 -- v3.2.0
- Now you can access the message ID of FIRMessagingRemoteMessage object. (#1861)
- Add a new boolean value useFIRMessagingDelegateForDirectMessageDelivery if you
  want all your direct channel data messages to be delivered in
  FIRMessagingDelegate. If you don't use the new flag, for iOS 10 and above,
  direct channel data messages are delivered in
  `FIRMessagingDelegate messaging:didReceiveMessage:`; for iOS 9 and below,
  direct channel data messages are delivered in Apple's
  `AppDelegate application:didReceiveRemoteNotification:fetchCompletionHandler:`.
  So if you set the useFIRMessagingDelegateForDirectMessageDelivery to true,
  direct channel data messages are delivered in FIRMessagingDelegate across all
  iOS versions. (#1875)
- Fix an issue that callback is not triggered when topic name is invalid. (#1880)

# 2018-08-28 -- v3.1.1
- Ensure NSUserDefaults is persisted properly before app close. (#1646)
- Internal code cleanup. (#1666)

# 2018-07-31 -- v3.1.0
- Added support for global Firebase data collection flag. (#1219)
- Fixed an issue where Messaging wouldn't properly unswizzle swizzled delegate
  methods. (#1481)
- Fixed an issue that Messaging doesn't compile inside app extension. (#1503)

# 2018-07-10 -- v3.0.3
- Fixed an issue that client should suspend the topic requests when token is not available and resume the topic operation when the token is generated.
- Corrected the deprecation warning when subscribing to or unsubscribing from an invalid topic. (#1397)
- Removed unused heart beat time stamp tracking.

# 2018-06-12 -- v3.0.2
- Added a warning message when subscribing to topics with incorrect name formats.
- Silenced a deprecation warning in FIRMessaging.

# 2018-05-29 -- v3.0.1
- Clean up a few deprecation warnings.

# 2018-05-08 -- v3.0.0
- Remove deprecated delegate property `remoteMessageDelegate`, please use `delegate` instead.
- Remove deprecated method `messaging:didRefreshRegistrationToken:` defined in FIRMessagingDelegate protocol, please use `messaging:didReceiveRegistrationToken:` instead.
- Remove deprecated method `applicationReceivedRemoteMessage:` defined in FIRMessagingDelegate protocol, please use `messaging:didReceiveMessage:` instead.
- Fix an issue that data messages were not tracked successfully.

# 2018-04-01 -- v2.2.0
- Add new methods that provide completion handlers for topic subscription and unsubscription.

# 2018-02-23 -- v2.1.1
- Improve documentation on the usage of the autoInitEnabled property.

# 2018-02-06 -- v2.1.0
- Added a new property autoInitEnabled to enable and disable FCM token auto generation.
- Fixed an issue where notification delivery would fail after changing language settings.

# 2017-09-26 -- v2.0.5
- Added swizzling of additional UNUserNotificationCenterDelegate method, for
  more accurate Analytics logging.
- Fixed a swizzling issue with unimplemented UNUserNotificationCenterDelegate
  methods.

# 2017-09-26 -- v2.0.4
- Fixed an issue where the FCM token was not associating correctly with an APNs
  device token, depending on when the APNs device token was made available.
- Fixed an issue where FCM tokens for different Sender IDs were not associating
  correctly with an APNs device token.
- Fixed an issue that was preventing the FCM direct channel from being
  established on the first start after 24 hours of being opened.
- Clarified a log message about method swizzling being enabled.

# 2017-09-13 -- v2.0.3
- Moved to safer use of NSAsserts, instead of lower-level `__builtin_trap()`
  method.
- Added logging of the underlying error code for an error trying to create or
  open an internal database file.

# 2017-08-25 -- v2.0.2
- Removed old logic which was saving the SDK version to NSUserDefaults.

# 2017-08-07 -- v2.0.1
- Fixed an issue where setting `shouldEstablishDirectChannel` in a background
  thread was triggering the Main Thread Sanitizer in Xcode 9.
- Removed some old logic related to logging.
- Added some additional logging around errors while method swizzling.

# 2017-05-03 -- v2.0.0
- Introduced an improved interface for Swift 3 developers
- Added new properties and methods to simplify FCM token management
- Added property, APNSToken, to simplify APNs token management
- Added new delegate method to be notified of FCM token refreshes
- Added new property, shouldEstablishDirectChannel, to simplify connecting
  directly to FCM

# 2017-03-31 -- v1.2.3

- Fixed an issue where custom UNNotificationCenterDelegates may not have been
  swizzled (if swizzling was enabled)
- Fixed a issue iOS 8.0 and 8.1 devices using scheduled notifications
- Improvements to console logging

# 2017-01-31 -- v1.2.2

- Improved topic subscription logic for more reliable subscriptions.
- Reduced memory footprint and CPU usage when subscribing to multiple topics.
- Better documentation in the public headers.
- Switched from ProtocolBuffers2 to protobuf compiler.

# 2016-10-12 -- v1.2.1

- Better documentation on the public headers.

# 2016-09-02 -- v1.2.0

- Support the UserNotifications framework introduced in iOS 10.
- Add a new API, -applicationReceivedRemoteMessage:, to FIRMessaging. This
  allows apps to receive data messages from FCM on devices running iOS 10 and
  above.

# 2016-07-06 -- v1.1.1

- Move FIRMessaging related plists to ApplicationSupport directory.

# 2016-05-04 -- v1.1.0

- Change flag to disable swizzling to *FirebaseAppDelegateProxyEnabled*.
- '[FIRMessaging appDidReceiveMessage:] returns FIRMessagingMessageInfo object.
- Minor bug fixes.

# 2016-01-25 -- v1.0.2

- Accept topic names without /topics prefix.
- Add Swift annotations to public static accessors.

# 2016-01-25 -- v1.0.0

- New Firebase messaging API.
