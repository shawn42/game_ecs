
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "game_ecs/version"

Gem::Specification.new do |spec|
  spec.name          = "game_ecs"
  spec.version       = GameEcs::VERSION
  spec.authors       = ["Shawn Anderson"]
  spec.email         = ["shawn42@gmail.com"]

  spec.summary       = %q{Entity Component System architecture in Ruby}
  spec.description   = %q{Entity Component System architecture in Ruby}
  spec.homepage      = "https://github.com/shawn42/game_ecs"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry", "~> 0.12.0"
end
