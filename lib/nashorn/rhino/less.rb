begin
  require 'nashorn/rhino'
rescue LoadError => e
  warn "[WARNING] Please install gem 'dienashorner' to use Less under JRuby."
  raise e
end

require 'less/java_script'

module Less
  module JavaScript
    class NashornContext

      def self.instance
        return new # NOTE: for Rhino a context should be kept open per thread !
      end

      def initialize(globals = nil)
        @context = Nashorn::Context.new :java => true
        #if @context.respond_to?(:version)
        #  @context.version = '1.8'
        #  apply_1_8_compatibility! if @context.version.to_s != '1.8'
        #else
        #  apply_1_8_compatibility!
        #end
        globals.each { |key, val| @context[key] = val } if globals
      end

      def unwrap
        @context
      end

      def exec(&block)
        @context.open(&block)
      rescue Nashorn::JSError => e
        handle_js_error(e)
      end

      def eval(source, options = nil)
        source = source.encode('UTF-8') if source.respond_to?(:encode)
        @context.eval("(#{source})")
      rescue Nashorn::JSError => e
        handle_js_error(e)
      end

      def call(properties, *args)
        args.last.is_a?(::Hash) ? args.pop : {} # extract_option!
        @context.eval(properties).call(*args)
      rescue Nashorn::JSError => e
        handle_js_error(e)
      end

      def method_missing(symbol, *args)
        if @context.respond_to?(symbol)
          @context.send(symbol, *args)
        else
          super
        end
      end

      private

      def handle_js_error(e)

        raise e # TODO NOT IMPLEMENTED

        #if e.value && ( e.value['message'] || e.value['type'].is_a?(String) )
        #  raise Less::ParseError.new(e, e.value) # LessError
        #end
        #if e.unwrap.to_s =~ /missing opening `\(`/
        #  raise Less::ParseError.new(e.unwrap.to_s)
        #end
        #if e.message && e.message[0, 12] == "Syntax Error"
        #  raise Less::ParseError.new(e)
        #else
        #  raise Less::Error.new(e)
        #end
      end

    end
  end
end

Less::JavaScript.context_wrapper = Less::JavaScript::NashornContext
