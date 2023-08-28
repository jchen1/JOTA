# Uncomment the next line to define a global platform for your project
# platform :ios, '10.0'

DEPLOYMENT_TARGET_IOS = '10.0'
DEPLOYMENT_TARGET_MACOS = '11.3'

target 'OTPAutoFill' do
  platform :ios, '10.0'

  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for OTPAutoFill
  pod 'KeychainAccess'
  pod 'SwiftOTP'
end

target 'JOTA' do
  platform :ios, '10.0'

  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for JOTA
  pod 'KeychainAccess'
  pod 'SwiftOTP'
  pod 'Toaster'

  target 'JOTATests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'JOTAUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end

target 'JOTA-macOS' do
  platform :osx, '12.0'
    # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for JOTA-macOS
  pod 'KeychainAccess'
  pod 'SwiftOTP'
  pod 'Introspect'
end

post_install do |installer|
    # Fix deployment target for pods that don't specify one
    # or specify one that is older than our own deployment target.
    desired_ios = Gem::Version.new(DEPLOYMENT_TARGET_IOS)
    desired_macos = Gem::Version.new(DEPLOYMENT_TARGET_MACOS)

    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            settings = config.build_settings

            actual = Gem::Version.new(settings['IPHONEOS_DEPLOYMENT_TARGET'])
            if actual < desired_ios
                settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET_IOS
            end

            actual = Gem::Version.new(settings['MACOSX_DEPLOYMENT_TARGET'])
            if actual < desired_macos
                settings['MACOSX_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET_MACOS
            end
        end
    end
end
