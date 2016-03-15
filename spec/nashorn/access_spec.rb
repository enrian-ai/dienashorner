require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Nashorn::Ruby::AttributeAccess do

  before(:all) do
    Nashorn::Ruby.access = Nashorn::Ruby::AttributeAccess.new
  end

  after(:all) do
    Nashorn::Ruby.access = nil
  end

  class Meh

    attr_reader :anAttr0
    attr_accessor :the_attr_1

    def initialize
      @anAttr0 = nil
      @the_attr_1 = 'attr_1'
      @an_attr_2 = 'attr_2'
    end

    def theMethod0; @theMethod0; end

    def a_method1; 1; end

    def the_method_2; '2'; end

  end

  it "gets methods and instance variables" do
    rb_object = Nashorn::Ruby::Object.wrap Meh.new

    rb_object.get('anAttr0', nil).should be_nil
    rb_object.get('the_attr_1', nil).should == 'attr_1'

    # rb_object.get('an_attr_2', nil).should be(Rhino::JS::Scriptable::NOT_FOUND) # no reader
    rb_object.get('an_attr_2', nil).should be nil

    [ 'theMethod0', 'a_method1', 'the_method_2' ].each do |name|
      rb_object.get(name, nil).should be_a(Nashorn::Ruby::Function)
    end

    # rb_object.get('non-existent-method', nil).should be(Rhino::JS::Scriptable::NOT_FOUND)
    rb_object.get('non-existent-method', nil).should be nil
  end

  it "has methods and instance variables" do
    rb_object = Nashorn::Ruby::Object.wrap Meh.new

    rb_object.has('anAttr0', nil).should be_true
    rb_object.has('the_attr_1', nil).should be_true
    rb_object.has('an_attr_2', nil).should be_false # no reader nor writer

    [ 'theMethod0', 'a_method1', 'the_method_2' ].each do |name|
      rb_object.has(name, nil).should be_true
    end

    rb_object.has('non-existent-method', nil).should be_false
  end

  it "puts using attr writer" do
    start = mock('start')
    start.expects(:put).never
    rb_object = Nashorn::Ruby::Object.wrap Meh.new

    rb_object.put('the_attr_1', start, 42)
    rb_object.the_attr_1.should == 42
  end

  it "might set access as a symbol" do
    prev_access = Nashorn::Ruby::access # Rhino::Ruby::Scriptable.access
    module FooAccess; end # backward compatibility
    class Foo2Access; end

    begin

      Nashorn::Ruby::access = nil
      lambda {
        Nashorn::Ruby::access = :attribute
      }.should_not raise_error
      Nashorn::Ruby::access.should be_a Nashorn::Ruby::AttributeAccess

      Nashorn::Ruby::access = nil
      lambda {
        Nashorn::Ruby::access = :attribute_access
      }.should_not raise_error
      Nashorn::Ruby::access.should be_a Nashorn::Ruby::AttributeAccess

      lambda {
        Nashorn::Ruby::access = :foo
      }.should_not raise_error
      Nashorn::Ruby::access.should == FooAccess

      lambda {
        Nashorn::Ruby::access = :foo2
      }.should_not raise_error
      Nashorn::Ruby::access.should be_a Foo2Access

      lambda {
        Nashorn::Ruby::access = :bar
      }.should raise_error

    ensure
      Nashorn::Ruby::access = prev_access # Rhino::Ruby::Scriptable.access = prev_access
    end
  end

  it "is backward compatibile with the 'module' way" do
    # Rhino::Ruby::AttributeAccess.respond_to?(:has).should be true
    # Rhino::Ruby::AttributeAccess.respond_to?(:get).should be true
    # Rhino::Ruby::AttributeAccess.respond_to?(:put).should be true

    Nashorn::Ruby::access = Nashorn::Ruby::AttributeAccess

    rb_object = Nashorn::Ruby::Object.wrap Meh.new
    rb_object.get('theMethod0', nil).should be_a(Nashorn::Ruby::Function)
    rb_object.has('non-existent-method', nil).should be false
  end

end
