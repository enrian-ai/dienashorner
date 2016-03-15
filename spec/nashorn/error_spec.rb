require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Nashorn::JSError do

  it "works as a StandardError with a message being passed" do
    js_error = Nashorn::JSError.new 'an error message'
    lambda { js_error.to_s && js_error.inspect }.should_not raise_error

    js_error.cause.should be nil
    js_error.message.should == 'an error message'
    js_error.javascript_backtrace.should be nil
  end

#  it "might wrap a NashornException wrapped in a NativeException like error" do
#    # JRuby's NativeException.new(Nashorn_e) does not work as it is
#    # intended to handle Java exceptions ... no new on the Ruby side
#    native_error_class = Class.new(RuntimeError) do
#      def initialize(cause); @cause = cause end
#      def cause; @cause end
#    end
#
#    nashorn_e = javax.script.ScriptException.new("42".to_java)
#    js_error = Nashorn::JSError.new native_error_class.new(nashorn_e)
#    lambda { js_error.to_s && js_error.inspect }.should_not raise_error
#
#    js_error.cause.should be nashorn_e
#    js_error.message.should == '42'
#    js_error.javascript_backtrace.should be nil
#  end

  it "keeps the thrown javascript object value" do
    begin
      Nashorn::Context.eval "throw { foo: 'bar' }"
    rescue => e
      e.should be_a(Nashorn::JSError)
      e.message.should == e.value.to_s

      pending

      puts e.value.inspect
      puts e.value.class
      puts e.value.class.included_modules.inspect
      puts e.value.class.superclass
      puts e.value.class.superclass.included_modules.inspect

      e.value.should be_a(Nashorn::JS::JSObject)
      e.value['foo'].should == 'bar'
    else
      fail "expected to rescue"
    end
  end

  it "keeps the thrown javascript string value" do
    begin
      Nashorn::Context.eval "throw 'mehehehe'"
    rescue => e
      e.should be_a(Nashorn::JSError)
      e.value.should == 'mehehehe'
      e.message.should == e.value.to_s
    else
      fail "expected to rescue"
    end
  end

  it "contains the native error as the cause 42" do
    begin
      Nashorn::Context.eval "throw 42"
    rescue => e # javax.script.ScriptException
      e.cause.should_not be nil
      e.cause.should be_a Java::JdkNashornInternalRuntime::ECMAException
      e.cause.value.should == 42
      e.cause.lineNumber.should == 1
      e.cause.fileName.should == '<eval>'
    else
      fail "expected to rescue"
    end
  end

  it "has a correct javascript backtrace" do
    begin
      Nashorn::Context.eval "throw 42"
    rescue => e
      #
      e.javascript_backtrace.should be_a Enumerable
      e.javascript_backtrace.size.should >= 1
      e.javascript_backtrace[0].should =~ /.*?<eval>:1/
      e.javascript_backtrace(true).should be_a Enumerable
      e.javascript_backtrace(true).size.should >= 1
      element = e.javascript_backtrace(true)[0]
      element.file_name.should == '<eval>'
      # element.function_name.should be nil
      element.line_number.should == 1
    else
      fail "expected to rescue"
    end
  end

  it "contains function name in javascript backtrace" do
    begin
      Nashorn::Context.eval "function fortyTwo() { throw 42 }\n fortyTwo()"
    rescue => e
      # ["<<eval>>.fortyTwo(<eval>:1)", "<<eval>>.<program>(<eval>:2)"]
      e.javascript_backtrace.size.should >= 2
      e.javascript_backtrace[0].should =~ /fortyTwo\(<eval>:1\)/
      expect( e.javascript_backtrace.find { |trace| trace.index("<eval>:2") } ).to_not be nil
    else
      fail "expected to rescue"
    end
  end

  it "backtrace starts with the javascript part" do
    begin
      Nashorn::Context.eval "throw 42"
    rescue => e
      e.backtrace.should be_a Array
      e.backtrace[0].should =~ /.*?<eval>:1/
      e.backtrace[1].should_not be nil
    else
      fail "expected to rescue"
    end
  end

  it "inspect shows the javascript value" do
    begin
      Nashorn::Context.eval "throw '42'"
    rescue => e
      e.inspect.should == '#<Nashorn::JSError: 42>'
      e.to_s.should == '42'
    else
      fail "expected to rescue"
    end
  end

  it "wrapps false value correctly" do
    begin
      Nashorn::Context.eval "throw false"
    rescue => e
      e.inspect.should == '#<Nashorn::JSError: false>'
      e.value.should be false
    else
      fail "expected to rescue"
    end
  end

  it "wrapps null value correctly" do
    begin
      Nashorn::Context.eval "throw null"
    rescue => e
      e.inspect.should == '#<Nashorn::JSError: null>'
      e.value.should be nil
    else
      fail "expected to rescue"
    end
  end

  it "raises correct error from function#apply" do
    begin
      context = Nashorn::Context.new
      context.eval "function foo() { throw 'bar' }"
      context['foo'].apply(nil)
    rescue => e
      e.should be_a Nashorn::JSError
      e.value.should == 'bar'
    else
      fail "expected to rescue"
    end
  end

  it "prints info about nested (ruby) error" do
    context = Nashorn::Context.new
    klass = Class.new do
      def hello(arg = 42)
        raise RuntimeError, 'hello' if arg != 42
      end
    end
    context[:Hello] = klass.new
    hi = context.eval "( function hi(arg) { Hello.hello(arg); } )"
    begin
      hi.call(24)
    rescue => e
      e.should be_a Nashorn::JSError
      e.value.should_not be nil
      # Java::JdkNashornInternalObjects::NativeTypeError
      # e.value.should be_a Nashorn::Ruby::Object
      # e.value(true).should be_a RuntimeError # unwraps ruby object
      # prints the original message (beyond [ruby RuntimeError]) :
      e.message.should =~ /TypeError: .* has no such function \"hello\"/
    else
      fail "expected to rescue"
    end
    #     Nashorn::JSError:
    #       jdk.nashorn.internal.objects.NativeTypeError@52719fb6
    #     # <<eval>>.hi(<eval>:1)
    #     # <jdk/nashorn/internal/scripts/<eval>>.hi(jdk/nashorn/internal/scripts/<eval>:1)
    #     # ./lib/nashorn/ext.rb:157:in `call'
    #     # ./spec/nashorn/error_spec.rb:179:in `(root)'
  end

end
