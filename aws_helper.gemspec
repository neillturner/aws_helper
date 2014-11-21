# encoding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'awshelper/version'

Gem::Specification.new do |s|
  s.name          = 'aws_helper'
  s.version       = Awshelper::VERSION
  s.authors       = ['Neill Turner']
  s.email         = ['neillwturner@gmail.com']
  s.homepage      = 'https://github.com/neillturner/aws_helper'
  s.summary       = 'Aws Helper for an instance'
  candidates = Dir.glob('{lib}/**/*') +  ['README.md', 'aws_helper.gemspec']
  candidates = candidates +  Dir.glob("bin/*")
  s.files = candidates.sort
  s.platform      = Gem::Platform::RUBY
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = ['lib']
  s.add_dependency('right_aws')
  s.add_dependency('thor')  
  s.rubyforge_project = '[none]'
  s.description = <<-EOF
== DESCRIPTION:

Aws Helper for an instance 

== FEATURES:

Allows functions on EBS volumes, snapshots, IP addresses and more 

EOF

end
