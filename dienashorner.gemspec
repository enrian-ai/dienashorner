# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = 'therubyrhino becomes dienashorner'.split.last
  gem.authors       = ['Karol Bucek']
  gem.email         = ['self@kares.org']
  gem.licenses      = ['Apache-2.0']

  path = File.expand_path("lib/nashorn/version.rb", File.dirname(__FILE__))
  gem.version       = File.read(path).match( /.*VERSION\s*=\s*['"](.*)['"]/m )[1]

  gem.summary       = %q{The Nashorn JavaScript interpreter for JRuby}
  gem.description   = %q{Nashorn, a Rhino's sucessor, allows embeded JavaScript interaction from within Ruby.}
  gem.homepage      = "https://github.com/kares/dienashorner"

  gem.require_paths = ["lib"]
  gem.files         = `git ls-files`.split("\n").sort
  gem.test_files    = `git ls-files -- {spec}/*`.split("\n")

  gem.extra_rdoc_files = %w[ README.md LICENSE ]

  gem.add_development_dependency "rspec", "~> 2.14.1"
  gem.add_development_dependency "mocha", "~> 0.13.3"
end
