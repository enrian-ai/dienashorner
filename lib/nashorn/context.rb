require 'stringio'

module Nashorn

  # JavaScript gets executed in a context which represents the execution environment
  # in which scripts run. The environment consists of the standard JavaScript objects
  # and functions like `Object`, `parseInt()` or `null`, as well as any objects or
  # functions which have been defined in it. e.g.
  #
  #   Context.open do |js|
  #     js['answer'] = 22
  #     js['compute'] = lambda { |t| 10 * t }
  #     js.eval('num + compute(2)') #=> 42
  #   end
  #
  # @note Context are isolated, multiple context do not share any JS objects!
  class Context

    class << self

      def open(options = nil, &block)
        new(options).open(&block)
      end

      def eval(source, options = nil)
        new(options).eval(source)
      end

    end

    # @private
    ENGINE_SCOPE = javax.script.ScriptContext.ENGINE_SCOPE
    # @private
    NashornScriptEngineFactory = JS::NashornScriptEngineFactory
    # @private
    NASHORN_GLOBAL = JS::NashornScriptEngine::NASHORN_GLOBAL.to_java
    # @private
    SimpleScriptContext = javax.script.SimpleScriptContext

    # Create a new JavaScript environment for executing JS (and Ruby) code.
    def initialize(options = nil)
      if options.is_a?(Hash)
        factory = options[:factory]
        with = options[:with]
        java = options[:java]
        version = options[:javascript_version] || options[:language_version]
        if version
          (args ||= []).push '--language', version.to_s
        end
        if options.key?(:strict)
          (args ||= []).push '-strict', (!!options[:strict]).to_s
        end
        if options.key?(:scripting)
          (args ||= []).push '-scripting', (!!options[:scripting]).to_s
        end
      elsif options.is_a?(String)
        args = options.split(' ')
      elsif options.is_a?(Array)
        args = options
      end
      factory ||= NashornScriptEngineFactory.new
      with ||= nil
      java = true if java.nil?

      @native = args ? factory.getScriptEngine(args.to_java) : factory.getScriptEngine

      #simple_context = SimpleScriptContext.new
      #bindings = @native.getBindings(ENGINE_SCOPE)
      #global = bindings.get(NASHORN_GLOBAL)

      @scope = global = @native.eval('this')

      if with
        #bindings.set(NASHORN_GLOBAL, @scope = Nashorn.to_js(with))
        object = @native.eval('Object')
        @native.invokeMethod(object, 'bindProperties', global, Nashorn.to_js(with))
      end
      unless java
        [ 'java', 'javax', 'org', 'com', 'Packages', 'Java' ].each do |name|
          global.removeMember(name)
        end
      end
      yield(self) if block_given?
    end

    def factory; @native.getFactory end

    attr_reader :scope

    # Read a value from the global scope of this context
    def [](key)
      @scope[key]
    end

    # Set a value in the global scope of this context. This value will be visible to all the
    # javascript that is executed in this context.
    def []=(key, val)
      @scope[key] = val
    end

    # @private
    FILENAME = javax.script.ScriptEngine.FILENAME

    # Evaluate a String/IO of JavaScript in this context.
    def eval(source, filename = nil, line = nil)
      open do
        if IO === source || StringIO === source
          source = IOReader.new(source)
        else
          source = source.to_s
        end
        @native.put(FILENAME, filename) if filename
        Nashorn.to_rb @native.eval(source, @scope)
      end
    end

    def evaluate(source, filename = nil); eval(source, filename) end

    # Read the contents of <tt>filename</tt> and evaluate it as JavaScript.
    #
    #   Context.open { |js_env| js_env.load("path/to/some/lib.js") }
    #
    # @return the result of evaluating the JavaScript
    def load(filename)
      File.open(filename) do |file|
        eval file, filename
      end
    end

    def language_version
      factory.getLanguageVersion
    end

    # Get the JavaScript language version.
    # @private
    def javascript_version
      case version = language_version
        when nil, '' then nil
        #when 'es5'   then 1.5 # default
        #when 'es6'   then 1.6
        else version
      end
    end
    alias :version :javascript_version

    # @private
    def javascript_version=(version)
      warn "#{self}#javascript_version = not supported, use open(javascript_version: #{version.inspect}) instead"
    end
    alias :version= :javascript_version=

    # @private
    ScriptException = javax.script.ScriptException

    def open
      yield self
    rescue ScriptException => e
      raise JSError.new(e)
    rescue JS::NashornException => e
      raise JSError.new(e)
    end

  end

  # @private
  class IOReader < java.io.Reader

    def initialize(io)
      @io = io
    end

    # int Reader#read(char[] buffer, int offset, int length)
    def read(buffer, offset, length)
      str = nil
      begin
        str = @io.read(length)
      rescue StandardError => e
        raise java.io.IOException.new("failed reading from ruby IO object: #{e.inspect}")
      end
      return -1 if str.nil?

      jstr = str.to_java
      for i in 0 .. jstr.length - 1
        buffer[i + offset] = jstr.charAt(i)
      end
      return jstr.length
    end

  end

  # @private not used
  class ContextError < StandardError; end

end
