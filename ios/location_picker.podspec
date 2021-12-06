#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint location_picker.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'location_picker'
  s.version          = '0.0.1'
  s.summary          = 'Location Picker Plugin from Google Maps based on google_maps_flutter.'
  s.description      = <<-DESC
  Location Picker Plugin from Google Maps based on google_maps_flutter.
                       DESC
  s.homepage         = 'https://github.com/tehsunnliu/location_picker'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Sunns Technologies' => 'tehsunnliu@sunnstech.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '8.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
