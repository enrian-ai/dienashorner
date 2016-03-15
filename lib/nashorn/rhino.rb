require 'nashorn'
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

if Object.const_defined?(:Rhino)
  warn "therubyrhino seems to be loaded, Nashorn won't emulate Rhino"
else
  $LOADED_FEATURES << 'rhino'
  Rhino = Nashorn # the-borg!
end