require_relative 'lib/neorack/version'

Gem::Specification.new do |spec|
  spec.name          = "neorack"
  spec.version       = NeoRack::VERSION
  spec.authors       = ["Bo"]
  spec.email         = ["bo@facil.io"]

  spec.summary       = %q{Common helpers and external extensions for NeoRack.}
  spec.description   = %q{This gem is optional. NeoRack is a specification, not a gem... but to save developers time in (re)writing the DSL builder and other common tasks, this gem is provided.}
  spec.homepage      = "https://github.com/boazsegev/neorack"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/boazsegev/neorack"
  spec.metadata["changelog_uri"] = "https://github.com/boazsegev/neorack/gem/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
