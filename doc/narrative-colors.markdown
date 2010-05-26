Title: Narrative Description of "colors" Demo

This is a simple narrative description of the `colors` application included
with the Lumen library as a demo.  It is probably slanted toward the X window
system; MS-Windows and Mac users of Lumen, if there ever are any, may not be
familiar with some of the terms.

The `colors` demo was the very first application written to use the Lumen
library.  It uses low-level calls, and most real Lumen apps won't look much
like it.  But it did help Lumen get up and stumbling with its two most
fundamental services: Opening a window into which OpenGL rendering can be
done, and reporting user input events to the app.  It was adapted from
[the simple `glXIntro` demo program](http://glprogramming.com/blue/ch07.html)
I found on the web.

It starts off using `Lumen.Window.Create` to create its window, which creates
a native window and an OpenGL rendering context to go with it.  It sets the
window name (which on my system appears in the window's title bar), asks for
it *nnt* to be double-buffered (`Animated => False`, I'll explain why in a
bit), and asks to see key-press events sent to the new window.

Having created the window successfully, which it knows because otherwise an
exception would have been raised, it goes into its own very simple
custom-crafted event loop.  Lumen provides some predefined "canned" event-loop
routines, which I assume most programs will use, possibly in their own
separate task, but `colors` isn't that complex.  Plus it also serves as an
example of how to write your own event loop, yay!

The first thing the event loop does is process any and all pending events.
These will be key presses, plus any "unmaskable" events like client messages,
plus structure-change notifications, which Lumen asks for automatically.
Usually the first event it gets is a `Mapped` event, which says "your window
is now present on the screen".  The first time it gets that event, the app
sets the `Visible` flag, which causes the actual drawing to happen later in
the event loop.

The event processing also checks for key presses and close-window events,
which cause it to exit the main (outer) event loop and terminate the app.  Key
presses happen when you press any key on the keyboard, even modifiers like
Shift or Control.  The `Close_Window` event is generated when you select the
window manager's "Close" button, usually an "X" in the title bar or something
like it, depending on your window manager and its configuration.

After it has gobbled up and processed all the events in the inner loop, the
app then goes into the actual OpenGL drawing code.  Finally!  It does the
drawing only after the window becomes visible, because before that it would be
a waste of time.  I guess one danger of the current code is that if the window
doesn't become visible (mapped, in X parlance) right away, the app goes into a
very tight loop waiting for that first `Mapped` event.  But testing hasn't
shown that to happen, so meh.

Normal X apps spend much of their time blocked on the event queue, waiting for
an event to show up, which doesn't take any real CPU time.  That's what
Lumen's canned event-loop routines do, too, which is why they'll sometimes be
placed into a separate task, so the rest of the app can go about its business
without waiting for an event to come along.  So-called "event-driven" apps, on
the other hand, are actually designed to wait until an event comes along
before taking any action; it's just up to the needs of your app which
structure you'll use.

The OpenGL "drawing" part of the demo is dirt simple: It clears the window
successively to red, green, and then blue, waiting one second after each
change.  And that's it.  You were maybe expecting bouncing balls or something?

As mentioned above, I chose to create a single-buffered rendering context, by
setting the `Animated` parameter to the `Create` call to `False`.  This
simplifies the app a tiny bit: If I had asked for a double-buffered context,
I'd have had to call `Lumen.Window.Swap` after every color change in order to
actually see the new color.  That's because in double-buffered contexts,
drawing normally happens in the invisible "back buffer", and that buffer is
only displayed once you swap it to the front.  Any good OpenGL reference can
explain what that's all about, and how it avoids "tearing" and other enemies
of smooth animation, but we don't need it here.