require File.expand_path('../spec_helper', File.dirname(__FILE__))

module NashornHelpers

  module_function

  def add_prototype_key(hash, recurse = false)
    hash['prototype'] ||= {}
    hash.keys.each do |key|
      val = hash[key] unless key == 'prototype'
      add_prototype_key(val, recurse) if val.is_a?(Hash)
    end if recurse
  end

end

shared_examples_for 'JSObject', :shared => true do

  it "acts like a hash" do
    @object['foo'] = 'bar'
    @object['foo'].should == 'bar'
  end

#  it "might be converted to a hash with string keys" do
#    @object[42] = '42'
#    @object[:foo] = 'bar'
#    expect = @object.respond_to?(:to_h_properties) ? @object.to_h_properties : {}
#    @object.to_h.should == expect.merge('42' => '42', 'foo' => 'bar')
#  end

  it "yields properties with each" do
    @object['1'] = 1
    @object['3'] = 3
    @object['2'] = 2
    @object.each do |key, val|
      case key
        when '1' then val.should == 1
        when '2' then val.should == 2
        when '3' then val.should == 3
      end
    end
  end

end

describe "JS Array" do

  before do
    @object = Nashorn.eval_js '[ 1, 2, 3 ]'
  end

  it_should_behave_like 'JSObject'

  it "converts toString" do
    @object.to_s.should == '{"0"=>1, "1"=>2, "2"=>3}'
  end

  it "converts toString" do
    @object.getDefaultValue(nil).should == '1,2,3'
  end

  it 'routes rhino methods' do
    @object.proto.should_not be nil
    @object.class_name.should == 'Array'
  end

  it 'raises on missing method' do
    lambda { @object.aMissingMethod }.should raise_error(NoMethodError)
  end

  it 'puts JS property' do
    @object.hasMember('foo').should == false
    @object.foo = 'bar'
    @object.hasMember('foo').should == true
  end

  it 'gets JS property' do
    @object.put('foo', 42)
    @object.foo.should == 42
  end

end

describe "JS Object" do

  before do
    @object = Nashorn.eval_js 'Object.create({})'
  end

  it_should_behave_like 'JSObject'

  it 'raises on missing method' do
    lambda { @object.aMissingMethod }.should raise_error(NoMethodError)
  end

  it 'puts JS property' do
    @object.hasMember('foo').should == false
    @object.foo = 'bar'
    @object.hasMember('foo').should == true
  end

  it 'gets JS property' do
    @object.put('foo', 42)
    @object.foo.should == 42
  end

#  it 'is == to an empty Hash / Map' do
#    ( @object == {} ).should be true
#    ( @object == java.util.HashMap.new ).should be true
#  end
#
#  it 'is === to an empty Hash' do
#    ( @object === {} ).should be true
#  end

  it 'is eql? to an empty Hash / Map' do
    ( @object.eql?( {} ) ).should be true
    ( @object.eql?( java.util.HashMap.new ) ).should be true
  end

#  it 'is eql? to another native object' do
#    object = @context.newObject(scope)
#    ( @object.eql?( object ) ).should be true
#    ( object.eql?( @object ) ).should be true
#    ( @object == object ).should be true
#    ( object === @object ).should be true
#  end

#  it 'objects with same values are equal' do
#    #object1 = @object; object1['foo'] = 'bar'; object1['answer'] = 42
#    #object2 = Nashorn.eval_js '({ foo: "bar", answer: 42 })'
#    Nashorn::Context.open do |js|
#      object1 = js.eval '({})'
#      object1['foo'] = 'bar'; object1['answer'] = 42
#      object2 = js.eval '({ foo: "bar", answer: 42 })'
#
#      ( object1 == object2 ).should be true
#      ( object1.eql?( object2 ) ).should be true
#    end
#  end

end
