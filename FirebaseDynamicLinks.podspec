Pod::Spec.new do |s|
  s.name             = 'FirebaseDynamicLinks'
  s.version          = '3.4.1'
  s.summary          = 'Firebase DynamicLinks for iOS'

  s.description      = <<-DESC
Firebase Dynamic Links are deep links that enhance user experience and increase engagement by retaining context post-install, across platforms.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'DynamicLinks-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'Firebase/DynamicLinks/**/*.[mh]'
  s.public_header_files = 'Firebase/DynamicLinks/Public/*.h'
  s.frameworks = 'AssetsLibrary', 'MessageUI', 'QuartzCore'
  s.weak_framework = 'WebKit'
  s.dependency 'FirebaseCore', '~> 5.2'
  s.ios.dependency 'FirebaseAnalytics', '~> 5.1'
  s.dependency 'FirebaseAnalyticsInterop', '~> 1.0'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'FIRDynamicLinks_VERSION=' + s.version.to_s +
                                      ' FIRDynamicLinks3P GIN_SCION_LOGGING',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"/Firebase'
  }
end
