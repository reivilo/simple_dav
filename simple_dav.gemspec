Gem::Specification.new do |s|
  s.name        = 'simple_dav'
  s.version     = '0.0.6'
  s.date        = '2012-10-15'
  s.platform    = Gem::Platform::RUBY
  s.summary     = "Ruby dav client"
  s.description = "Access your sogo dav server from ruby to sync contacts, events and tasks"
  s.authors     = ["Olivier DIRRENBERGER"]
  s.email       = 'od@idfuze.com'
  s.files       = Dir.glob('lib/**/*') + ['README', 'TODO']
  s.require_path= 'lib'
  s.homepage    = 'https://github.com/reivilo/simple_dav'
  
  s.add_dependency('httpclient', '>= 2.2.1')
  s.add_dependency('nokogiri', '>= 1.5.0')
end