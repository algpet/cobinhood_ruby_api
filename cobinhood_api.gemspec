
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
    spec.name          = "cobinhood_api"
    spec.version       = "0.0.1"
    spec.authors       = ["Algis"]
    spec.email         = ["litovec@gmail.com"]

    spec.summary       = "Cobinhood REST API"
    spec.description   = "Simple wrapper over Cobinhood REST API"
    spec.homepage      = "https://github.com/algpet/cobinhood_ruby_api"
    spec.license       = "MIT"
    
    spec.files         = `git ls-files -z`.split("\x0").reject do |f|
        f.match(%r{^(test|spec|features)/})
    end
    spec.bindir        = "exe"
    spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
    spec.require_paths = ["lib"]

    spec.add_development_dependency "bundler", "~> 1.16"
    spec.add_development_dependency "rake", "~> 10.0"
    spec.add_development_dependency "minitest", "~> 5.0"
end
