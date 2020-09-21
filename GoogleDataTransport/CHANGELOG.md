# v3.0.1
- Fixes sanitizer issues and runtime errors. (#4039, #4027)

# v3.0.0
- Changes backgrounding logic to reduce background usage and properly complete
all tasks. (#3893)
- Fix Catalyst define checks. (#3695)
- Fix ubsan issues in GDT (#3910)
- Add support for FLL. (#3867)

# v2.0.0
- Change/rename all classes and references from GDT to GDTCOR. (#3729)

# v1.2.0
- Removes all NSAsserts in favor of custom asserts. (#3747)

# v1.1.3
- Wrap decoding in GDTCORUploadCoordinator in a try catch. (#3676)

# v1.1.2
- Add initial support for iOS 13.
- Add initial support for Catalyst.
- Backgrounding in GDTCORStorage is fixed. (#3623 and #3625)

# v1.1.1
- Fixes a crash in GDTCORUploadPackage and GDTCORStorage. (#3547)

# v1.1.0
- Remove almost all NSAsserts and NSCAsserts for a better development
experience. (#3530)

# v1.0.0
- Initial Release--for Google-use only. This library is the foundation of a
network transport layer that focuses on transparently and respectfully
transporting data that is collected for purposes that vary depending on the
adopting SDK. Primarily, we seek to reduce Firebase's impact on binary size,
mobile data consumption, and battery use for end users by aggregating collected
data and transporting it under ideal conditions. Users should expect to see an
increase in the number of Cocoapods/frameworks/libraries, but a decrease in
binary size over time as our codebase becomes more modularized.
