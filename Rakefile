
task :default => :spec

begin
  require 'bundler/setup'
rescue LoadError => e
  warn "Bundler not available: #{e.inspect}"
else
  require 'bundler/gem_tasks'
  Bundler::GemHelper.install_tasks
end

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rspec_opts = '--color'
end
