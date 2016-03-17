# load ExecJS with an available Nashorn runtime!

require 'execjs/runtimes' # only require 'execjs' triggers auto-detect

module ExecJS
  if const_defined?(:NashornRuntime)
    warn "ExecJS::NashornRuntime exists, you probably want to avoid loading #{__FILE__}"
  end

  require 'nashorn/execjs/runtime'

  unless at = Runtimes.runtimes.find { |runtime| runtime.is_a?(ExecJS::NashornRuntime) }
    at = Runtimes.runtimes.index(RubyRhino) if const_defined?(:RubyRhino)
    Runtimes.runtimes.insert (at || 0), ExecJS::NashornRuntime.new
  end
end