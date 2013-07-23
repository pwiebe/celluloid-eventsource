# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'celluloid-eventsource/version'

Gem::Specification.new do |gem|
  gem.name          = "celluloid-eventsource"
  gem.version       = Celluloid::EventSource::VERSION
  gem.authors       = ["Philip Wiebe"]
  gem.email         = ["pwiebe_99@yahoo.com"]
  gem.description   = <<-DOC
  celluloid-eventsource is a celluloid-based library to consume Server-Sent Events streaming API.
  You can find the specification here: http://dev.w3.org/html5/eventsource/
  DOC

  gem.summary       = %q{Celluloid-based SSE Client}
  gem.homepage      = "http://github.com/pwiebe/celluloid-eventsource"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'celluloid'
  gem.add_dependency 'celluloid-io'
end
