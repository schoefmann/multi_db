# coding: utf-8
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{multi_db}
  s.version = "1.0.0"

  s.authors = ["Maximilian Sch\303\266fmann", "Jacopo Beschi"]
  s.date = %q{2012-03-29}
  s.homepage = "http://github.com/iubenda/multi_db"
  s.summary = "Connection proxy for ActiveRecord for single master / multiple slave database deployments"
  s.description = "Connection proxy for ActiveRecord for single master / multiple slave database deployments"
  s.email = "jacopo.beschi@iubenda.com"
  s.extra_rdoc_files = ["LICENSE", "README.rdoc"]
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "multi_db", "--main", "README.rdoc"]

  s.require_paths = ["lib"]
  s.files = ["lib/multi_db.rb", "lib/multi_db/active_record_extensions.rb", "lib/multi_db/connection_proxy.rb", "lib/multi_db/observer_extensions.rb", "lib/multi_db/query_cache_compat.rb", "lib/multi_db/scheduler.rb", "LICENSE", "README.rdoc", "spec/config/database.yml", "spec/connection_proxy_spec.rb", "spec/scheduler_spec.rb", "spec/spec_helper.rb", "multi_db.gemspec"]

  s.required_ruby_version = Gem::Requirement.new("~> 2.4")

  s.add_dependency('activerecord', ["~> 4.0"])
  s.add_dependency('rails-observers', ["0.1.5"])

  s.add_dependency('tlattr_accessors', [">= 0.0.3"])

  s.add_development_dependency('mysql2', '0.3.21')
  s.add_development_dependency('rspec', '~> 2.14')
end
