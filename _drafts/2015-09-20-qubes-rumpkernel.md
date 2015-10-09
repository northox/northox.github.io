---
layout: post
title: Enhancing Qubes OS with Rumpkernels.
excerpt: ""
categories: "low-level"
tags: 
  - qubesos
  - rumpkernel
  - firewall
  - immutable
image: 
  feature: "birds-porto.jpeg"
  position: top left
  topPosition: 0px
bgContrast: dark
bgGradientOpacity: darker
syntaxHighlighter: "no"
published: true
---

---
layout: post
title:  "Enhancing Qubes OS with Rumpkernels."
excerpt: ""
categories: low-level
tags:
- qubesos
- rumpkernel
- firewall
- immutable
image:
  feature: birds-porto.jpeg
  position: 'top left'
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

To further extend the compartmentalization capabilities of QubesOS, for a long time I've begin asking myself what would be the best way to reduce the boot time and cpu/memory footprint of service/dedicated VMs, e.g., slip gpg, firewallVM, proxyVMs, trusted converters.

untrusted -> convert to raw (easy to validate format) -> send to trustedVM which validate the format -> convert back to a compressed format -> send it back.

##### The impacts
For serviceVM, cpu/memory load can quickly become a problem. In average, I found my firewallVM to use ~350MB of memory on its own. I haven't really tried to optimize as I'm pretty sure the optimization can bring me close to my objectives.

Heavy on memory -> might use deduplication but this has it's own security caveats
Heavy on CPU usage -> lots of unnecessary processes: cron, scheduler, ... (context switching)
Heavy on disk space -> fixed by templateVM architecture

### Enters the AnyKernel
Library OS

purpose built image ->  low maintenance
low memory/cpu footprint
typically boot in less than 100ms

#### Rumpkernels
Anti and friends . What they accomplish is simply awesome.
pick and choose NetBSD's drivers

#### What's the value for Qubes OS?
I foresee two main benefit of integrating anykernels to the QubesOS architecture:

1. Possibility for more segregation
load: CPU / memory
hard drive = minimal cuz templateVM
is to lower the boot time and cpu/memory footprint to enable more serviceVM (big sec-gain)
Better user experience... enabling more serviceVM convertVM

One of the best thing about Qubes OS its easy to strongly isolate operations while providing powerful integration tools. convert untrusted PDF to a trusted format.
music

untrusted -> convert to raw (easy to validate format) -> send to trustedVM which validate the format -> convert back to a compressed format -> send it back.

To further extend the compartmentalization capabilities of QubesOS, for a long time I've begin asking myself what would be the best way to reduce the boot time and cpu/memory footprint of service/dedicated VMs, e.g., slip gpg, firewallVM, proxyVMs, trusted converters.

2. Mitigate TCP/IP stack exploitation
is to fix ticket #??? which is to make use of a different TCP/IP stack codebase to reduce the chance for a single zero-day to hop from (out to in) the NetVM to FirewallVM to any AppVM and (in to out) from an UnpriviledgeVM to the FirewallVM and back to any AppVM

#### Impact on QubesOS and limitations of Rumpkernels:
a few scripts on dom0's side
still use XEN hypervisor - easy
code xenstore mechanisms?

There is still a lot of important limitation tothe rumpkernel as it does not handle signal,forks else? ???

### Proof of Concept - An immutable TorFirewallVM
the option to make it immutable but it's not quite clear whether this configuration could be used for the main Firewall but it seems like a very good option for a TorFirewallVM

#### How to build

### What's next?

--------
From a security perspective, the rumpkernel firewallVM increase the difficulties of compromising Qubes' AppVMs through a linux network stack zero-day. This threat is known and has been describe a long time ago (see ####). The idea is that since all the VMs share the same TCP/IP stack codebase, a single zero-day could compromise the isolation of all AppVMs by simply hopping from one VM to another using the same flaw. Obviously, this doesn't affect dom0 or AppVM with no network interface directly and to be fair, the attack itself is unlikely as the network stack are pretty stable and no flaws have been found since a long time, but still. With the rumpkernel FirewallVM, the attacker would need two zero-day (i.e. one in Linux and one in NetBSD) thus, an order of magnitude less likely/more difficult.

fs-util to manage conf
performance: static link. 1 VCPU?? see wiki
Rust!