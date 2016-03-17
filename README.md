# dia nashorner

Embed the ~~Mozilla Rhino~~ Nashorn JavaScript interpreter into Ruby.

Nashorn JS engine is available with Java 8 installs (try `jjs -v`).


### Requirements

Java **>= 8**

`jruby -S gem install dienashorner` # make sure you have JRuby >= 1.7.x


### Features

* Evaluate JavaScript bits from the Ruby side
* Embed Ruby objects into the JavaScript world

```ruby
require 'nashorn'
```

* evaluate some simple JavaScript
```ruby
Nashorn.eval 'true + 100' #=> 101
Nashorn.eval_js '"4" + 2' #=> "42"
```

```ruby
include Nashorn
eval_js "'1' + '' * 2" #=> "10"
```

* if you need more control, use a `Context`
```ruby
Nashorn::Context.open do |js|
  js['foo'] = "bar"
  js.eval('foo') # => "bar"
end
```

* evaluate a Ruby function from JavaScript
```ruby
Nashorn::Context.open do |js|
  js['say'] = lambda { |word, times| word * times }
  js.eval("say('Szia', 3) + '!'") #=> SziaSziaSzia!
end
```

* embed a Ruby object into your JavaScript environment
```ruby
class MyMath
  def plus(a, b); a + b + 1 end
end

Nashorn::Context.open do |js|
  js["math"] = MyMath.new
  js.eval("math.plus(20, 21)") #=> 42
end
```

* make a Ruby object a JavaScript (global) environment
```ruby
math = MyMath.new
Nashorn::Context.open(:with => math) do |js|
  js.eval("plus(20, 21)") #=> 42
end
```


### Context Options

Mostly the same as with **`jjs`** e.g. `Nashorn::Context.open(:strict => true)`.


### Loading .js

```ruby
  File.open('___.js') { |file| eval_js file }
```

```ruby
  Nashorn::Context.open { |js| js.load('___.js') }
```


### Configurable Ruby access

Ported over from [Rhino](https://github.com/cowboyd/therubyrhino#configurable-ruby-access)

<!--
By default accessing Ruby objects from JavaScript is compatible with *therubyracer*:
https://github.com/cowboyd/therubyracer/wiki/Accessing-Ruby-Objects-From-JavaScript

Thus you end-up calling arbitrary no-arg methods as if they were JavaScript properties,
since instance accessors (properties) and methods (functions) are indistinguishable :

```ruby
Nashorn::Context.open do |context|
  context['Time'] = Time
  context.eval('Time.now')
end
```

However, you can customize this behavior and there's another access implementation
that attempts to mirror only attributes as properties as close as possible:
```ruby
class Foo
  attr_accessor :bar

  def initialize
    @bar = "bar"
  end

  def check_bar
    bar == "bar"
  end
end

Rhino::Ruby::Scriptable.access = :attribute
Rhino::Context.open do |context|
  context['Foo'] = Foo
  context.eval('var foo = new Foo()')
  context.eval('foo.bar') # get property using reader
  context.eval('foo.bar = null') # set property using writer
  context.eval('foo.check_bar()') # called like a function
end
```

If you happen to come up with your own access strategy, just set it directly :
```ruby
Rhino::Ruby::Scriptable.access = FooApp::BarAccess.instance
```
-->


### Rhino Compatibility

Nashorn was inspired (and crafted) from Rhino a.k.a **therubyrhino** JRuby gem.
Far from being a drop-in replacement although there's `require 'nashorn/rhino'`.


### Less.rb

[Less.rb](https://github.com/cowboyd/less.rb) seems to be working, for now you
will simply need to :`require 'nashorn/rhino/less'` before a `require 'less'`.


### ExecJS

dienashorner gem ships with an [ExecJS][3] compatible runtime, its best to load it
(`require 'nashorn/execjs/load'`) before ExecJS's auto-detection takes place :
```ruby
gem 'execjs', require: false
gem 'dienashorner', platform: :jruby, require: [ 'nashorn/execjs/load', 'execjs' ]
```


### Nashorn

Nashorn JavaScript runtime is part of [OpenJDK][4] (available since 8u40).


## Copyright

Copyright (c) 2016 Karol Bucek. Apache License v2 (see LICENSE for details).

[3]: https://github.com/rails/execjs
[4]: http://openjdk.java.net/projects/nashorn/