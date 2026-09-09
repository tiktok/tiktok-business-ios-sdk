#!/usr/bin/env ruby
# Requires the xcodeproj gem (also installed by CocoaPods). Creates an isolated
# native regression harness without changing the upstream project's test targets.
require 'xcodeproj'
require 'fileutils'

source = File.expand_path('..', __dir__)
destination = File.expand_path(ARGV.fetch(0))
abort 'Destination must be a new directory outside the repository' if File.exist?(destination) || destination.start_with?(source + '/')
FileUtils.mkdir_p(destination)
%w[TikTokBusinessSDK TikTokBusinessSDKTests TikTokBusinessSDKTestApp PrivacyInfo.xcprivacy TikTokBusinessSDK.podspec].each do |item|
  FileUtils.ln_s(File.join(source, item), File.join(destination, item))
end
FileUtils.cp_r(File.join(source, 'TikTokBusinessSDK.xcodeproj'), destination)
project_path = File.join(destination, 'TikTokBusinessSDK.xcodeproj')
project = Xcodeproj::Project.open(project_path)
tests = project.targets.find { |target| target.name == 'TikTokBusinessSDKTests' }
host = project.targets.find { |target| target.name == 'TikTokBusinessSDKTestApp' }

# Upstream tests include obsolete selectors/OCMock. Compile only these regression
# tests, with Swift runtime linkage needed by the real StoreKit implementation.
tests.source_build_phase.files.to_a.each do |file|
  file.remove_from_project unless file.file_ref.path == 'TikTokConsentTests.m'
end
File.write(File.join(destination, 'SwiftRuntime.swift'), "import Foundation\n")
tests.source_build_phase.add_file_reference(project.main_group.new_file('SwiftRuntime.swift'))
tests.build_configurations.each do |config|
  config.build_settings.delete('SWIFT_OBJC_BRIDGING_HEADER')
  config.build_settings['OTHER_LDFLAGS'] = ['$(inherited)', '-lc++', '-ObjC']
  config.build_settings['SWIFT_VERSION'] = '5.0'
end

# Do not statically link another SDK copy into the host: duplicate ObjC classes
# break secure event decoding. The host must not prompt for ATT or use live IDs.
host.source_build_phase.files.to_a.each(&:remove_from_project)
host.frameworks_build_phase.files.to_a.each do |file|
  file.remove_from_project if file.file_ref.path.include?('TikTokBusinessSDK')
end
File.write(File.join(destination, 'ConsentTestHost.swift'), <<~SWIFT)
  import UIKit
  @main final class ConsentTestHost: UIResponder, UIApplicationDelegate {
      var window: UIWindow?
      func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
          window = UIWindow(frame: UIScreen.main.bounds)
          window?.rootViewController = UIViewController()
          window?.makeKeyAndVisible()
          return true
      }
  }
SWIFT
host.source_build_phase.add_file_reference(project.main_group.new_file('ConsentTestHost.swift'))
(project.build_configurations + project.targets.flat_map(&:build_configurations)).each do |config|
  # Upstream's recursive repository search can pick up stale module maps/builds.
  config.build_settings['HEADER_SEARCH_PATHS'] = ['$(inherited)', '$(SRCROOT)/TikTokBusinessSDK/Core/**']
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(host)
scheme.add_test_target(tests)
scheme.save_as(project_path, 'ConsentRegression', true)
puts project_path
