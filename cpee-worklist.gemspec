Gem::Specification.new do |s|
  s.name             = "cpee-worklist"
  s.version          = "1.0.11"
  s.platform         = Gem::Platform::RUBY
  s.license          = "LGPL-3.0-or-later"
  s.summary          = "Worklist for the cloud process execution engine (cpee.org)"

  s.description      = "see http://cpee.org"

  s.files            = Dir['{server/worklist,server/worklist.conf,lib/**/*,ui/**/*,tools/**/*}'] + %w(LICENSE Rakefile cpee-worklist.gemspec README.md AUTHORS)
  s.require_path     = 'lib'
  s.extra_rdoc_files = ['README.md']
  s.bindir           = 'tools'
  s.executables      = ['cpee-worklist']

  s.required_ruby_version = '>=2.4.0'

  s.authors          = ['Juergen eTM Mangler','Florian Stertz', 'Patrik Koenig']

  s.email            = 'juergen.mangler@gmail.com'
  s.homepage         = 'http://cpee.org/'

  s.add_runtime_dependency 'riddl', '~> 1.0'
  s.add_runtime_dependency 'json', '~> 2.1'
  s.add_runtime_dependency 'cpee', '~> 2.1', '>= 2.1.56'
  s.add_runtime_dependency 'chronic_duration', '~> 0.10', '>= 0.10.6'
end
