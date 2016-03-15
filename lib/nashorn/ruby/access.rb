module Nashorn
  module Ruby

    autoload :DefaultAccess, 'nashorn/ruby/default_access'
    autoload :AttributeAccess, 'nashorn/ruby/attribute_access'

    class AccessBase

      def has(object, name)
        # try [](name) method :
        if object.respond_to?(:'[]') && object.method(:'[]').arity == 1
          unless internal?(name)
            value = object.[](name) { return true }
            return true unless value.nil?
          end
        end
        yield
      end

      def get(object, name)
        # try [](name) method :
        if object.respond_to?(:'[]') && object.method(:'[]').arity == 1
          value = begin
            object[name]
          rescue LocalJumpError
            nil
          end unless internal?(name)
          return Nashorn.to_js(value) unless value.nil?
        end
        yield
      end

      def set(object, name, value)
        # try []=(name, value) method :
        if object.respond_to?(:'[]=') && object.method(:'[]=').arity == 2
          rb_value = Nashorn.to_rb(value)
          begin
            return object[name] = rb_value
          rescue LocalJumpError
          end unless internal?(name)
        end
        yield
      end

      def has_slot(object, index, &block)
        has(object, index, &block)
      end

      def get_slot(object, index, &block)
        get(object, index, &block)
      end

      def set_slot(object, index, value, &block)
        set(object, index, value, &block)
      end

      private

      UNDERSCORES = '__'.freeze

      def internal?(name) # e.g. '__iterator__', '__proto__'
        name.is_a?(String) && name.start_with?(UNDERSCORES) && name.end_with?(UNDERSCORES)
      end

    end

  end
end