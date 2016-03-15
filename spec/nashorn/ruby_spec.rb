require File.expand_path('../spec_helper', File.dirname(__FILE__))

shared_examples_for Nashorn::Ruby::Scriptable, :shared => true do

  it "puts, gets and has a read/write attr" do
    @wrapper.unwrap.instance_eval do
      def foo; @foo; end
      def foo=(foo); @foo = foo; end
    end

    @wrapper.put('foo', 42)
    @wrapper.has('foo').should == true
    @wrapper.get('foo').should == 42
    @wrapper.unwrap.instance_variable_get(:'@foo').should == 42
  end

  it "puts, gets and has a write only attr" do
    @wrapper.unwrap.instance_eval do
      def foo=(foo); @foo = foo; end
    end

    @wrapper.put('foo', 42)
    @wrapper.has('foo').should == true
    @wrapper.get('foo').should be(nil)
    @wrapper.unwrap.instance_variable_get(:'@foo').should == 42
  end

  it "puts, gets and has gets delegated if it acts like a Hash" do
    @wrapper.unwrap.instance_eval do
      def [](name); (@hash ||= {})[name]; end
      def []=(name, value); (@hash ||= {})[name] = value; end
    end

    @wrapper.put('foo', 42)
    @wrapper.has('foo').should == true
    @wrapper.get('foo').should == 42
    @wrapper.unwrap.instance_variable_get(:'@hash')['foo'].should == 42
  end

  it "puts, gets and has non-existing property" do
    @wrapper.put('foo', 42)
    @wrapper.has('foo').should == false
    @wrapper.get('foo').should be nil # (Rhino::JS::Scriptable::NOT_FOUND)
  end

end

describe Nashorn::Ruby::Object do

  before do
    @wrapper = Nashorn::Ruby::Object.wrap @object = Object.new
  end

  it "unwraps a ruby object" do
    @wrapper.unwrap.should be(@object)
  end

  it_should_behave_like Nashorn::Ruby::Scriptable

  class UII < Object

    attr_reader :reader
    attr_writer :writer

    def method; nil; end

  end

  it "returns the ruby class name" do
    rb_object = Nashorn::Ruby::Object.wrap UII.new
    rb_object.getClassName.should == UII.name
  end

  it "reports being a ruby object on toString" do
    rb_object = Nashorn::Ruby::Object.wrap UII.new
    rb_object.toString.should == '[ruby UII]'
  end

  it "puts a non-existent attr (delegates to start)" do
    start = mock('start')
    start.expects(:put).once
    rb_object = Nashorn::Ruby::Object.wrap UII.new

    rb_object.put('nonExistingAttr', start, 42)
  end

  it "getIds include ruby class methods" do
    rb_object = Nashorn::Ruby::Object.wrap UII.new

    rb_object.keySet.should include("reader")
    rb_object.keySet.should include("method")
    rb_object.keySet.to_a.should_not include('writer=')
    rb_object.keySet.to_a.should include("writer")
  end

  it "getIds include ruby instance methods" do
    rb_object = Nashorn::Ruby::Object.wrap object = UII.new
    object.instance_eval do
      def foo; 'foo'; end
    end

    rb_object.keySet.to_a.should include('foo')
  end

  it "getIds include writers as attr names" do
    rb_object = Nashorn::Ruby::Object.wrap object = UII.new

    rb_object.keys.should include('writer')
    rb_object.keys.should_not include('writer=')

    object.instance_eval do
      def foo=(foo); 'foo' end
    end

    rb_object.keySet.to_a.should include('foo')
    rb_object.keySet.to_a.should_not include('foo=')
  end

  it "is aliased to RubyObject" do
    Nashorn::RubyObject.should be(Nashorn::Ruby::Object)
  end

end

