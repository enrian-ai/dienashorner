begin
  require 'java'
rescue LoadError => e
  raise e if defined? JRUBY_VERSION
  raise LoadError, "Please use JRuby with Nashorn : #{e.message}", e.backtrace
end

if ENV_JAVA['java.version'] < '1.8'
  warn "Nashorn needs Java >= 8, JRE #{ENV_JAVA['java.version']} likely won't work!"
end

module Nashorn
  # @private
  module JS
    include_package 'jdk.nashorn.api.scripting'
    # include_package 'jdk.nashorn.internal.runtime'
    ScriptObject = Java::JdkNashornInternalRuntime::ScriptObject rescue nil
    # Undefined = Java::JdkNashornInternalRuntime::Undefined rescue nil
  end

  def eval_js(source, options = {})
    factory = JS::NashornScriptEngineFactory.new
    factory.getScriptEngine.eval(source)
  end

  module_function :eval_js # due include Nashorn

  class << self
    alias_method :eval, :eval_js # Nashorn.eval '"4" + 2'
  end

  autoload :Context, 'nashorn/context'

end

require 'nashorn/version'
require 'nashorn/ext'
require 'nashorn/convert'
require 'nashorn/error'
require 'nashorn/ruby'
