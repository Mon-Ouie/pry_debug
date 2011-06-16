# PryDebug

PryDebug is a pure-ruby debugger, It simply relies on ``set_trace_func`` and
uses Pry (an alternative to IRB) to evaluate code on breakpoints. This means you
have complete access to local variables (you can even change them!), and can get
any information you want using methods and Pry's commands (find out the value of
an instance variable, for example).

If you wonder why using a debugger: how often have you written things like this?

```ruby
puts "HERE!!!"

# add as many variables as needed until you find the source of the issue.
p :foo => foo, :bar => bar, :baz => baz, :self => self
```

Adding a breakpoint on that line would tell you whether it was executed and let
you see the value of all those variables and all the other without running your
code again.

## Installation

```
gem install pry_debug
```

## Example

Just use the ``pry_debug`` executable, configure the debugger (add breakpoints,
...) and type ``run``.

```
$ pry_debug file.rb
debugged file set to test_debug.rb
pry(main)> b Foo.foo
addded breakpoint 0 at Foo.foo
pry(main)> r
reached breakpoint 0 at Foo.foo

From: /home/kilian/code/pry_debug/test_debug.rb @ line 2 in Class#foo:

     1: class Foo
 =>  2:   def self.foo
     3:     a, b, c = 1, 2, 3
     4:     @foo = a + b + c
     5:   end
     6:
     7:   def initialize(name)
pry(Foo):1> n
stepped at /home/kilian/code/pry_debug/test_debug.rb:3

From: /home/kilian/code/pry_debug/test_debug.rb @ line 3 in Class#foo:

     1: class Foo
     2:   def self.foo
 =>  3:     a, b, c = 1, 2, 3
     4:     @foo = a + b + c
     5:   end
     6:
     7:   def initialize(name)
     8:     @name = name
pry(Foo):2> n
stepped at /home/kilian/code/pry_debug/test_debug.rb:4

From: /home/kilian/code/pry_debug/test_debug.rb @ line 4 in Class#foo:

     1: class Foo
     2:   def self.foo
     3:     a, b, c = 1, 2, 3
 =>  4:     @foo = a + b + c
     5:   end
     6:
     7:   def initialize(name)
     8:     @name = name
     9:   end
pry(Foo):3> p a
1
=> 1
pry(Foo):3> ls -i
Instance variables: []
```

## Features

### Break on a line

That's quite an important feature: just ``b file.rb:line`` to break whenever
that line gets executed. Notice you can pass file.rb, path/to/file.rb, or
/full/path/to/file.rb to refer to the same file.

It will run Pry once the breakpoint is reached. When you're done, just type
``c`` to continue.

Breakpoints can be listed and removed whenever Pry is running:

```
pry(Foo):3> b test_debug.rb:10
added breakpoint 1 at test_debug.rb:10
pry(Foo):3> bl
breakpoint 0 at Foo.foo
breakpoint 1 at test_debug.rb:10
pry(Foo):3> d 0
breakpoint 0 deleted
pry(Foo):3> bl
breakpoint 1 at test_debug.rb:10
```

(You can use breakpoint instead of b, breakpoint-list instead of bl, delete
or del instead of d, and continue instead of c; I'm sure most people can't stand
typing the full command names, though)

### Break on a method

Often, you just want to break when a method gets called. Surely you can find the
location of a method in your code most of the time, but that won't work for
C-defined methods, and it is more work than just typing the name of the method,
isn't it?

```
pry(Foo):3> b SomeClass#some_method
addded breakpoint 2 at SomeClass#some_method
```

SomeClass#some_method is used to break on the instance method ``some_method`` of
the class SomeClass. Both ``SomeClass.some_method`` and
``SomeClass::some_method`` will break on a class method.

Note that, due to implementation details, it is currently hard for PryDebug to
identify that some call to Class#new was in fact a call to Foo.new. It still can
find what was called in most other cases.

### Conditional breakpoints

You may want a breakpoint to be run only when a particular condition is met. You
can add a condition to the breakpoint using ``cond breakpoint_id some code``,
where some code will get run every time the breakpoint is reached. If it
evaluated to nil or false, then PryDebug won't actually stop at that
point. Conditions can also be removed using ``uncond breakpoint_id``.

```
pry(Foo):3> b foo.rb:15
added breakpoint 3 at foo.rb:15
pry(Foo):3> cond 3 @array.size > 10
condition set to @array.size > 10
pry(Foo):3> bl
breakpoint 3 at foo.rb:15 (if @array.size > 10)
```

(Beware, exceptions in conditions are silently ignored)

### Step and next

Breaking at a given place is sometimes not enough. Sometimes, it is useful to
execute each line to find out what changed. That's what the ``step`` command is for:
it makes the debugger execute code until the next line before breaking. You can
also use ``step`` instead of ``run``. It will then break on the first line of
your code.

``next`` is a similar command, that will break on the next line in the same
file (though it would ideally break on the next line in the same method instead
of stepping into it if it is defined in the same file).

### Exceptions

You don't need to do anything to benefit from this feature: whenever an
exception isn't rescued, PryDebug will rescue it and bring you back to the place
where it occured so you can find out why it was raised:

```
unrescued exception: RuntimeError: foo
returning back to where the exception was raised

From: /home/kilian/code/pry_debug/test_debug.rb @ line 22 in Object#N/A:

    17:
    18: 100.times.map do |n|
    19:   n * 2
    20: end
    21:
 => 22: raise "foo"
    23:
    24: __END__
    25: b Foo.foo
    26: b Class#inherted
    27: b FooBar.jump
pry(main):3>
```

### Break on raise

This is disabled by default because it is annoying in code where an exception
being raised and then rescued is normal. It can still be helpful: once enabled,
raising an exception causes PryDebug to stop. This can be toggled using the
``bor`` (``break-on-raise``) command.

```
pry(main):4> bor
break on raise enabled
pry(main):4> r
exception raised: RuntimeError: foo

From: /home/kilian/code/pry_debug/test_debug.rb @ line 22 in Object#N/A:

    17:
    18: 100.times.map do |n|
    19:   n * 2
    20: end
    21:
 => 22: raise "foo"
    23:
    24: __END__
    25: b Foo.foo
    26: b Class#inherted
    27: b FooBar.jump
pry(main):5>
```

### Start in an existing program

Instead of starting your program from PryDebug, you can start PryDebug from your
program. In this case, it won't handle unrescued exceptions automatically,
though.

```ruby
require 'pry_debug'
PryDebug.start(false) # true makes PryDebug load its own file

# you can make it handle exceptions yourself (or break-on-raise instead):
begin
  # ...
rescue SystemExit
  # nothing
rescue Exception => ex
  # PryDebug can still be started

  if binding = PryDebug.context_of_exception(ex)
    PryDebug.start_pry binding
  else
    PryDebug.start_pry ex
  end
end
```

### Threads

It is completely possible you will want to use PryDebug in code that uses
Thread. PryDebug will ensure that only one thread uses Pry. It will also keep
information about breakpoints and stepping on a thread basis, to avoid
unexpected and undetermined results.
