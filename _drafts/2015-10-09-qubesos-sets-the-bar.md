---
published: false
---

---
layout: post
title:  "Why QubesOS sets the bar."
excerpt: ""
categories: low-level
tags:
- qubesos
- rumpkernel
- firewall
- immutable
image:
  feature: sky-porto.jpeg
  position: 'center center'
  topPosition: 0px
bgContrast: dark
bgGradientOpacity: darker
syntaxHighlighter: no
---
Within this post I'll go very briefly over some concepts behind Qubes OS to ramp
up readers that doesn't have all the technical background to entirelly comprehend the beauty of Rumpkernels. Still, before going any further, make sure
you're comfortable with its basic architecture.

Hint: no, it's not simply a new distribution of Linux but a new desktop Operating Systems architecture breaking the status quo.

#### Monolitic kernel
Mostly all Operating Systems in use today rely on Monolitic kernels. Invisible
Things Lab researches led them to have a profound disgust for traditional OS architecture which heavily rely on Security by Correctness. This means the attack surface of their Trusted Computing Base is very large and they mostly depend on code to be free of vulnerabilities for their Security Model to hold up.

Everything runs as the same level, e.g. your MP3 player can read your financial statement done in excel - it has the same privilege than you.

Mostly every flaw is a Game Over case; Ethernet driver, WIFI driver, graphical driver, the browser, the MP3 player or any application using streams of complex data that needs to be parse - mostly everything.

#### QubesOS' pseudo micro-kernel architecture
wanted to create a new OS with very limited resources 2 to 3 dev in a year.
something that would be usable.

The most important problems with micro-kernel is that everything needs to be rewrite and performance.

Strong Isolation: XEN
slim, secure interfaces (the most difficult part): libvchan + slim comm

It's actually pretty interesting to see Microsoft integrating some of those  _Compartmentalization_ concepts thought ?????? and partnership with Bromium.
