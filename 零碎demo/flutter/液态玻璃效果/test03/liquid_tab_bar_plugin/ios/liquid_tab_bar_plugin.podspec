#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint liquid_tab_bar_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'liquid_tab_bar_plugin'
  s.version          = '0.2.0'
  s.summary          = 'An adaptive Flutter tab bar with an iOS Liquid Glass renderer.'
  s.description      = <<-DESC
An adaptive Flutter tab bar with an iOS Liquid Glass renderer.
                       DESC
  # 发布前替换为真实项目主页和作者信息。
  s.homepage         = 'https://example.invalid/liquid_tab_bar_plugin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'liquid_tab_bar_plugin/Sources/liquid_tab_bar_plugin/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'liquid_tab_bar_plugin_privacy' => ['liquid_tab_bar_plugin/Sources/liquid_tab_bar_plugin/PrivacyInfo.xcprivacy']}
end
