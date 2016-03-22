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
        #if e.value && ( e.value['message'] || e.value['type'].is_a?(String) )
        #  raise Less::ParseError.new(e, e.value) # LessError
        #end
        raise Less::ParseError.new(e) if ::Nashorn::JSError.parse_error?(e.cause)

        msg = e.value.to_s
        raise Less::ParseError.new(msg) if msg.start_with?("missing opening `(`")
        #if e.message && e.message[0, 12] == "Syntax Error"
        #  raise Less::ParseError.new(e)
        #end
        raise Less::Error.new(e)
      end

    end

    def self.to_js_hash(hash) # TODO this needs to be figured out
      # we can not pass wrapped Ruby Hash objects down as they won't
      # have a prototype (and thus no hasOwnProperty)
      js_hash = Nashorn.eval_js '({})'
      hash.each { |key, val| js_hash[key] = val }
      js_hash
    end

  end
end

Less::JavaScript.context_wrapper = Less::JavaScript::NashornContext

require 'less'

Less::Parser.class_eval do

  def initialize(options = {})
    env = {}
    Less.defaults.merge(options).each do |key, val|
      env[key.to_s] =
        case val
        when Symbol, Pathname then val.to_s
        when Array
          val.map!(&:to_s) if key.to_sym == :paths # might contain Pathname-s
          val # keep the original passed Array
        else val # true/false/String/Method
        end
    end
    ###
    env = Less::JavaScript.to_js_hash env
    ###
    @parser = Less::JavaScript.exec { Less['Parser'].new(env) }
  end

end

Less::Parser::Tree.class_eval do

  def to_css(opts = {})
    ###
    opts = Less::JavaScript.to_js_hash opts
    ###
    Less::JavaScript.exec { @tree.toCSS(opts) }
  end

end
