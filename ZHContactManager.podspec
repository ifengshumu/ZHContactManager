#
#  Be sure to run `pod spec lint ZHContactManager.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "ZHContactManager"
  s.version      = "1.1.0"
  s.summary      = "通讯录操作"
  s.description  = "通讯录操作：选择联系人、添加新联系人、添加到现有联系人；打电话、发短信、发邮件"

  s.homepage     = "https://github.com/leezhihua/ZHContactManager"

  s.license      = { :type => "MIT", :file => "LICENSE" }


  s.author             = { "leezhihua" => "leezhihua@yeah.net" }

  s.ios.deployment_target = "8.0"

  s.source       = { :git => "https://github.com/leezhihua/ZHContactManager.git", :tag => "#{s.version}" }


  s.source_files = "Pod/Classes/*.{h,m}"


  s.frameworks   = "Contacts", "ContactsUI", "AddressBook", "AddressBookUI", "MessageUI"


  s.requires_arc = true



end
