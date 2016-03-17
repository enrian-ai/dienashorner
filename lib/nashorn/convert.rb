class << Nashorn

  def to_rb(object, unmirror = false)
    # ConsString for optimized String + operations :
    return object.toString if object.is_a?(Java::JavaLang::CharSequence)
    return object.unwrap if object.is_a?(Nashorn::RubyObject)
    return object.unwrap if object.is_a?(Nashorn::RubyFunction)
    return nil if Nashorn::JS::ScriptObjectMirror.isUndefined(object)
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

  def args_to_js(args)
    args.map { |arg| to_js(arg) }.to_java
  end

  def js_mirror_to_rb(object, deep = true)
    object = Nashorn::JS::ScriptUtils.unwrap(object)
    if object.is_a?(Nashorn::JS::JSObject)
      return object.values.to_a if object.isArray
      return object if object.isFunction
      # Nashorn::JS::ScriptObjectMirror is already a Map but still :
      hash = {}
      object.keySet.each { |key| hash[key] = to_rb object[key], true }
      hash
    else
      object
    end
  end

end