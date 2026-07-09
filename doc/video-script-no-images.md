[title](title.png)
This is an experiment 
on separating architecture from code. 
Comments and suggestions welcome.

In my mind, 
code is just a building material, 
system architecture is more important than code.

---
[](title.png)

In this video, 
I'll just show a simple technique 
for writing an architectural description 
and how to browse it in layers.

Then we can look at the code 
to see how it maps to the 
Design Intent (DI) of the architect.

I imagine that in the future 
we might invent several more precise languages
to describe architecture with, 
like the Parts Based Programming (PBP) 
stuff I describe elsewhere, 
but, for this video 
we'll just use English 
and some SVG pictures.

---

[show M-0 code only view of test.st]
[](0.png)
What does this code do?

To figure that out, 
we are used to reading the code 
and reverse-engineering 
why the architect wrote 
the code that way.

---
I've been trying to re-create 
the reference version of the 
Parts Based Programming (PBP) kernel.

I'm inventing a meta-language 
on the fly 
that is intended to emit Python code, 
and to emit code in other languages 
like Javascript, Odin, etc. 
The meta-language is like 
Python with braces 
along with a few keywords 
that begin with `$` and `@`. 
You don't need to 
understand the meta-language 
at this point. 
I only want to show 
how to use layers 
to describe an architecture 
by spiralling into it 
in a layered manner.

I've been writing comments 
in ASCII text to explain 
what's going on, 
and what the meta-code 
is meant to accomplish, 
but it would be easier 
to explain in stages 
and to use diagrams.

I am drawing SVG diagrams 
using drawio 
and I've asked Claude 
to write elisp code 
to elide code 
and comments 
based on key bindings.

---
[display M-1 view]
[](1.png)
Here's an interim 
snippet of meta code. 
The algorithm that I want to describe 
is called `container-handler`.
It takes one parameter `self` 
that's defined elsewhere.

---
[M-2]

[](2.png)

At level 2, we describe 
the _purpose_ of this function.

We are writing the algorithm 
for how to handle parts 
that are composed of other parts.

This is kind of like lisp lists 
that contain other lists.

---
[M-3]

[](3.png)
At layer 3, I say more about the algorithm.

First we punt the incoming message 
down to children parts.

Then, we cycle and step 
the innards of this container 
until all internal events have subsided.

I use the word `mevent` here 
to mean an event which 
causes a reaction - 
a message event.

---
[M-4]

[](4.png)
At level 4, 
I choose to show red arrows 
for how to punt mevents 
down to children.

The interesting point here 
is that one incoming mevent 
is copied twice 
and fanned out 
to two inner children.

I think that the diagram 
shows what is happening 
better than words.

---
[M-5]

[](5.png)
At the next level, 
I say that the algorithm 
_steps until quiescense_

and show what I mean 
in the next level down

---
[M-6]

[](6.png)
The diagram shows 
that the incoming mevent 
caused a reaction 
from two inner parts 
which then sent two more mevents 
which then generated 
two more mevents 
which got fanned out
into the output 
of the composite part.

Again, t
he diagram says this 
better than my words.

---
`[M-0] [M-0]`

[](7.png)
Here, I've hit the key 
to show all architectural comments 
with code embedded within them.

---
[M-0]

[](8.png)

And here, 
I hit the toggle key 
to turn off all architectural comments, 
showing only the code.

We already saw this code 
at the beginning of this presentation, 
but now we have a better idea 
of why the code was written this way.

If I want to study the code some more, 
I can continue to hit hot keys 
to turn on various architectural 
layers as needed.
