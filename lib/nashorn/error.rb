module Nashorn

  class JSError < StandardError

    def initialize(native)
      @native = native # might be a NativeException wrapping a Java Throwable
      if ( value = self.value(true) ) != nil
        if value.is_a?(Exception)
          super "#{value.class.name}: #{value.message}"
        elsif value.is_a?(JS::ScriptObject) # && @native.to_s.index('Error:')
          super normalize_message(@native)
        else
          super value
        end
      else
        if cause = self.cause
          message = normalize_message(cause)
        else
          message = normalize_message(@native)
        end
        super message
      end
    end

    def inspect
      "#<#{self.class.name}: #{message}>"
    end

    def message; super.to_s end

    # Returns the (nested) cause of this error if any.
    def cause
      return @cause if defined?(@cause)

      if @native.respond_to?(:cause) && @native.cause
        @cause = @native.cause
      else
        @cause = @native.is_a?(JS::NashornException) ? @native : nil
      end
    end

    # Attempts to unwrap the (native) JavaScript/Java exception.
    def unwrap
      return @unwrap if defined?(@unwrap)
      cause = self.cause
      if cause && cause.is_a?(JS::NashornException)
        e = cause.getCause
        if e && e.is_a?(Java::OrgJrubyExceptions::RaiseException)
          @unwrap = e.getException
        else
          @unwrap = e
        end
      else
        @unwrap = nil
      end
    end

    # Return the thown (native) JavaScript value.
    def value(unwrap = false)
      return @value if defined?(@value) && ! unwrap
      @value = get_thrown unless defined?(@value)
      return @value.unwrap if unwrap && @value.respond_to?(:unwrap)
      @value
    end
    alias_method :thrown, :value

    # The backtrace is constructed using #javascript_backtrace + the Ruby part.
    def backtrace
      if js_backtrace = javascript_backtrace
        js_backtrace.push(*super)
      else
        super
      end
    end

    # Returns the JavaScript back-trace part for this error (the script stack).
    def javascript_backtrace(raw_elements = false)
      return @javascript_backtrace if (@javascript_backtrace ||= nil) && ! raw_elements

      return nil unless cause.is_a?(JS::NashornException)

      return JS::NashornException.getScriptFrames(cause) if raw_elements

      js_backtrace = []
      js_backtrace << @_trace_trail if defined?(@_trace_trail)

      for element in JS::NashornException.getScriptFrames(cause)
        js_backtrace << element.to_s # element - ScriptStackElement
      end
      @javascript_backtrace = js_backtrace
    end

    # jdk.nashorn.internal.runtime::ECMAException < NashornException has these :

    def file_name
      cause.respond_to?(:getFileName) ? cause.getFileName : nil
    end

    def line_number
      cause.respond_to?(:getLineNumber) ? cause.getLineNumber : nil
    end

    def column_number
      cause.respond_to?(:getColumnNumber) ? cause.getColumnNumber : nil
    end

    PARSER_EXCEPTION = 'Java::JdkNashornInternalRuntime::ParserException'
    private_constant :PARSER_EXCEPTION if respond_to?(:private_constant)

    # @private invented for ExceJS
    def self.parse_error?(error)
      PARSER_EXCEPTION.eql? error.class.name
    end

    private

    def get_thrown
      if ( cause = self.cause ) && cause.respond_to?(:thrown)
        cause.thrown  # e.g. NashornException.getThrown
      else
        nil
      end
    end

    def normalize_message(error)
      # "<eval>:1:1 Expected an operand but found )\n ())\n^"
      # extract first trace part of message :
      message = error.message
      return message unless JSError.parse_error?(error)
      if match = message.match(/^(.*?\:\d+\:\d+)\s/)
        @_trace_trail = match[1]
        return message[@_trace_trail.length + 1..-1]
      end
      message
    end

  end

end