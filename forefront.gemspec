require_relative "lib/forefront/version"

Gem::Specification.new do |spec|
  spec.name        = "forefront"
  spec.version     = Forefront::VERSION
  spec.authors     = [ "Sumit Sharma" ]
  spec.email       = [ "sumit@gemsessence.com" ]
  spec.homepage    = "https://github.com/GemsEssence/forefront"
  spec.summary     = "Ticket + Lead tracking engine for Rails apps"
  spec.description = "Mountable Rails engine providing ticket & lead tracking with activities, followups, reminders, and file attachments."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/GemsEssence/forefront"
  spec.metadata["changelog_uri"] = "https://github.com/GemsEssence/forefront/change_log.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ['>= 6.0', '< 9']
  spec.add_dependency "sqlite3"
  spec.add_dependency "devise", "~> 4.9"
  spec.add_dependency "kaminari", "~> 1.2"
  spec.add_dependency "pundit", "~> 2.3"
end
