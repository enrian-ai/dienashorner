require 'nashorn/ruby/access'

module Nashorn
  module Ruby

    @@access = nil
    def self.access; @@access ||= Ruby::DefaultAccess.new end

    def self.access=(access)
      @@access = ( access.respond_to?(:get) && access.respond_to?(:put) ) ? access :
        begin
          access =
            if access && ! access.is_a?(Class) # Ruby.access = :attribute
              name = access.to_s.chomp('_access')
              name = name[0, 1].capitalize << name[1..-1]
              name = :"#{name}Access"
              if Ruby.const_defined?(name)
                Ruby.const_get(name) # e.g. Nashorn::Ruby::AttributeAccess
              else
                const_get(name) # e.g. Nashorn::Ruby::FooAccess
              end
            else # nil, false, Class
              access
            end
          access.is_a?(Class) ? access.new : access
        end
    end

    # Shared "JSObject" implementation.
    module Scriptable
      include JS::JSObject

      attr_reader :unwrap

      # @override JSObject
      def getMember(name)
        return nil if exclude?(name)
        Ruby.access.get(unwrap, name) { super }
      end

      # @override JSObject
      def hasMember(name)
        return nil if exclude?(name)
        Ruby.access.has(unwrap, name) { super }
      end

      # @override JSObject
      def setMember(name, value)
        return nil if exclude?(name)
        Ruby.access.set(unwrap, name, value) { super }
      end

      # @override JSObject
      def getSlot(name)
        return nil if exclude?(name)
        Ruby.access.get_slot(unwrap, name) { super }
      end

      # @override JSObject
      def hasSlot(name)
        return nil if exclude?(name)
        Ruby.access.has_slot(unwrap, name) { super }
      end

      # @override JSObject
      def setSlot(name, value)
        return nil if exclude?(name)
        Ruby.access.set_slot(unwrap, name, value) { super }
      end

      # @override JSObject
      def removeMember(name)
        setMember(name, nil) # TODO remove_method?
      end

      # @override JSObject
      def keySet
        ids = java.util.HashSet.new
        super_set = super
        unwrap.public_methods(false).each do |name|
          next unless name = convert(name.to_s)
          unless super_set.include?(name)
            ids.add name.to_java # java.lang.String
          end
        end
        ids
      end

      private

      def convert(name)
        if exclude?(name)
          nil
        elsif name.end_with?('=')
          name[0...-1]
        else
          name
        end
      end

      FETCH = '[]'.freeze
      STORE = '[]='.freeze

      def exclude?(name)
        name.eql?(FETCH) || name.eql?(STORE)
      end

    end

    class Object < JS::AbstractJSObject
      include Scriptable

      # wrap an arbitrary (ruby) object
      def self.wrap(object)
        Ruby.cache(object) { new(object) }
      end

      def initialize(object)
        super()
        @unwrap = object
      end

      # @override ECMA [[Class]] property
      def getClassName
        @unwrap.class.to_s # to_s handles 'nameless' classes as well
      end

      # @override
      def isInstance(instance)
        instance.class.equal? @unwrap
      end

      # @override
      def isArray; @unwrap.is_a?(Array) end

      # @override
      def isFunction; false end

      # @override
      def isStrictFunction; false end

      # @override
      #def newObject(args); fail end

      def toString
        "[ruby #{getClassName}]" # [object User]
      end

      def equals(other)
        other.is_a?(Object) && unwrap.eql?(other.unwrap)
      end

      def ==(other)
        if other.is_a?(Object)
          unwrap == other.unwrap
        else
          unwrap == other
        end
      end

      def hashCode; @unwrap.hash end

      def to_a
        isArray ? @unwrap : super
      end

    end

    class Function < JS::AbstractJSObject
      include Scriptable

      # wrap a callable (Method/Proc)
      def self.wrap(callable)
        Ruby.cache(callable.to_s) { new(callable) }
      end

      def initialize(callable)
        super()
        @unwrap = callable
      end

      # @override ECMA [[Class]] property
      def getClassName
        @unwrap.to_s # to_s handles 'nameless' classes as well
      end

      #def getFunctionName
      #  @callable.is_a?(Proc) ? "" : @callable.name
      #end

      # @override
      def isInstance(instance)
        instance.class.equal? @unwrap
      end

      # @override
      def isArray; false end

      # @override
      def isFunction; true end

      # @override
      def isStrictFunction; false end

      # @override
      #def newObject(args); fail end

      def length # getLength
        arity = @unwrap.arity
        arity < 0 ? ( arity + 1 ).abs : arity
      end

      def arity; length end

      def equals(other) # JS == operator
        return false unless other.is_a?(Function)
        return true if unwrap == other.unwrap
        # Method.== does check if their bind to the same object
        # JS == means they might be bind to different objects :
        unwrap.to_s == other.unwrap.to_s # "#<Method: Foo#bar>"
      end

      def ==(other)
        if other.is_a?(Object)
          unwrap == other.unwrap
        else
          unwrap == other
        end
      end

      # @override
      def call(*args) # call(Object thiz, Object... args)
        # unless args.first.is_a?(JS::Context)
        #   return super # assume a Ruby #call
        # end

        # NOTE: distinguish a Ruby vs Java call here :
        arr = args[1]
        if arr && args.size == 2 && # Java Function#call dispatch
           arr.respond_to?(:java_class) && arr.java_class.array?
          this = args[0]; args = arr.to_a; java_args = true
        end
        # this = args.shift # Java Function#call dispatch

        callable = @unwrap

        if callable.is_a?(UnboundMethod)
          this = args.shift unless java_args
          callable = callable.bind(Nashorn.to_rb(this)) # TODO wrap TypeError ?
        end
        # JS function style :
        if ( arity = callable.arity ) != -1 # (a1, *a).arity == -2
          if arity > -1 && args.size > arity # omit 'redundant' arguments
            args = args.slice(0, arity)
          elsif arity > args.size || # fill 'missing' arguments
              ( arity < -1 && (arity = arity.abs - 1) > args.size )
            (arity - args.size).times { args.push(nil) }
          end
        end
        rb_args = Nashorn.args_to_rb(args)
        begin
          result = callable.call(*rb_args)
        rescue StandardError, ScriptError => e
          raise e unless java_args
          # TODO is this wrapping needed with __Nashorn__ ?
          raise Ruby.wrap_error(e, e.backtrace) # thus `try { } catch (e)` works in JS
        end
        java_args ? Nashorn.to_js(result) : result
        # Nashorn.to_js(result) # TODO do not convert if java_args ?
      end

      # make sure redefined :call is aliased not the one "inherited" from
      # JS::BaseFunction#call when invoking __call__ (@see ext.rb)
      alias_method :__call__, :call

    end

    class Constructor < Function

      # wrap a ruby class as as constructor function
      def self.wrap(klass)
        # NOTE: caching here seems redundant since we implemented JS::Wrapper
        # and a ruby class objects seems always the same ref under JRuby ...
        Ruby.cache(klass) { new(klass) }
      end

      def initialize(klass)
        super(klass.method(:new))
        @klass = klass
      end

      def unwrap; @klass end

      # @override ECMA [[Class]] property
      def getClassName; @klass.name end

      # @override
      def isInstance(instance)
        return false unless instance
        return true if instance.is_a?(@klass)
        instance.is_a?(Object) && instance.unwrap.is_a?(@klass)
      end

      # @override
      def isArray; false end

      # @override
      def isFunction; true end

      # @override
      def isStrictFunction; false end

      # @override
      def newObject(args); @klass.new(*args) end

      # override int BaseFunction#getLength()
      #def getLength
      #  arity = @klass.instance_method(:initialize).arity
      #  arity < 0 ? ( arity + 1 ).abs : arity
      #end

    end

    def self.cache(key, &block)
      return yield

      #context = JS::Context.getCurrentContext
      #context ? context.cache(key, &block) : yield
    end

    # @private
    class Exception < JS::NashornException

      def initialize(value)
        super wrap_value(value)
      end

      private

      def wrap_value(value)
        value.is_a?(Object) ? value : Object.wrap(value)
      end

    end

    def self.wrap_error(e, backtrace = nil)
      error = Exception.new(e)
      error.set_backtrace(backtrace) if backtrace
      error
    end

  end

  # @private
  RubyObject = Ruby::Object # :nodoc
  # @private
  RubyFunction = Ruby::Function # :nodoc
  # @private
  RubyConstructor = Ruby::Constructor # :nodoc

end
