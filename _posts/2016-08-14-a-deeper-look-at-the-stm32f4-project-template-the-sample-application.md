---
layout: post
tags:   embedded iot st microcontrollers project-template sample
date:   2016-08-14 20:45:00 +10:00
title:  "A deeper look at the STM32F4 project template: the sample application"
comments: true
---

[Over three months ago](/2016/05/08/a-deeper-look-at-the-stm32f4-project-template-linking-it-all-together/) (yeah... sorry about that) we took a look at the linker script for the [STM32F4 project template](https://github.com/charleskorn/stm32f4-project-template). I promised that we'd examine [the sample application](https://github.com/charleskorn/stm32f4-project-template/blob/master/main/main.cpp) next.

Note: the sample app assumes that you're using the STM32F4 Discovery development board. If you're not using that board, you should still be able to easily follow along, but some of the pin assignments might be slightly different.

The app is pretty straightforward: all it does is blink the four LEDs on the board in sequence, like this:

![Blinking LEDs](https://github.com/charleskorn/stm32f4-project-template/raw/master/doc/flashing-leds.gif)

If you've familiar with Arduinos, you'd probably expect to have something along these lines, perhaps without the repetition:

{% highlight c %}
while (1) {
	digitalWrite(LED_1, HIGH);
	delay(1000);
	digitalWrite(LED_1, LOW);
	digitalWrite(LED_2, HIGH);
	delay(1000);
	digitalWrite(LED_2, LOW);
	digitalWrite(LED_3, HIGH);
	delay(1000);
	
	...
	
}
{% endhighlight %}

However, I've taken a different approach. While it's definitely possible to do something like that, I wanted to illustrate the use of the timer hardware and interrupts.

# Setup

Most of the work is just configuring all the peripherals we need, and this all happens in `main()`:

{% highlight c %}
void main() {
	enableGPIOD();

	for (auto i = 0; i < pinCount; i++) {
		enableOutputPin(GPIOD, pins[i]);
	}

	enableTIM2();
	enableIRQ(TIM2_IRQn);
	enableTimerUpdateInterrupt(TIM2);
	setPrescaler(TIM2, 16 - 1); // Set scale to microseconds, based on a 16 MHz clock
	setPeriod(TIM2, millisecondsToMicroseconds(300) - 1);
	enableAutoReload(TIM2);
	enableCounter(TIM2);
	resetTimer(TIM2);
}
{% endhighlight %}

What does this all mean? Why is it necessary? (I've omitted the individual method definitions above and below for the sake of brevity, but you can find them in [the source](https://github.com/charleskorn/stm32f4-project-template/blob/master/main/main.cpp).)

* `enableGPIOD()`: Like most peripherals on ARM CPUs, GPIO banks (groups of I/O pins) are turned off by default to save power. All four of the LEDs are in GPIO bank D, so we need to enable it.

* `enableOutputPin(GPIOD, pins[i])`: just like `pinMode()` for Arduino, we need to set up each GPIO pin. Each pin can operate in a number of modes, so we need to specify which mode we want to use (digital input and output are the most common, but there are some other options as well).

* `enableTIM2()`: just like for GPIO bank D, we need to enable the timer we want to use (`TIM2`). We'll use the timer to trigger changing which LED is turned on at the right moment.

* `enableIRQ(TIM2_IRQn)` and `enableTimerUpdateInterrupt(TIM2)`: in addition to enabling the `TIM2` hardware, we also need to enable its corresponding IRQ, and select which events we want to receive interrupts for. In our case, we want timer update events, which occur when the timer reaches the end of the time period we specify.

* `setPrescaler(TIM2, 16 - 1)`: timers are based on clock cycles, so one clock cycle equates to one unit of time. However, that's usually not a convenient scale to use -- we'd prefer to think in more natural units like microseconds or milliseconds. So the timers have what is called a prescaler: something that scales the clock cycle time units to our preferred time units. 

	In our case, the CPU is running at 16 MHz, so setting the prescaler value to 16 sets up a 16:1 scaling -- 16 CPU cycles is one timer time unit. But there's an additional complication: the value we set in the register is not exactly the divisor used. The divisor used is actually one more than the value we set, so we set the prescaler value to 15 to achieve a divisor of 16.
	
* `setPeriod(TIM2, millisecondsToMicroseconds(300) - 1)`: this does exactly what it says on the tin. We want the timer to fire every 300 ms, so we configure the timer's period, or auto-reload value, to be 300 ms. 

	The reason it's called an 'auto-reload value' is due to how the timer works internally. The timer counts down ticks until its counter reaches zero, at which point the timer update interrupt fires. Once the interrupt has been handled, the auto-reload value is loaded into the counter, and the timer starts counting down again. So by setting the auto-reload value to our desired period, we'll receive interrupts at regular intervals.
	
	And, just like the prescaler value, the value used is one more than the value we set, so we subtract one to get the interval we're after.
	
* `enableAutoReload(TIM2)`: we need to enable resetting the counter with the auto-reload value, otherwise the timer will count down to zero and then stop.

* `enableCounter(TIM2)`: the counter won't actually start updating its counter in response to CPU cycles until we enable the counter

* `resetTimer(TIM2)`: any changes we make in the timer configuration registers don't take effect until we reset the timer, at which point it pulls in the values we've just configured.

So, after all that, we've setup the GPIO pins for the LEDs and configured the timer. Now all we have to do is wait for the timer interrupt to fire, and then we'll change which LED is turned on.

You might be wondering how to find out what you need to do to use a piece of hardware. After all, there was a lot of stuff that needed to be done to set up that timer, and not all of it was particularly intuitive. The answer is usually a combination of trawling through the datasheet, looking at examples provided by the manufacturer (ST in this case) and Googling. 

# Timer interrupt handling

In comparison to the configuration of everything, actually responding to the timer interrupts and blinking the LEDs is relatively straightforward.

First of all, we need an interrupt handler: 

{% highlight c %}
extern "C" {
	void TIM2_IRQHandler() {
		if (TIM2->SR & TIM_SR_UIF) {
			onTIM2Tick();
		}

		resetTimerInterrupt(TIM2);
	}
}
{% endhighlight %}

Because this method is called directly by the [startup assembly code](/2016/04/17/a-deeper-look-at-the-stm32f4-project-template-getting-things-started/), we have to mark it as `extern "C"`. This means that the method uses C linkage, which prevents C++'s name-mangling from changing the name. We don't want the name to be changed because we want to be able to refer to it by name in the assembly code. [This Stack Overflow question](http://stackoverflow.com/questions/1041866/in-c-source-what-is-the-effect-of-extern-c) has a more detailed explanation if you're interested.

The handler itself is relatively straightforward:

* we check if the reason for the interrupt is the update event we're interested in
* if it is, we call out to our handler function `onTIM2Tick()`
* we reset the timer interrupt -- otherwise our interrupt handler will be called again straight away

`onTIM2Tick()` is also straightforward:

{% highlight c %}
void onTIM2Tick() {
	lastPinOn = (lastPinOn + 1) % pinCount;

	for (auto i = 0; i < pinCount; i++) {
		BitAction value = (i == lastPinOn ? Bit_SET : Bit_RESET);

		GPIO_WriteBit(GPIOD, 1 << pins[i], value);
	}
}
{% endhighlight %}

All we do is loop over each of the four LEDs, turning on the next one and turning off all of the others. (`GPIO_WriteBit()` is a function from the standard peripherals library that does exactly what it sounds like.)

# The end

That's all there is to it -- a lot of configuration wrangling and then it's smooth sailing. Next time (which hopefully won't be in another three months), we'll take a quick look at the build system in the project template.
