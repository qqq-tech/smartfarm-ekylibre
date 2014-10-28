# First-runs tasks
namespace :first_run do

  desc "Load the default first-run"
  task :default => :environment do
    Ekylibre::FirstRun.launch({folder: "default"}.merge(ENV.to_hash.symbolize_keys.slice(:folder, :name, :max, :mode)))
  end


  desc "Build a First-Run package"
  task :build do
    folder = ENV["folder"]
    Ekylibre::FirstRun.build(folder)
  end

end

desc "Load first run in one transaction"
task :first_run => :environment do
  Ekylibre::FirstRun.launch ENV.to_hash.symbolize_keys.slice(:folder, :name, :max, :mode)
end
