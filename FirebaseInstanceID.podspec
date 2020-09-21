Pod::Spec.new do |s|
  s.name             = 'FirebaseInstanceID'
  s.version          = '3.7.0'
  s.summary          = 'Firebase InstanceID for iOS'

  s.description      = <<-DESC
Instance ID provides a unique ID per instance of your iOS apps. In addition to providing
unique IDs for authentication,Instance ID can generate security tokens for use with other
services.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'InstanceID-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "Firebase/InstanceID/"
  s.source_files = base_dir + '**/*.[mh]'
  s.requires_arc = base_dir + '*.m'
  s.public_header_files = base_dir + 'Public/*.h'
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'FIRInstanceID_LIB_VERSION=' + String(s.version)
  }
  s.framework = 'Security'
  s.dependency 'FirebaseCore', '~> 5.2'
  s.dependency 'GoogleUtilities/UserDefaults', '~> 5.2'
  s.dependency 'GoogleUtilities/Environment', '~> 5.2'
end
