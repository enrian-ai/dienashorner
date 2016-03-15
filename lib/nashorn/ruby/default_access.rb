module Nashorn
  module Ruby
    class DefaultAccess < AccessBase

      def has(object, name)
        if object.respond_to?(name.to_s) ||
           object.respond_to?(:"#{name}=")
          return true
        end
        super
      end

      def get(object, name)
        if object.respond_to?(name_s = name.to_s)
          method = object.method(name_s)
          if method.arity == 0
            return Nashorn.to_js(method.call)
          else
            return Function.wrap(method.unbind)
          end
        elsif object.respond_to?(:"#{name}=")
          return nil
        end
        super
      end

      def set(object, name, value)
        if object.respond_to?(set_name = :"#{name}=")
          return object.send(set_name, Nashorn.to_rb(value))
        end
        super
      end
      alias_method :put, :set

    end
  end
end