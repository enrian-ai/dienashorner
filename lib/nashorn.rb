begin
  require 'java'
rescue LoadError => e
  raise e if defined? JRUBY_VERSION
  raise LoadError, "Please use JRuby with Nashorn : #{e.message}", e.backtrace
end

if ENV_JAVA['java.version'] < '1.8'
  warn "Nashorn needs Java >= 8, you're Java version #{ENV_JAVA['java.version']} won't work!"
end

module Nashorn
  # @private
  module JS
    include_package 'jdk.nashorn.api.scripting'
  end

  class << self

    def eval_js(source, options = {})
      factory = JS::NashornScriptEngineFactory.new
      factory.getScriptEngine.eval(source)
    end
    alias_method :eval, :eval_js

  end
end

require 'nashorn/version'
require 'nashorn/ext'
require 'nashorn/convert'
require 'nashorn/ruby'
