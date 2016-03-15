module Nashorn

  class JSError < StandardError

    def initialize(native)
      @native = native # might be a NativeException wrapping a Java Throwable
      if ( value = self.value(true) ) != nil
        super value.is_a?(Exception) ? "#{value.class.name}: #{value.message}" : value
      else
        super cause ? cause.message : @native
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
        @native.is_a?(JS::NashornException) ? @native : nil
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
      return nil unless cause.is_a?(JS::NashornException)
      JS::NashornException.getScriptFrames(cause).map do |element|
        raw_elements ? element : element.to_s # ScriptStackElement
      end
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

    private

    def get_thrown
      if ( cause = self.cause ) && cause.respond_to?(:thrown)
        cause.thrown  # e.g. NashornException.getThrown
      else
        nil
      end
    end

  end

end