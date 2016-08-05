require 'rspec/core/rake_task'
require 'pry'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :console do
  sh %(pry -I lib -r chip8)
end
