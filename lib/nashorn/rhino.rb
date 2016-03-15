require 'nashorn'

$LOADED_FEATURES << 'rhino'

require 'nashorn/context'

module Nashorn
  module Ruby
    Scriptable.module_eval do

      def get(name, scope = nil)
        getMember(name)
      end

      def has(name, scope = nil)
        hasMember(name)
      end

      def put(name, value, scope = nil)
        setMember(name, value)
      end

    end
  end
  module JS
    Scriptable = JSObject
    JavaScriptException = NashornException
    RhinoException = NashornException
  end
end