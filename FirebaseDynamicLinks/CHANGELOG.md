# Unversioned
- [fixed] Reduce frequency of iOS14 pasteboard notifications by only reading from it when it contains URL(s). (#5905)

# v4.3.0
- [changed] Functionally neutral updated import references for dependencies. (#5824)

# v4.1.0
- [fixed] Fixing unwanted pending dynamic links checks on subsequent app restarts. (#5665)

# v4.0.8 -- M67
- [fixed] Fix Catalyst build - removed deprecated unused Apple framework dependencies. (#5139)

# v4.0.7 -- M64
- [fixed] Use module import syntax for headers from other SDKs. (#4824)

# v4.0.6
- [fixed] Fix component startup time. (#4137)
- [fixed] Fix crash due to object deallocation on app launch. (#4308)

# v4.0.5
- [fixed] Removed references to UIWebViewDelegate to comply with App Store Submission warning. (#3722)

# v4.0.4
- [fixed] Removed references to UIWebView to comply with App Store Submission warning. (#3722)

# v4.0.3
- [added] Added support for custom domains for internal Google apps. (#3540)

# v4.0.2
- [changed] Updated to maintain compatibility with Firebase Core in 6.6.0.

# v4.0.1
- [changed] Removed deprecated internal log method. (#3333)

# v4.0
- [feature] FirebaseAnalytics is no longer a hard dependency in the DynamicLinks pod. If you were installing Dynamic Links via pod ''Firebase/DynamicLinks'', you should add 'pod 'Firebase/Analytics'' to the Podfile to maintain full Dynamic Links functionality. If you previously have 'pod 'Firebase/Core'' in the Podfile, no change is necessary. (#2738)
- [removed] Remove deprecated API in FDLURLComponents. (#2768)

# v3.4.3
- [fixed] Fixed an issue where matchesshortlinkformat was returning true for certain FDL long links.

# v3.4.2
- [fixed] Fixes an issue with certain analytics attribution parameters not being recorded on an app install. (#2462)

# v3.4.1
- [changed] Return call validation for sysctlbyname. (#2394)

# v3.4.0
- [changed] Bug fixes and internal SDK changes. (#2238, #2220)

# v3.3.0
- [added] Introduced a new `componentsWithLink:domainURIPrefix:` and deprecated the existing `componentsWithLink:domain:`. (#1962, #2017, #2078, #2097, #2112)

# v3.2.0
- [changed] Delete deprecated source files. (#2038)

# v3.1.1
- [changed] Use c99 compatible __typeof__() operator. (#1982)

# v3.1.0
- [feature] Firebase Dynamic Links is now open source and delivered as a source pod. (#1842)

# v3.0.2
- [changed] Bug fixes.

# v3.0.1
- [fixed] Fixed issue where first app opens were getting double counted when using unique match.

# v2.3.2
- [fixed] Fixed error when fingerprint match fails for some locales.

# v2.3.1
- [fixed] Fixed race condition while processing server response(s).

# v2.3.0
- [added] Added new confidence type property. See FIRDLMatchType (values Unique, Default, Weak);
- [changed] Updates to self diagnostic output.

# v2.2.0
- [added] Added Other platform fallback link to FDL Builder API;

# v2.1.0
- [added] Added basic self diagnostic to identify Firebase Dynamic Links configuration issues. See method
  [FIRDynamicLinks performDiagnosticsWithCompletion:].
- [fixed] Fixed returning warning in Builder API, see warnings parameter in
  FIRDynamicLinkShortenerCompletion block.

# v2.0.0
- [fixed] Change Swift API names to better align with Swift convention.
- [fixed] Fixes to pending link retrieval process, especially when custom URL schemes are not
  set up properly.

# v1.4.0
- [added] Added Builder API to create and shorten dynamic links in iOS Apps.

# v1.3.5
- [changed] Minor update triggered by changes in Firebase Core libraries.

# v1.3.4
- [changed] Bug fixes

# v1.3.3
- [changed] Improved tracking of social media tag parameters in Dynamic Links

# v1.3.2
- [changed] Removes dependency on the Core Motion framework

# v1.3.1
- [added] Adds FIRLogger support (not public-facing)
- [fixed] Fixes IPv6 compatibilty issues

# v1.3.0
- [changed] Removes the SFSafariViewController per Apple's Review Guidelines
- [changed] Removes dependency on the Core Location framework

# v1.2.0
- [added] iOS 10 Supoort

# v1.1.1
- [fixed] Fixes an issue where if resolveLink() API returned a non-JSON object, it
  would cause a crash.

# v1.1.0 (M10)
- [fixed] Greatly reduced SDK size.

# v1.0.0 (I/O)
- Initial public release.