describe Nashorn::Ruby::Function do

  before do
    @wrapper = Nashorn::Ruby::Function.wrap @method = Object.new.method(:to_s)
  end

  it "unwraps a ruby method" do
    @wrapper.unwrap.should be(@method)
  end

  it_should_behave_like Nashorn::Ruby::Scriptable

  it "is (JavaScript) callable as a function" do
    rb_function = Nashorn::Ruby::Function.wrap 'foo'.method(:upcase)
    this = nil; args = nil
    rb_function.call(this, args).should == 'FOO'
  end

  it 'is Ruby callable' do
    rb_function = Nashorn::Ruby::Function.wrap 'foo'.method(:upcase)
    rb_function.call.should == 'FOO'
  end

  it 'is Ruby callable passing arguments' do
    rb_function = Nashorn::Ruby::Function.wrap 'foo'.method(:scan)
    rb_function.call('o').should == ['o', 'o']
  end

  it "args get converted before delegating a ruby function call" do
    klass = Class.new(Object) do
      def foo(array)
        array.all? { |elem| elem.is_a?(String) }
      end
    end
    rb_function = Nashorn::Ruby::Function.wrap method = klass.new.method(:foo)
    this = nil
    args = [ '1'.to_java, java.lang.String.new('2') ].to_java
    # args = [ Rhino::JS::NativeArray.new(args) ].to_java
    rb_function.call(this, args).should be(true)
  end

  it "returned value gets converted to javascript" do
    klass = Class.new(Object) do
      def foo
        [ 42 ]
      end
    end
    rb_function = Nashorn::Ruby::Function.wrap method = klass.new.method(:foo)
    this = nil; args = [].to_java
    rb_function.call(this, args).should be_a(Nashorn::JS::JSObject)
    rb_function.call(this, args).isArray.should be true
    # rb_function.call(this, args).array?.should be true
  end

  it "slices redundant args when delegating call" do
    klass = Class.new(Object) do
      def foo(a1)
        a1
      end
    end
    rb_function = Nashorn::Ruby::Function.wrap klass.new.method(:foo)
    this = nil

    args = [ 1.to_java, 2.to_java, 3.to_java ].to_java; js_return = nil
    lambda { js_return = rb_function.call(this, args) }.should_not raise_error
    js_return.should == 1
  end

  it "fills missing args when delegating call" do
    klass = Class.new(Object) do
      def foo(a1, a2)
        [ a1, a2 ]
      end
    end
    rb_function = Nashorn::Ruby::Function.wrap klass.new.method(:foo)
    this = nil

    args = [ 1.to_java ].to_java; js_return = nil
    lambda { js_return = rb_function.call(this, args) }.should_not raise_error
    # js_return.toArray.to_a.should == [ 1, nil ]
    js_return.to_a.should == [ 1, nil ]

    args = [ ].to_java; js_return = nil
    lambda { js_return = rb_function.call(this, args) }.should_not raise_error
    # js_return.toArray.to_a.should == [ nil, nil ]
    js_return.should == [ nil, nil ]
  end

  it "fills missing args when delegating call that ends with varargs" do
    klass = Class.new(Object) do
      def foo(a1, a2, *args)
        [ a1, a2, args ].flatten
      end
    end
    rb_function = Nashorn::Ruby::Function.wrap klass.new.method(:foo)
    this = nil

    args = [ ].to_java; js_return = nil
    lambda { js_return = rb_function.call(this, args) }.should_not raise_error
    js_return.should == [ nil, nil ]

    args = [ 1.to_java ].to_java; js_return = nil
    lambda { js_return = rb_function.call(this, args) }.should_not raise_error
    js_return.should == [ 1, nil ]

    args = [ 1.to_java, 2.to_java ].to_java; js_return = nil
    lambda { js_return = rb_function.call(this, args) }.should_not raise_error
    js_return.to_a.should == [ 1, 2 ]

    args = [ 1.to_java, 2.to_java, 3.to_java ].to_java; js_return = nil
    lambda { js_return = rb_function.call(this, args) }.should_not raise_error
    js_return.to_a.should == [ 1, 2, 3 ]
  end

  it "returns correct arity and length" do
    klass = Class.new(Object) do
      def foo(a1, a2)
        a1 || a2
      end
    end
    rb_function = Nashorn::Ruby::Function.wrap klass.new.method(:foo)
    rb_function.arity.should == 2
    rb_function.length.should == 2
  end

  it "reports arity and length of 0 for varargs only method" do
    klass = Class.new(Object) do
      def foo(*args); args; end
    end
    rb_function = Nashorn::Ruby::Function.wrap klass.new.method(:foo)
    rb_function.arity.should == 0
    rb_function.length.should == 0
  end

  it "reports correct arity and length for ending varargs" do
    klass = Class.new(Object) do
      def foo(a1, *args); [ a1, args ]; end
    end
    rb_function = Nashorn::Ruby::Function.wrap klass.new.method(:foo)
    rb_function.arity.should == 1
    rb_function.length.should == 1
  end

  it "is aliased to RubyFunction" do
    Nashorn::RubyFunction.should be(Nashorn::Ruby::Function)
  end

end

describe Nashorn::Ruby::Constructor do

  before do
    @wrapper = Nashorn::Ruby::Constructor.wrap @class = Class.new(Object)
  end

  it "unwraps a ruby method" do
    @wrapper.unwrap.should be(@class)
  end

  it_should_behave_like Nashorn::Ruby::Scriptable

  class Foo < Object
  end

  it "is callable as a function" do
    rb_new = Nashorn::Ruby::Constructor.wrap Foo
    this = nil; args = nil
    rb_new.__call__(this, args).should be_a(Nashorn::Ruby::Object)
    rb_new.__call__(this, args).unwrap.should be_a(Foo)
  end

  it "returns correct arity and length" do
    rb_new = Nashorn::Ruby::Constructor.wrap Foo
    rb_new.arity.should == 0
    rb_new.length.should == 0
  end

  it "reports arity and length of 0 for varargs" do
    klass = Class.new do
      def initialize(*args); args; end
    end
    rb_new = Nashorn::Ruby::Constructor.wrap klass
    rb_new.arity.should == 0
    rb_new.length.should == 0
  end

  it "is aliased to RubyConstructor" do
    (!! defined? Nashorn::RubyConstructor).should == true
    Nashorn::RubyConstructor.should be(Nashorn::Ruby::Constructor)
  end

end

#describe Nashorn::Ruby::Exception do
#
#  it 'outcomes as ruby errors in function calls' do
#    klass = Class.new(Object) do
#      def foo(arg)
#        raise TypeError, "don't foo me with #{arg}" unless arg.is_a?(String)
#      end
#    end
#    rb_function = Rhino::Ruby::Function.wrap klass.new.method(:foo)
#    this = nil; args = [ 42.to_java ].to_java
#    begin
#      rb_function.call(context, scope, this, args)
#    rescue java.lang.Exception => e
#      e.should be_a(Rhino::Ruby::Exception)
#      e.getValue.should be_a(Rhino::Ruby::Object)
#      e.value.unwrap.should be_a(TypeError)
#      e.value.unwrap.message == "don't foo me with 42"
#    else
#      fail "#{Rhino::Ruby::Exception} expected to be raised"
#    end
#  end
#
#end
