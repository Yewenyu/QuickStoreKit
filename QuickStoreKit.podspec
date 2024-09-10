Pod::Spec.new do |s|
  s.name             = 'QuickStoreKit'
  s.version          = '0.0.2'
  s.summary          = 'A Swift-based storage management framework for iOS.'
  s.description      = <<-DESC
                        QuickStoreKit is a powerful storage management framework designed to make data handling easier and more secure in iOS applications. It supports encryption, caching, and custom storage solutions.
                      DESC
  s.homepage         = 'https://github.com/yourusername/QuickStoreKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ye' => '****' }
  s.source           = { :git => 'https://github.com/Yewenyu/QuickStoreKit.git', :tag => "#{s.version}" }
  s.ios.deployment_target = '11.0'
  s.source_files     = 'QuickStoreKit/**/*.{swift,h}'
  s.swift_version    = '5.0'
  
  # 如果你的框架依赖于其他第三方库，可以在这里添加依赖
  # s.dependency 'AnotherPod', '~> 1.0'
  
end

# pod trunk register your_email@example.com 'Your Name'
# pod trunk push QuickStoreKit.podspec
