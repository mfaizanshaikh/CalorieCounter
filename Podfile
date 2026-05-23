platform :ios, '17.0'

target 'CalorieCounter' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for CalorieCounter
  pod 'Firebase/Analytics'

  # Google Sign-In (Apple Sign-In uses Apple's built-in AuthenticationServices framework — no pod required).
  pod 'GoogleSignIn', '~> 7.1'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end
