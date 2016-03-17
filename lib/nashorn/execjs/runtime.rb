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

      def call(prop, *args)
        evaled = @nashorn_context.eval(prop)
        unbox evaled.call(*args)
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

        error_class = e.message.index('syntax error') ? RuntimeError : ProgramError

        backtrace = e.backtrace

        if js_stack = e.javascript_backtrace
          backtrace = backtrace - js_stack
          # ["<<eval>>.<anonymous>(<eval>:1)", "<<eval>>.<program>(<eval>:1)"]
          js_stack = js_stack.map { |line| line.sub(/\<eval\>\:/, "(execjs):") }
          backtrace = js_stack + backtrace
        elsif backtrace
          backtrace = backtrace.dup; backtrace.unshift('(execjs):1')
        end

        error = error_class.new e.value ? e.value.to_s : e.message
        error.set_backtrace(backtrace)
        error
      end

    end

    def name
      'dienashorner (Nashorn)'
    end

    def available?
      return false unless defined? JRUBY_VERSION
      require 'nashorn'
      true
    rescue LoadError
      false
    end

  end
end
