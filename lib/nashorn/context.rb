require 'stringio'

module Nashorn

  # ==Overview
  #  All Javascript must be executed in a context which represents the execution environment in
  #  which scripts will run. The environment consists of the standard javascript objects
  #  and functions like Object, String, Array, etc... as well as any objects or functions which
  #  have been defined in it. e.g.
  #
  #   Context.open do |js|
  #     js['num'] = 5
  #     js.eval('num + 5') #=> 10
  #   end
  #
  # == Multiple Contexts.
  #
  #   six = 6
  #   Context.open do |js|
  #     js['num'] = 5
  #     js.eval('num') # => 5
  #     Context.open do |js|
  #       js['num'] = 10
  #       js.eval('num') # => 10
  #       js.eval('++num') # => 11
  #     end
  #     js.eval('num') # => 5
  #   end
  #
  class Context

    class << self

      def open(options = {}, &block)
        new(options).open(&block)
      end

      def eval(javascript)
        new.eval(javascript)
      end

    end

    ENGINE_SCOPE = javax.script.ScriptContext.ENGINE_SCOPE
    NashornScriptEngineFactory = JS::NashornScriptEngineFactory
    NASHORN_GLOBAL = JS::NashornScriptEngine::NASHORN_GLOBAL.to_java
    SimpleScriptContext = javax.script.SimpleScriptContext

    # Create a new JavaScript environment for executing JS (and Ruby) code.
    def initialize(options = nil)
      if options.is_a?(Hash)
        factory = options[:factory]
        with = options[:with]
        java = options[:java]
        version = options[:javascript_version] || options[:language_version]
        if version
          args = [ '--language', version.to_s ]
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

    # Read a value from the global scope of this context
    def [](key)
      @scope[key]
    end

    # Set a value in the global scope of this context. This value will be visible to all the
    # javascript that is executed in this context.
    def []=(key, val)
      @scope[key] = val
    end

    # Evaluate a String/IO of JavaScript in this context.
    def eval(source, source_name = "<eval>", line_number = 1)
      open do
        if IO === source || StringIO === source
          source = IOReader.new(source)
        else
          source = source.to_s
        end
        Nashorn.to_rb @native.eval(source, @scope)
      end
    end

    def evaluate(source); eval(source) end

    # Read the contents of <tt>filename</tt> and evaluate it as javascript. Returns the result of evaluating the
    # javascript. e.g.
    #
    # Context.open do |cxt|
    #   cxt.load("path/to/some/lib.js")
    # end
    #
    def load(filename)
      File.open(filename) do |file|
        eval file, filename
      end
    end

    def language_version
      factory.getLanguageVersion
    end

    # Get the JS interpreter version.
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

    # Sets interpreter mode a.k.a. JS language version.
    # @private
    def javascript_version=(version)
      warn "#{self}#javascript_version = not supported, use open(javascript_version: #{version.inspect}) instead"
    end
    alias :version= :javascript_version=

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

    # implement int Reader#read(char[] buffer, int offset, int length)
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
