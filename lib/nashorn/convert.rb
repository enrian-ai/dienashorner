class << Nashorn

  ScriptObjectMirror = Nashorn::JS::ScriptObjectMirror
  private_constant :ScriptObjectMirror
  ScriptObject = Nashorn::JS::ScriptObject
  private_constant :ScriptObject

  def to_rb(object, unmirror = false)
    # ConsString for optimized String + operations :
    return object.toString if object.is_a?(Java::JavaLang::CharSequence)
    return object.unwrap if object.is_a?(Nashorn::RubyObject)
    return object.unwrap if object.is_a?(Nashorn::RubyFunction)
    return nil if ScriptObjectMirror.isUndefined(object)
    # NOTE: "correct" Nashorn leaking-out internals :
    if ScriptObject && object.is_a?(ScriptObject)
      # BUGY: Java::JavaLang::ClassCastException:
      #   jdk.nashorn.internal.scripts.JO4 cannot be cast to jdk.nashorn.api.scripting.ScriptObjectMirror
      #   jdk.nashorn.api.scripting.ScriptUtils.wrap(jdk/nashorn/api/scripting/ScriptUtils.java:92)
      # object = Nashorn::JS::ScriptUtils.wrap(object)
    end
    return js_mirror_to_rb(object) if unmirror
    object
  end
  alias_method :to_ruby, :to_rb

  def to_js(object)
    case object
    when NilClass              then object
    when String, Numeric       then object.to_java
    when TrueClass, FalseClass then object.to_java
    when Nashorn::JS::JSObject then object
    #when Array                 then array_to_js(object)
    #when Hash                  then hash_to_js(object)
    when Time                  then object.to_java
    when Method, UnboundMethod then Nashorn::Ruby::Function.wrap(object)
    when Proc                  then Nashorn::Ruby::Function.wrap(object)
    when Class                 then Nashorn::Ruby::Constructor.wrap(object)
    else Nashorn::Ruby::Object.wrap(object)
    end
  end
  alias_method :to_javascript, :to_js

  def args_to_rb(args)
    args.map { |arg| to_rb(arg) }
  end

  def args_to_js(args, to_java = false)
    args = args.map { |arg| to_js(arg) }
    to_java ? args.to_java : args
  end

  DEEP_UNMIRROR = ENV_JAVA['nashorn.to_rb.unmirror.deep'] &&
                  ENV_JAVA['nashorn.to_rb.unmirror.deep'].length > 0 &&
                  ENV_JAVA['nashorn.to_rb.unmirror.deep'] != 'false'

  def js_mirror_to_rb(object, deep = DEEP_UNMIRROR)
    if object.is_a?(Nashorn::JS::JSObject)
      if object.isArray
        return object.raw_values.to_a unless deep
        object.raw_values.map { |obj| to_rb(obj, true) }
      end
      return object if object.isFunction # TODO CallableHash < Hash?
      # Nashorn::JS::ScriptObjectMirror is already a Map but still :
      hash = {}
      for key in object.keySet
        hash[key] = deep ? to_rb(object[key], true) : object[key]
      end
      hash
    else
      object
    end
  end

end