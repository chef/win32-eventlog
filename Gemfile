source "https://rubygems.org"

gemspec

group :test do
  gem "ptools"
  gem "test-unit"
  gem "rake"
end

group :docs do
  gem "yard"
  gem "redcarpet"
  gem "github-markup"
end

group :debug do
  gem "pry"
  gem "pry-byebug"
  gem "pry-stack_explorer"
  gem "rb-readline"
end

instance_eval(ENV["GEMFILE_MOD"]) if ENV["GEMFILE_MOD"]

# If you want to load debugging tools into the bundle exec sandbox,
# add these additional dependencies into Gemfile.local
eval_gemfile(__FILE__ + ".local") if File.exist?(__FILE__ + ".local")
