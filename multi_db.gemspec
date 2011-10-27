# coding: utf-8
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{multi_db}
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Maximilian Sch\303\266fmann"]
  s.date = %q{2011-05-17}
  s.description = "Connection proxy for ActiveRecord for single master / multiple slave database deployments"
  s.email = "max@pragmatic-it.de"
  s.extra_rdoc_files = ["LICENSE", "README.rdoc"]
  s.files = ["lib/multi_db.rb", "lib/multi_db/active_record_extensions.rb", "lib/multi_db/connection_proxy.rb", "lib/multi_db/observer_extensions.rb", "lib/multi_db/query_cache_compat.rb", "lib/multi_db/scheduler.rb", "LICENSE", "README.rdoc", "spec/config/database.yml", "spec/connection_proxy_spec.rb", "spec/scheduler_spec.rb", "spec/spec_helper.rb", "multi_db.gemspec"]
  s.has_rdoc = true
  s.homepage = "http://github.com/schoefmax/multi_db"
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "multi_db", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "multi_db"
  s.rubygems_version = %q{1.3.1}
  s.summary = "Connection proxy for ActiveRecord for single master / multiple slave database deployments"

  if s.respond_to? :specification_version then
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency('activerecord', [">= 2.1.0"])
      s.add_runtime_dependency('tlattr_accessors', [">= 0.0.3"])
    else
      s.add_dependency('activerecord', [">= 2.1.0"])
      s.add_dependency('tlattr_accessors', [">= 0.0.3"])
    end
  else
    s.add_dependency('activerecord', [">= 2.1.0"])
    s.add_dependency('tlattr_accessors', [">= 0.0.3"])
  end
end
