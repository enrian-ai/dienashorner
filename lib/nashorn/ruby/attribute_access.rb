module Nashorn
  module Ruby
    class AttributeAccess < AccessBase

      def has(object, name)
        if object.respond_to?(name.to_s) ||
           object.respond_to?(:"#{name}=") # might have a writer but no reader
          return true
        end
        super
      end

      def get(object, name)
        name_sym = name.to_s.to_sym
        if object.respond_to?(name_sym)
          method = object.method(name_sym)
          if method.arity == 0 && # check if it is an attr_reader
            ( object.respond_to?(:"#{name}=") ||
                object.instance_variables.find { |var| var.to_sym == :"@#{name}" } )
            return Nashorn.to_js(method.call)
          else
            return Function.wrap(method.unbind)
          end
        elsif object.respond_to?(:"#{name}=")
          return nil # it does have the property but is non readable
        end
        super
      end

      def set(object, name, value)
        if object.respond_to?(set_name = :"#{name}=")
          rb_value = Nashorn.to_rb(value)
          return object.send(set_name, rb_value)
        end
        super
      end
      alias_method :put, :set

    end
  end
end