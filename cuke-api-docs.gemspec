# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cuke-api-docs/version'

Gem::Specification.new do |spec|
  spec.name          = "cuke-api-docs"
  spec.version       = CukeApiDocs::VERSION
  spec.authors       = ["Bruz Marzolf"]
  spec.email         = ["bruz@bruzilla.com"]
  spec.summary       = %q{Cucumber formatter that produces HTML API documentation}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "arbre", "~> 1.0"
  spec.add_dependency "cucumber", "~> 1.3"
  spec.add_dependency "json", "~> 1.8"
  spec.add_dependency "deep_merge", "~> 1.0"
  spec.add_dependency "virtus", "~> 1.0"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
