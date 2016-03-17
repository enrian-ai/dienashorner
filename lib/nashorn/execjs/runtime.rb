require 'execjs/runtime'

module ExecJS
  class NashornRuntime < Runtime
    class Context < Runtime::Context

      def initialize(runtime, source = nil)
        source = encode(source) if source
        @nashorn_context = ::Nashorn::Context.new
        @nashorn_context.eval(source) if source
      rescue Exception => e
        raise wrap_error(e)
      end

      def exec(source, options = nil) # options not used
        source = encode(source)
        eval "(function(){#{source}})()", options if /\S/ =~ source
      end

      def eval(source, options = nil) # options not used
        source = encode(source)
        unbox @nashorn_context.eval("(#{source})") if /\S/ =~ source
      rescue Exception => e
        raise wrap_error(e)
      end

      def call(properties, *args)
        evaled = @nashorn_context.eval(properties)
        unbox @nashorn_context.eval(properties).call(*args)
      rescue Exception => e
        raise wrap_error(e)
      end

      def unbox(value)
        value = ::Nashorn::to_rb(value, false) # ExecJS likes its own way :

        if value.is_a?(::Nashorn::JS::JSObject)
          return nil if value.isFunction
          return value.values.map { |v| unbox(v) } if value.isArray
          hash = {}; value.each_raw do |key, val|
            next if val.respond_to?(:isFunction) && val.isFunction
            hash[key] = unbox(val)
          end
          return hash
        end
        value
      end

      def wrap_error(e)
        return e unless e.is_a?(::Nashorn::JSError)

        error_class = e.message == "syntax error" ? RuntimeError : ProgramError

        stack = e.backtrace
        stack = stack.map { |line| line.sub(" at ", "").sub("<eval>", "(execjs)").strip }
        stack.unshift("(execjs):1") if e.javascript_backtrace.empty?

        error = error_class.new(e.value.to_s)
        error.set_backtrace(stack)
        error
      end

    end

    def name
      'dienashorner (Nashorn)'
    end

    def available?
      return false unless defined? JRUBY_VERSION
      require 'nashorn' # require 'nashorn/context'
      true
    rescue LoadError
      false
    end

  end
end
