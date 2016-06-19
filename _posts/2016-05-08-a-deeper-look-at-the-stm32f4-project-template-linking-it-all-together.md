---
layout: post
tags:   embedded iot st microcontrollers project-template linker
date:   2016-05-08 17:40:00 +10:00
title: "A deeper look at the STM32F4 project template: linking it all together"
comments: true
---

[Last time](/2016/04/17/a-deeper-look-at-the-stm32f4-project-template-getting-things-started/), we saw how the microcontroller starts up and begins running our code, and I mentioned that the linker script is responsible for making sure the right stuff ends up in the right place in our firmware binary. So today I'm going to take a closer look at the [linker script](https://github.com/charleskorn/stm32f4-project-template/blob/master/lib/stm32f4xx/src/stm32f407vg.ld) and how it makes this happen.

And like last time, while I'll be using the code in the project template as an example, the concepts are broadly applicable to most microcontrollers. 

# What does the linker do again?
Before we jump into the linker script, it's worthwhile going back and reminding ourselves what the linker's job is. It has two main roles:

1. Combining all the various object files and statically-linked libraries, resolving any references between them so that symbols (eg. `printf`) can be turned into memory locations in the final executable

2. Producing an executable in the format required for the target environment (eg. [ELF](https://en.wikipedia.org/wiki/Executable_and_Linkable_Format) for Linux and some embedded systems, an `.exe` for Windows, [Mach-O](https://en.wikipedia.org/wiki/Mach-O) for OS X)

In order to do the second part above, it needs to know about the target environment. In particular, it needs to know where different parts of the code need to reside in the binary, and where they will end up in memory. This is where the linker script comes in. It takes the different parts of your program (arranged into groups called sections) and tells the linker how to arrange them. The linker then takes this arrangement and produces a binary in the required format, with all symbols replaced with their memory locations. 

(Dynamic linking, where some libraries aren't combined into the binary but are instead loaded at runtime, is a bit different. I won't cover it here because it's less common in embedded software.)

By default, the linker will use a standard linker script appropriate for your platform -- so if you're building an application for OS X, then the default linker script will be one appropriate for OS X, for example. However, because there are so many microcontrollers out there, each with their own memory layout, there is no one standard linker script that could just work for every possible target. So we have to provide our own. Many manufacturers provide sample linker scripts for a variety of toolchains, so you usually don't have to write it yourself. However, as you're about to see, they're not complicated.

# What does a linker script look like?
The best way to understand how a linker script works is to work through an example and explain what's going on. So I'm going to do just that with the one I'm using in the project template.

Just like for the startup assembly code, I've used [Philip Munts' example linker script](http://tech.munts.com/MCU/Frameworks/ARM/stm32f4/) in the project template. (The startup assembly code and linker script are fairly closely related, as you'll see in a minute.)

## Memory and some constants

The first part defines what memory blocks are available:

{% highlight ld %}
MEMORY
{
  flash (rx): ORIGIN = 0x08000000, LENGTH = 1024K
  ram (rwx) : ORIGIN = 0x20000000, LENGTH = 128K
  ccm (rwx) : ORIGIN = 0x10000000, LENGTH = 64K
}
{% endhighlight %}

This is fairly self-explanatory. We have three different types of memory available on our microcontroller, either read-only executable (`rx`) flash ROM, or read-write executable (`rwx`) RAM and [core-coupled memory (CCM)](http://sigalrm.blogspot.com.au/2013/12/using-ccm-memory-on-stm32.html). Each has a particular memory location and size, given by `ORIGIN` and `LENGTH`, respectively. These values are shown on the memory map diagram in the [STM32F405 / STM32F407 datasheet](http://www2.st.com/content/ccc/resource/technical/document/datasheet/ef/92/76/6d/bb/c2/4f/f7/DM00037051.pdf/files/DM00037051.pdf/jcr:content/translations/en.DM00037051.pdf).

Next up, we define some symbols, some of which we used in the startup assembly code and some of which are used by library functions:

{% highlight ld %}
__rom_start__   = ORIGIN(flash);
__rom_size__    = LENGTH(flash);
__ram_start__   = ORIGIN(ram);
__ram_size__    = LENGTH(ram);
__ram_end__     = __ram_start__ + __ram_size__;
__stack_end__   = __ram_end__;      /* Top of RAM */
__stack_size__  = 16K;
__stack_start__ = __stack_end__ - __stack_size__;
__heap_start__  = __bss_end__;      /* Between bss and stack */
__heap_end__    = __stack_start__;
__ccm_start__   = ORIGIN(ccm);
__ccm_size__    = LENGTH(ccm);
end             = __heap_start__;
{% endhighlight %}

## Sections

And then we come to the meat of the linker script -- the `SECTIONS` command. As I mentioned before, sections are used to differentiate between different kinds of data so they can be treated appropriately. For example, code has to end up in a executable memory location, while constants can go in a read-only location, so each of these are in different sections. 

Before we get into the details, a quick note on terminology. There are two kinds of sections we talk about when working with the linker:

* Input sections come from the object files we load (usually as the result of compiling our source code), or the libraries we use.
* Output sections are exactly what they sound like -- sections that appear in the output, the final executable.

In most scenarios, you'll start with many different input sections that are then combined into far fewer output sections. 
 
### `.text` section

The first section we define is the `.text` output section. `.text` holds all of the executable code. It also contains any values that can remain in read-only memory, such as constants.

The definition of `.text` in the linker script looks like this:

{% highlight ld %}
  .text : {
    KEEP(*(.startup))         /* Startup code */
    *(.text*)                 /* Program code */
    KEEP(*(.rodata*))         /* Read only data */
    *(.glue_7)
    *(.glue_7t)
    *(.eh_frame)
    . = ALIGN(4);
    __ctors_start__ = .;
    KEEP(*(.init_array))      /* C++ constructors */
    KEEP(*(.ctors))           /* C++ constructors */
    __ctors_end__ = .;
    . = ALIGN(16);
    __text_end__ = .;
  } >flash
{% endhighlight %}

Let's work through this and understand what's going on. `KEEP(*(.startup))` tells the linker that the first thing in the output section should be anything in the `.startup` input section. For example, this includes our startup assembly code. (That's why there's the `.section  .startup, "x"` bit at the start of the assembly code). `KEEP` tells the linker that it shouldn't remove any `.startup` input sections, even if they're unreferenced -- particularly important for the startup code.

Next up is our program code, `*(.text*)`. You'll notice that there are two asterisks: 

* the one before the parentheses means 'include sections that matches the inner pattern from any input file'
* the one near the end is a wildcard -- so any section that starts with `.text` will be included

For comparison, `*(.startup)` means 'include any `.startup` section from any input file'.

We then include some more sections: `.rodata` for read-only data, `.glue_7` and `.glue_7t` to allow ARM instructions to call [Thumb instructions](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0210c/CACBCAAE.html) and vice-versa, and `.eh_frame` to assist in [exception unwinding](http://www.airs.com/blog/archives/460). 

Finally, we set up the global and static variable constructors area. We saw this used in the `call_ctors` / `ctors_loop` part of the startup code.  We define `__ctors_start__` and `__ctors_end__` so that the startup code knows where the list of constructors starts and ends.

You'll notice there's `. = ALIGN(4);` just before this, and `. = ALIGN(16);` just afterwards. `.` refers to the current address, so `. = ALIGN(x)` advances the current address forward until it is a multiple of `x` bytes. (If it's already a multiple of `x`, nothing changes.) This is used to ensure that data is aligned with particular boundaries. For example, if an instruction is 4 bytes long, there might be a requirement that all instructions have to be aligned to 4 byte boundaries. So we can use `. = ALIGN(4);` to ensure that we start in a valid location. (We'll see why `. = ALIGN(16);` and `__text_end__ = .;` are necessary in a second.)

Now that we've finished specifying what needs to go inside the section, we need to tell the linker which memory block to put it in. Given that `.text` just contains read-only instructions and data, we use `>flash` to tell the linker to put `.text` in flash memory.

### `.data` section

That's `.text` sorted, so let's take a look at `.data` next. `.data` contains initial values of mutable global and static values.

This is how it's defined in the linker script: 

{% highlight ld %}
  .data : ALIGN(16) {
    __data_beg__ = .;         /* Used in crt0.S */
    *(.data*)                 /* Initialized data */
    __data_end__ = .;         /* Used in crt0.S */
  } >ram AT > flash
{% endhighlight %}

`.data` is fairly similar to `.text`, with a few small differences used to achieve the one purpose: initialising initial values for global and static variables.

`>ram AT > flash` instructs the linker that the `.data` section should be placed in the `flash` memory block, but that all symbols that refer to anything in it should be allocated in the `ram` memory block. Why? Because `.data` contains just the initial values, and they're not constants -- they're mutable values we can modify in our program. Therefore we need them to be in RAM, not read-only flash. But we can't just set values in RAM directly when we flash our microcontroller, as the only thing we can flash is flash memory. So the solution is to store them in flash, and then as part of the startup code, we copy them into RAM, ready to be modified. 

If you think back to the startup code, you'll remember `copy_data` and `copy_data_loop` were responsible for copying the initial values from flash to RAM. There are a couple of values that the linker script sets so that code knows what to copy, and to where:

* `__text_end__`, which was defined at the end of the `.text` section, gives us the first flash memory location of the `.data` section. Why this is the case might not be clear at first: the `. = ALIGN(16);` advances `.` to the next 16 byte boundary, and then we store that value in `__text_end__`. When the linker comes to `.data`, which is the next section, it starts allocating flash memory locations for `.data` from `__text_end__` onwards, because that is the next available location in flash.
* `__data_beg__` and `__data_end__` give the start and end locations of `.data` in RAM. `ALIGN(16)` in the section definition ensures that the start location is aligned to a 16 byte boundary. 

So `copy_data` follows this pseudocode:

* if `__data_beg__` equals `__data_end__`, there is nothing to initialise, so skip all of this
* otherwise:
	* set `current_text` to `__text_end__` and `current_data` to `__data_beg__`
	* copy the byte at address `current_text` to address `current_data` (X)
	* advance `current_text` and `current_data` each by one
	* if we've reached the end (ie. our updated `current_data` equals `__data_end__`), stop, otherwise go back to (X)

### `.bss` section

Two down, one to go... `.bss` is the last major output section:

{% highlight ld %}
  .bss (NOLOAD) : ALIGN(16) {
    __bss_beg__ = .;          /* Used in crt0.S */
    *(.bss*)                  /* Uninitialized data */
    *(COMMON)                 /* Common data */
    __bss_end__ = .;          /* Used in crt0.S */
  } >ram
{% endhighlight %}

Again, this is a section we've seen references to in the startup code. `zero_bss` and `zero_bss_loop` was the part of startup that sets up any global or static variables that have a zero initial value. You'll remember that rather than storing a whole bunch of zeroes in flash and copying them over, we instead store how many zeroes we need and then initialise that many memory locations to zero when starting up. 

A few different parts combine to produce this result:

* `NOLOAD` specifies that this section should just be allocated addresses in whichever memory block it belongs to, without including its contents in the final executable.
* `>ram` at the end specifies that addresses should be allocated in the RAM memory block.
* We use a similar trick to what we saw in `.data`, where we store the first and last RAM locations of the zero values as `__bss_beg__` and `__bss_end__` respectively. These are then used by the startup code to actually initialise those locations with zeroes.

### `.ARM.extab` and `.ARM.exidx` sections

These are sections that are used for exception unwinding and section unwinding, respectively. [This presentation](https://wiki.linaro.org/KenWerner/Sandbox/libunwind?action=AttachFile&do=get&target=libunwind-LDS.pdf) gives a short overview of the information contained in them and how they're used.

## Entrypoint

Last, but certainly not least, we need to define the entrypoint of the application. This is done with the command `ENTRY(_vectors)`. `_vectors` is the starting point of the exception vector table, which we defined in the startup code. This isn't used by the microcontroller, as it always starts at the same memory address after a reset. However, it's still necessary so that the linker doesn't just optimise everything away as unused code. 

# The end

So that's the linker script... next time we'll take a look at the sample application and how it makes those LEDs blink.

# References
* [`ld` user manual](https://sourceware.org/binutils/docs/ld/index.html)
* [STM32F405 / STM32F407 datasheet](http://www2.st.com/content/ccc/resource/technical/document/datasheet/ef/92/76/6d/bb/c2/4f/f7/DM00037051.pdf/files/DM00037051.pdf/jcr:content/translations/en.DM00037051.pdf)
