require File.expand_path('spec_helper', File.dirname(__FILE__))

describe Nashorn do

  it 'allows to eval js on Nashorn' do
    expect( Nashorn.eval '"4" + 2' ).to eql '42'
    expect( Nashorn.eval_js 'true + 10' ).to eql '11'
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
