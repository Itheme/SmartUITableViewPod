Pod::Spec.new do |spec|
  spec.name         = 'SmartUITableView'
  spec.version      = '0.2.0'
  spec.license      = { :type => 'BSD' }
  spec.homepage     = 'https://github.com/Itheme/SmartUITableViewPod'
  spec.authors      = { 'Danila Parkhomenko' => 'thereaintnomailformeagain@gmail.com' }
  spec.summary      = 'UITableView that doesn't crash on wrong updates (iOS)'
  spec.source       = { :git => 'https://github.com/Itheme/SmartUITableViewPod.git', :tag => 'v0.2.0' }
  spec.source_files = 'SmartUITableView.{h,m}'
  spec.framework    = 'UIKit'
end
