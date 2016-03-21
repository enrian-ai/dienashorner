require File.expand_path('spec_helper', File.dirname(__FILE__))

describe Nashorn do

  it 'allows to eval js on Nashorn' do
    expect( Nashorn.eval '"4" + 2' ).to eql '42'
    expect( Nashorn.eval_js 'true + 100' ).to eql 101
  end

  it 'getDefaultValue is used for toString' do
    arr = Nashorn.eval('[ 1, 2 ]')
    expect( arr ).to be_a Nashorn::JS::JSObject
    expect( arr.getDefaultValue(nil) ).to eql '1,2'
    expect( arr.getDefaultValue(java.lang.Number.java_class) ).to eql '1,2'
    expect( arr.getDefaultValue(java.lang.String.java_class) ).to eql '1,2'
  end

  class NashornStub
    include Nashorn

    def do_eval_js str
      eval_js str
    end

  end

  it 'allows to eval js when mixed-in' do
    expect( NashornStub.new.do_eval_js "'1' + '' * 2" ).to eql '10'
  end

end
