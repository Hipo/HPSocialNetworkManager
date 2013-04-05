Pod::Spec.new do |s|
  s.name         = "HPSocialNetworkManager"
  s.version      = "0.1.0"
  s.summary      = "iOS framework for authenticating with Facebook and Twitter, with reverse-auth support."
  s.homepage     = "https://github.com/Hipo/HPSocialNetworkManager"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.authors      = { "Taylan Pince" => "taylan@hipo.biz", "Sarp Erdag" => "sarp.erdag@gmail.com" }
  s.source       = { :git => "https://github.com/Hipo/HPSocialNetworkManager.git", :tag => "0.1.0" }
  s.platform     = :ios
  s.source_files = 'Classes/**/*.{h,m}', 'Dependencies/**/*.{h,m}', 'Dependencies/FacebookSDK.framework/Headers/*.h'
end
