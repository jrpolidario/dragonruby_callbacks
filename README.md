# [Unofficial] DragonRuby Callbacks

* A simple callback plug-n-play DSL for any Class heavily influenced by [Rails' ActiveSupport::Callbacks](https://api.rubyonrails.org/classes/ActiveSupport/Callbacks.html)
* Allows `before` and `after` hooks for calls to any method. TODO :`around`
* Supports conditional callbacks
* Focuses on performance (not saying though it already is!! Performance tests still need to be done :)
* Probably gonna expand as I need it to be, as my game grows.

*Version: 0.2.1*

### Dependencies
* [DragonRuby](https://dragonruby.itch.io/)'s current ruby version: 1.9
* No-strong dependency to DragonRuby (yet or maybe never?), so you can use this in your own non-DragonRuby projects

### Usage (Motivation)

* In DragonRuby, I wanted my Sprite objects to automatically adjust the position of the sprite on the screen when my character moves on the world (because the camera / view is following my character centered on the screen). I do not want to keep myself worrying about every update / change that needs to be done. And so, I wrote this small module to be used like the following (for example in my case)

```ruby
# assuming you copy callbacks.rb into your /app folder
require 'app/callbacks.rb'

# basically this is just anything that can be drawn on the screen that has `x`, `y`, `width`, `height`
# this class expands on DragonRuby's fast "class" rendering of sprites
# for more info see dragonruby's samples/14_sprite_limit source code
class Sprite
  # You'll need to include this to any class that you want to have callbacks available
  include Callbacks

  # you only are gonna be "reading" these values, that's why I changed this from `attr_accessor`
  attr_reader :sprite, :x, :y, :r, :g, :b, :alpha, :move_speed, :height, :image, :width, :height, :rotation

  # now for "writing" values, instead of the default `attr_writer` generated-methods,
  # my Callbacks module provides the following method which just basically wraps the
  # normal `attr_writer` setter methods with a `run_callbacks do ... end` block
  # which you'd want to do in order to perform "something" if the value has been changed.
  attr_writer_with_callbacks :sprite, :x, :y, :r, :g, :b, :alpha, :move_speed, :height, :image, :width, :height, :rotation

  # this just basically means if game_x changes (i.e another Monster sprite on the screen moves),
  # then update that monster sprite's screen coordinates with respect to camera
  after :game_x=, :update_screen_coordinates_with_respect_to_camera
  after :game_y=, :update_screen_coordinates_with_respect_to_camera

  # you can add multiple callbacks to a method (callbacks are called sequentially in FCFS order)
  # after :game_x=, :do_something_1
  # after :game_x=, :do_something_2

  # for flexibility, you can also use one or many "block" mode:
  # after :game_x= do |arg|
  #   update_screen_coordinates_with_respect_to_camera
  # end
  # after :game_x= do |arg|
  #   puts 'do something here'
  # end

  def initialize(opts = {})
    @move_speed = opts.fetch(:move_speed)

    update_screen_coordinates_with_respect_to_camera

    @width = opts.fetch(:width)
    @height = opts.fetch(:height)
    @image = opts.fetch(:image)
    @rotation = opts[:rotation] || 0
    @alpha = opts[:alpha]
    @r = opts[:r]
    @g = opts[:g]
    @b = opts[:b]

    @sprite = [@x, @y, @width, @height, @image, @rotation, @alpha, @r, @g, @b]
  end

  def update_screen_coordinates_with_respect_to_camera
    # in this example I have a transparent "solid" rectangular camera created in `def tick`
    # which freely follows the player as he/she moves the world
    @x = @game_x - $gtk.args.state.camera.game_x
    @y = @game_y - $gtk.args.state.camera.game_y
    @sprite.x = @x # @sprite.x is DragonRuby helper method for @sprite[0]
    @sprite.y = @y # @sprite.y is DragonRuby helper method for @sprite[1]
  end
end
```

* ^ all of the above just means that I could do the following

```ruby
args.state.sprites ||= []

if args.state.dooge.nil?
  args.state.dooge = Sprite.new(
    game_x: 50,
    game_y: 75,
    move_speed: 8,
    width: 64,
    height: 64,
    image: 'images/dooge.png'
  )
  args.state.sprites << args.state.dooge
end

if args.state.hooman.nil?
  args.state.hooman ||= Sprite.new(
    game_x: 0,
    game_y: 0,
    move_speed: 5,
    width: 64,
    height: 128,
    image: 'images/hooman.png'
  )
  args.state.sprites << args.state.hooman
end

camera ||= Camera.new

# let's pretend I have a defined control! method that allows key presses (w, s, a, or, d)
# to move hooman
control!(args.state.hooman)

if args.state.hooman.moved?
  # camera follows hooman if hooman moved
  camera.game_x = args.state.hooman.game_x
  camera.game_y = args.state.hooman.game_y
end

# let's just PRETEND on this tick, hooman didn't move (i.e. i didnt press any control key)
# however let's say on this tick dooge is moving towards hooman (i mean because he is dooge)
x_distance_between_hooman_and_dooge = args.state.hooman.game_x - args.state.dooge.game_x
y_distance_between_hooman_and_dooge = args.state.hooman.game_y - args.state.dooge.game_y

distance_to_travel = Math.sqrt(
  (x_distance_between_hooman_and_dooge ** 2) + (y_distance_between_hooman_and_dooge ** 2)
)

x_move_speed_towards_hooman = x_distance_between_hooman_and_dooge / (distance_to_travel / args.state.dooge.move_speed)
y_move_speed_towards_hooman = y_distance_between_hooman_and_dooge / (distance_to_travel / args.state.dooge.move_speed)

# because dooge.game_x= and dooge.game_y= have after callbacks calling update_screen_coordinates_with_respect_to_camera
# then dooge's x and y values on the screen would be automatically updated
dooge.game_x += x_move_speed_towards_hooman
dooge.game_y += y_move_speed_towards_hooman

# render all sprites
args.outputs.sprites << args.state.sprites.map(&:sprite)
```

*P.S. Above example just only shows the usage of callbacks when a Sprite's `game_x` or `game_y` changes, but for a more complete example, you'd also want to have callbacks when the Camera's `game_x` or `game_y` changes, because you'd want to update all the Sprites coordinates like below:*

```ruby
class Camera
  include Callbacks
  # ...
  attr_writer_with_callbacks :game_x, :game_y #, ...

  # assuming that you only have one Camera instance as say args.state.camera,
  # this means that whenever the Camera moves (`game_x` or `game_y` changes), then
  # all sprites screen coordinates are updated accordingly.
  [:game_x=, :game_y=].each do |method_name|
    after method_name do |arg|
      $gtk.args.state.sprites.map(&:update_screen_coordinates_with_respect_to_camera)
    end
  end
end
```

### Pseudo-Skipping Callbacks

* via Ruby's [`instance_variable_get`](https://ruby-doc.org/core-1.9.1/Object.html#method-i-instance_variable_get) and [`instance_variable_set`](https://ruby-doc.org/core-1.9.1/Object.html#method-i-instance_variable_set)

```ruby
class Foo
  include Callbacks

  attr_writer_with_callbacks :bar

  before :bar= do |arg|
    puts 'before bar= is called!'
  end
end

foo = Foo.new

# normal way (callbacks are called):
foo.bar = 'somevalue'
# => 'before_bar= is called!'

# but to "pseudo" skip all callbacks, and directly manipulate the instance variable value:
foo.instance_variable_set(:@bar, 'somevalue')
```

* At the moment, I am not compelled (yet?) to fully support skipping callbacks because I do not want to pollute the DSL and I do not find myself yet needing such behaviour, because the callbacks are there for "integrity". If I really want the callbacks conditional, I'll just use the conditional argument. See below.

### Conditional Callbacks

```ruby
class Monster
  include Callbacks

  attr_reader :hp
  attr_writer_with_callbacks :hp

  after :hp=, :despawn, if: lambda { |arg| @hp == 0 }

  # above is just equivalently:
  # after :hp= do |arg|
  #   despawn if @hp == 0
  # end

  def despawn
    puts 'despawning!'
    # do something here, like say removing the Monster from the world
  end
end

monster = Monster.new
monster.hp = 5
monster.hp -= 1 # 4
monster.hp -= 1 # 3
monster.hp -= 1 # 2
monster.hp -= 1 # 1
monster.hp -= 1 # hp is now 0, so despawn!
# => despawning!
```

### DSL

#### Class Methods

* `before(method_name, callback_method_name = nil, options = {}, &callback_proc)`

    * This means that before `method_name` method runs, run `callback_method_name` first (or run the block first if block is supplied instead of `callback_method_name`)
    * Conditional callback via `options[:if]` is supported; see [conditional callbacks](#conditional-callbacks) above.

* `before!(method_name, callback_method_name = nil, &callback_proc)`

    * Sometimes, I noticed that I forgot to define `method_name`! This is just basically like `before` except that this raises an error if `method_name` is not defined or not yet defined (at the time `before!` is called)
    * This works perfect in conjunction with `attr_writer_with_callbacks` as after this line, I can now safely call `before!` or `after!` because I am sure that I already defined everything I needed to define. If I forgot something then, this `before!` would raise an error and alert me, and not silently failing. Helps debugging :)

* `after(method_name, callback_method_name = nil, options = {}, &callback_proc)`

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
  #   run_callbacks :bar=, arg do
  #     @bar = arg
  #   end
  # end
end
```

* `attr_reader_with_callbacks(*instance_variable_names)`

    * Similar to ruby's `attr_reader` except only that the defined getter method is wrapped with a `run_callbacks` block:
    * DON'T USE THIS for instance variables that you are gonna be "reading" or calling in each tick! ... as this will slow down your app (in varying degrees). Better just eager-evaluate the value and set or cache it somehow deterministically on write / changes (to its value dependencies)
    * therefore, probably you'd want to use attr_writer_with_callbacks to each of this value's dependency attributes instead to cache the value
    * i.e. don't use this for the `:sprite` instance variable! as each call to `.sprite` will run each defined callbacks. Imagine if you have 1000 Sprite objects on the screen each of which `.sprite` is called!

```ruby
class Foo
  include Callbacks

  attr_reader_with_callbacks :bar

  # ^ above is just exactly the same as the code below

  # def bar
  #   run_callbacks :bar do
  #     @bar
  #   end
  # end
end
```

* `attr_accessor_with_callbacks(*instance_variable_names)`

    * This just combines both `attr_reader_with_callbacks` and `attr_writer_with_callbacks` (see them above).

* `before_callbacks`

    * hash of array of all defined before callbacks

* `after_callbacks`

    * hash of array of all defined after callbacks

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
* should DragonRuby upgrade ruby version into 2.0, use `.prepend` in conjuction with `super` instead to have cleaner callbacks hook methods. Won't need to call `run_callbacks` explicitly anymore in custom methods.
* when the need already arises, implement `around` (If you have ideas or want to help this part, please feel free to fork or send me a message! :)

### Changelog

* v0.2.1 (2019-08-09)

    * Fixed syntax errors for ruby 1.9.3; Fixed not supporting subclasses of Proc, String, or Symbol

* v0.2 (2019-08-08)

    * Supported [conditional callbacks](#conditional-callbacks) with `:if`

* v0.1 (2019-08-07)

    * Done all
