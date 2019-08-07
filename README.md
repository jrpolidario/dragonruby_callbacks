# [Unofficial] DragonRuby Callbacks

* A simple callback plug-n-play DSL for any Class heavily influenced by [Rails' ActiveSupport::Callbacks](https://api.rubyonrails.org/classes/ActiveSupport/Callbacks.html)
* Allows `before` and `after` hooks for calls to any method. TODO :`around`
* Focuses on performance (not saying though it already is!! Performance tests still need to be done :)
* Probably gonna expand as I need it to be, as my game grows.

### Dependencies
* DragonRuby's current ruby version: 1.9
* No-strong dependency to DragonRuby (yet or maybe never?), so you can use this in your own non-DrargonRuby projects

### Usage (Motivation)

* In DragonRuby, I wanted my Sprite objects to automatically adjust the position of the sprite on the page when my character moves on the world (because the camera / view is following my character centered on the screen). I do not want to keep myself worrying about every update / change that needs to be done. And so, I wrote this small module to be used like the following (for example in my case)

```ruby
# assuming you copy callbacks.rb into your /app folder
require 'app/callbacks.rb'

# basically this is just anything that can be drawn on the screen that has `x`, `y`, `width`, `height`
# this class expands on DragonRuby's fast "class" rendering of sprites
# for more info see dragonruby's samples/14_sprite_limit source code
class Sprite
  # You'll need to include this to any class that you want to have callbacks available
  includes Callback

  # you only are gonna be "reading" these values, that's why I changed this from `attr_accessor`
  attr_reader :sprite, :x, :y, :r, :g, :b, :alpha, :speed_x, :speed_y, :height, :image, :width, :height, :rotation

  # now for "writing" values, instead of the default `attr_writer` generated-methods,
  # my Callbacks module provides the following method which just basically wraps the
  # normal `attr_writer` setter methods with a `run_callbacks do ... end` block
  # which you'd want to do in order to perform "something" if the value has been changed.
  attr_writer_with_callbacks :sprite, :x, :y, :r, :g, :b, :alpha, :speed_x, :speed_y, :height, :image, :width, :height, :rotation

  # this just basically means if game_x changes (i.e another Monster sprite on the screen moves),
  # then update that monster sprite's screen coordinates with respect to camera
  after :game_x=, :update_screen_coordinates_with_respect_to_camera
  after :game_y=, :update_screen_coordinates_with_respect_to_camera

  # for flexibility, you can also do "block" mode:
  # after :game_x= do |arg|
  #   update_screen_coordinates_with_respect_to_camera
  # end

  def initialize(opts = {})
    @game_x = opts.fetch(:game_x)
    @game_y = opts.fetch(:game_y)

    update_screen_coordinates_with_respect_to_camera

    @width = opts.fetch(:width)
    @height = opts.fetch(:height)
    @image = opts.fetch(:image)
    @rotation = opts[:rotation] || 0
    @alpha = opts.fetch(:alpha)
    @r = opts.fetch(:r)
    @g = opts.fetch(:g)
    @b = opts.fetch(:b)

    @sprite = [@x, @y, @width, @height, @image, @rotation, @alpha, @r, @g, @b]
  end

  def update_screen_coordinates_with_respect_to_camera
    # game_x and game_y refers to actual-world coordinates
    # while x and y refers to screen coordinates (for rendering)
    # in this example I have a transparent "solid" rectangular camera created in `def tick`
    # which freely follows the player as he/she moves the world
    @x = @game_x - $gtk.args.state.camera.game_x
    @y = @game_y - $gtk.args.state.camera.game_y
  end
end
```

### DSL

#### Class Methods

* `before(method_name, callback_method_name = nil, &callback_proc)`

    * This means that before `method_name` method runs, run `callback_method_name` first (or run the block first if block is supplied instead of `callback_method_name`)

* `before!(method_name, callback_method_name = nil, &callback_proc)`

    * Sometimes, I noticed that I forgot to define `method_name`! This is just basically like `before` except that this raises an error if `method_name` is not defined or not yet defined (at the time `before!` is called)
    * This works perfect in conjunction with `attr_writer_with_callbacks` as after this line, I can now safely call `before!` or `after!` because I am sure that I already defined everything I needed to define. If I forgot something then, this `before!` would raise an error and alert me, and not silently failing. Helps debugging :) this is one-line slower than `before` though.

* `after(method_name, callback_method_name = nil, &callback_proc)`

    * same as `before` above, but just that the callback_method_name or callback_proc is called after method_name

* `after!(method_name, callback_method_name = nil, &callback_proc)`

    * same as `before` above, but just that the callback_method_name or callback_proc is called after method_name

* `attr_writer_with_callbacks(*instance_variable_names)`

    * Similar to ruby's `attr_writer` except only that the defined setter method is wrapped with a `run_callbacks` block:

```ruby
class Foo
  include Callbacks

  attr_writer_with_callbacks :bar

  # ^ above is just exactly the same as the code below

  # def bar=(arg)
  #   run_callbacks arg do
  #     @bar = arg
  #   end
  # end
```

* `attr_reader_with_callbacks(*instance_variable_names)`

    * Similar to ruby's `attr_reader` except only that the defined getter method is wrapped with a `run_callbacks` block:
    * DON'T USE THIS for instance variables that you are gonna be "reading" or calling in each tick! ... as this will slow down your app (in varying degrees). Better just eager-evaluate the value and set or cache it somehow deterministically on write / changes (to its value dependencies)
    # therefore, probably you'd want to use attr_writer_with_callbacks to each of this value's dependency attributes instead to cache the value
    # i.e. don't use this for the `:sprite` instance variable! as each call to `.sprite` will run each defined callbacks. Imagine if you have 1000 Sprite objects each on the page each of which `.sprite` is called!

```ruby
class Foo
  include Callbacks

  attr_reader_with_callbacks :bar

  # ^ above is just exactly the same as the code below

  # def bar
  #   run_callbacks do
  #     @bar
  #   end
  # end
```

* `attr_accessor_with_callbacks(*instance_variable_names)`

    * This just combines both `attr_reader_with_callbacks` and `attr_writer_with_callbacks` (see them above).

#### Instance Methods

* `run_callbacks(method_name, *args) do ... end`

    * runs all defined callbacks for `method_name`, starting by running first all `before_callbacks`, then running the inside of the `do ... end` block, then finally running all `after_callbacks`.
    * `*args` will be yielded to the block as arguments

```ruby
class Foo
  include Callbacks

  before :x do
    puts 'before x is called!'
  end

  before :y do |arg|
    puts "before y is called with argument: #{arg}"
  end

  # __method__ is a ruby thing that just returns the current method
  # so for `def x`, `__method__` then has the value of `:x`

  def x
    run_callbacks __method__ do
      puts 'x is called!'
    end
  end

  def y(arg)
    run_callbacks __method__, arg do
      puts 'y is called!'
    end
  end
end

foo = Foo.new
foo.x
# => before x is called!
# => x is called!
foo.y('somevalue')
# => before y is called with argument: somevalue
# => y is called!
```

### Test

* open terminal and `cd` into this directory, and then run `ruby ./callbacks_test.rb`

### TODO
* should DragonRuby upgrade ruby version into 2.0, use `.prepend` in conjuction with `super` instead instead to have cleaner callbacks hook methods. Won't need to call `run_callbacks` explicitly anymore in custom methods.
* when the need already arises, implement `around` (If you have ideas or want to help this part, please feel free to fork or send me a message! :)
