# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'business_date_calculator/version'

Gem::Specification.new do |spec|
  spec.name          = "business_date_calculator"
  spec.version       = BusinessDateCalculator::VERSION
  spec.authors       = ["Lucas Pérez"]
  spec.email         = ["lucascperez@gmail.com"]

  spec.summary       = %q{A Ruby Library for dealing with business calendar.}
  spec.description   = %q{A Ruby Library for dealing with business calendar.}
  spec.homepage      = "https://github.com/investtools/business_date_calculator"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "bundler-audit", "~> 0.9"
  spec.add_development_dependency "rake", ">= 12.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_dependency "activesupport"
end
