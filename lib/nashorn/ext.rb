module Nashorn
  module JS

    JSObject.module_eval do

      def [](key)
        Nashorn.to_rb key.is_a?(Fixnum) ? getSlot(key) : getMember(key.to_s)
      end

      def []=(key, value)
        key.is_a?(Fixnum) ? setSlot(key, value) : setMember(key.to_s, value)
      end

      # enumerate the key value pairs contained in this javascript object. e.g.
      #
      #     eval_js("{foo: 'bar', baz: 'bang'}").each do |key,value|
      #       puts "#{key} -> #{value} "
      #     end
      #
      # outputs foo -> bar baz -> bang
      #
      def each
        each_raw { |key, val| yield key, Nashorn.to_rb(val) }
      end

      def each_key
        each_raw { |key, val| yield key }
      end

      def each_value
        each_raw { |key, val| yield Nashorn.to_rb(val) }
      end

      def each_raw
        for id in keySet do
          yield id, getMember(id)
        end
      end

      def keys
        keySet.to_a
      end

      def values
        values.to_a
      end

      # Converts the native object to a hash. This isn't really a stretch since it's
      # pretty much a hash in the first place.
      def to_h
        hash = {}
        each do |key, val|
          hash[key] = val.is_a?(JSObject) && ! val.equal?(self) ? val.to_h : val
        end
        hash
      end

    #  def ==(other)
    #    equivalentValues(other) == true # JS ==
    #  end
    #
    #  def eql?(other)
    #    self.class == other.class && self.==(other)
    #  end

      # Convert this javascript object into a json string.
      def to_json(*args)
        to_h.to_json(*args)
      end

      # Delegate methods to JS object if possible when called from Ruby.
      def method_missing(name, *args)
        name_str = name.to_s
        if name_str.end_with?('=') && args.size == 1 # writer -> JS put
          self[ name_str[0...-1] ] = args[0]
        else
          if hasMember(name_str) && property = getMember(name_str)
            if property.is_a?(JSObject) && property.isFunction
              js_args = Nashorn.args_to_js(args)
              Nashorn.to_rb property.__call__(self, js_args)
            else
              if args.size > 0
                raise ArgumentError, "can't call '#{name_str}' with args: #{args.inspect} as it's a property"
              end
              Nashorn.to_rb property
            end
          else
            super
          end
        end
      end

      # function :

      # alias_method :__call__, :call

      # make JavaScript functions callable Ruby style e.g. `fn.call('42')`
      #
      # NOTE: That invoking #call does not have the same semantics as
      # JavaScript's Function#call but rather as Ruby's Method#call !
      # Use #apply or #bind before calling to achieve the same effect.
      def call(*args)
        this = nil
        Nashorn.to_rb __call__ this, Nashorn.args_to_js(args)
      rescue JS::NashornException => e
        raise Nashorn::JSError.new(e)
      end

      # bind a JavaScript function into the given (this) context
      #def bind(this, *args)
      #  args = Nashorn.args_to_js(args)
      #  Rhino::JS::BoundFunction.new(self, Nashorn.to_js(this), args)
      #end

      # use JavaScript functions constructors from Ruby as `fn.new`
      def new(*args)
        newObject Nashorn.args_to_js(args)
      rescue JS::NashornException => e
        raise Nashorn::JSError.new(e)
      end

      # apply a function with the given context and (optional) arguments
      # e.g. `fn.apply(obj, 1, 2)`
      #
      # NOTE: That #call from Ruby does not have the same semantics as
      # JavaScript's Function#call but rather as Ruby's Method#call !
      def apply(this, *args)
        __call__ Nashorn.to_js(this), Nashorn.args_to_js(args)
      rescue JS::NashornException => e
        raise Nashorn::JSError.new(e)
      end
      alias_method :methodcall, :apply # V8::Function compatibility

    end

    AbstractJSObject.module_eval do
      alias_method :__call__, :call
    end

    ScriptObjectMirror.module_eval do # implements java.util.Map

      # @private NOTE: duplicated from JSObject
      def [](key)
        Nashorn.to_rb key.is_a?(Fixnum) ? getSlot(key) : getMember(key.to_s)
      end

      # @private NOTE: duplicated from JSObject
      def []=(key, value)
        key.is_a?(Fixnum) ? setSlot(key, value) : setMember(key.to_s, value)
      end

      # @private NOTE: duplicated from JSObject
      def call(*args)
        this = nil
        Nashorn.to_rb __call__ this, Nashorn.args_to_js(args)
      rescue JS::NashornException => e
        raise Nashorn::JSError.new(e)
      end

    end

    NashornException.class_eval do
      alias_method :value, :thrown
    end

  end
end
