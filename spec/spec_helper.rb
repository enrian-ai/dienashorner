require 'nashorn'
require 'nashorn/rhino'

begin
  require 'mocha/api'
rescue LoadError
  require 'mocha'
end

=begin
require 'redjs'

module RedJS
  Context = Rhino::Context
  Error = Rhino::JSError
end
=end

module Nashorn
  module SpecHelpers

    def context_factory
      @context_factory ||= Nashorn::ContextFactory.new
    end

    def context
      @context || context_factory.call { |ctx| @context = ctx }
      @context
    end

  end
end

RSpec.configure do |config|
  config.filter_run_excluding :compat => /(0.5.0)|(0.6.0)/ # RedJS
  config.include Nashorn::SpecHelpers
  config.deprecation_stream = 'spec/deprecations.log'
end
