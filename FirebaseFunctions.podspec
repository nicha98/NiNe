Pod::Spec.new do |s|
  s.name             = 'FirebaseFunctions'
  s.version          = '2.3.0'
  s.summary          = 'Cloud Functions for Firebase iOS SDK.'

  s.description      = <<-DESC
iOS SDK for Cloud Functions for Firebase.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Functions-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'Functions/FirebaseFunctions/**/*'
  s.public_header_files = 'Functions/FirebaseFunctions/Public/*.h'

  s.dependency 'FirebaseAuthInterop', '~> 1.0'
  s.dependency 'FirebaseCore', '~> 5.2'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'FIRFunctions_VERSION=' + s.version.to_s
  }
end
