require_relative "lib/zed/rails/jumper/version"

Gem::Specification.new do |spec|
  spec.name        = "zed-rails-jumper"
  spec.version     = Zed::Rails::Jumper::VERSION
  spec.authors     = [ "Tonksthebear" ]
  spec.homepage    = "https://github.com/tonksthebear/zed-rails-jumper"
  spec.summary     = "A CLI gem for the Zed editor that helps developers quickly jump to Rails views associated with the current controller method."
  spec.description = "A CLI gem for the Zed editor that helps developers quickly jump to Rails views associated with the current controller method."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/tonksthebear/zed-rails-jumper"
  spec.metadata["changelog_uri"] = "https://github.com/tonksthebear/zed-rails-jumper/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib,exe}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0.0"
  spec.add_dependency "thor", "~> 1.0"

  spec.executables = [ "zed-rails-jumper" ]
  spec.bindir = "exe"
end
