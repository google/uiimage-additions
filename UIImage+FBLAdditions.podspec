Pod::Spec.new do |s|
  s.name        = 'UIImage+FBLAdditions'
  s.version     = '1.0.0'
  s.authors     = 'Google Inc.'
  s.license     = { :type => 'Apache', :file => 'LICENSE' }
  s.homepage    = 'https://github.com/google/uiimage-additions'
  s.source      = { :git => 'https://github.com/google/uiimage-additions.git', :tag => s.version }
  s.summary     = 'UIImage Additions'
  s.description = <<-DESC

  A collection of miscellaneous utilities for `UIImage` that provide various
  image transformations with minimal memory footprint.
                     DESC

  s.ios.deployment_target  = '9.0'
  s.prefix_header_file = false
  s.public_header_files = "Sources/#{s.name}/include/**/*.h"
  s.source_files = "Sources/#{s.name}/**/*.{h,m}"
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => "\"${PODS_TARGET_SRCROOT}/Sources/#{s.name}/include\""
  }

  s.test_spec 'Tests' do |ts|
    ts.source_files = "Tests/#{s.name}Tests/*.m",
                      "Sources/#{s.name}TestHelpers/include/#{s.name}TestHelpers.h",
                      "Sources/#{s.name}TestHelpers/#{s.name}TestHelpers.m"
  end
end
