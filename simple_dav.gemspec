Gem::Specification.new do |s|
  s.name        = 'simple_dav'
  s.version     = '0.0.4'
  s.date        = '2012-10-05'
  s.summary     = "Ruby dav client"
  s.description = "Access your sogo dav server from ruby to sync contacts, events and tasks"
  s.authors     = ["Olivier DIRRENBERGER"]
  s.email       = 'od@idfuze.com'
  s.files       = ["lib/simple_dav.rb"]
  s.homepage    = 'https://github.com/reivilo/simple_dav'
  
  s.add_dependency('httpclient', '>= 2.2.1')
  s.add_dependency('nokogiri', '>= 1.5.0')
end