source "https://rubygems.org"

gemspec

group :test do
  # NOTE: some specs might be excluded @see #spec/spec_helper.rb
  #gem 'redjs', :git => 'git://github.com/cowboyd/redjs.git', :group => :test,
  #             :ref => "0d844f066666f967a78b20beb164c52d9ac3f5ca"
  gem 'less', '~> 2.6.0', :require => false
  if version = ENV['EXECJS_VERSION']
    gem 'execjs', version, :require => false
  else
    gem 'execjs', '~> 2.7.0', :require => false
  end
end

gem 'rake', '< 11', :require => false, :group => :development
