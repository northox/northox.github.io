---
layout: post
title: Enhancing QubesOS with Rumprun unikernels.
excerpt: ""
categories: "low-level"
tags:
  - qubesos
  - unikernel
  - rumprun
image:
  feature: "birds-porto.jpeg"
  position: top left
  topPosition: 0px
bgContrast: dark
bgGradientOpacity: darker
syntaxHighlighter: "no"
---

For some time, I've been asking myself how to enhance the compartmentalization capability of [Qubes OS](https://qubes-os.org). Playing with different security domains implemented as VMs running common monolithic kernels comes at a price:

- The user experience drawbacks of managing resources tension caused by concurrent domains, e.g. free some memory by stopping a VM to start another;
- The delay associated with starting domains, i.e. normally Fedora Linux, sometimes only to execute a specific task which takes a fraction of the time needed to boot.

Nonetheless, there's huge advantage for this approach. As ITL summarize it: everything just works. Being able to leverage what's already out there certainly have something to do with the success of such an ambitious project, e.g. Firefox, MS Word, network and graphical drivers. Building an OS which requires each and every application to be rewritten (e.g. a micro-kernel) is sort of a show stopper if you aim at building something actually useful - not pure research.

At some point I end up with those questions:

- Would it be possible to significantly reduce the memory footprint of a few domains?
- What if we reduce the boot time to something barely noticeable?

To give an idea of what we're talking about; in average I found my NetVM and FirewallVM to boot in ~15 seconds while my split GPG and vault domains takes ~9 seconds and respectively use 300MB and 200MB of memory.

What if there was a middle ground between running a full OS and having to rewrite everything?

### Enter the Rumprun unikernel

> Unikernels are specialised, **single address space** machines constructed by using library operating systems. A developer selects, from a modular stack, the **minimal set of libraries** which correspond to the OS constructs required for their application to run. These libraries are then compiled with the application and configuration code to build sealed, fixed-purpose images which run directly on a hypervisor or hardware.
> - Source: [Wikipedia](https://en.wikipedia.org/wiki/Unikernel)

Just as an example, unikernels are so tailored to the application they run, they don't even need a file system unless made necessary by the application (configurations, data sets, etc) or a driver required by the application (to open a device, load firmware, etc).

While most unikernel projects are aimed at cloud usage or are language specific (Erlang, OClam, Haskell, Go), the use cases applicable to the unikernel from the [Rump kernel](http://rumpkernel.org) project seems much broader as it can run existing/unmodified POSIX software - exactly what we're looking for.

The project started as an implementation of the [anykernel](https://en.wikipedia.org/wiki/Rump_kernel#Anykernel) concept on NetBSD but end up also creating a unikernel called [Rumprun](https://github.com/rumpkernel/rumprun). The story of how they got there is [truly fascinating](https://blog.xenproject.org/2015/08/06/on-rump-kernels-and-the-rumprun-unikernel/) but what needs to be understood is the following:

The [anykernel](https://en.wikipedia.org/wiki/Rump_kernel#Anykernel) concept targets drivers. The goal is to create an architecture-agnostic approach to drivers that makes it possible to run unmodified kernel components almost anywhere. This enables NetBSD drivers to run in userspace of POSIX operating systems, e.g. Linux, BSD, Windows via Cygwin. Yep, you got that right, you can develop, run and debug a driver in userland.

<blockquote class="largeQuote">
  This capability led them to easily create unikernels.
</blockquote>

To get from the anykernel concept to a unikernel they needed a few more things; low-level code as describe below and to put libc on top for the application to interact with:

> I started looking at the Xen Mini-OS to figure out how to bootstrap a domU, and quickly realized that Mini-OS implements almost everything the rump kernel hypercall layer requires: a build infra, cooperative thread scheduling, physical memory allocation, simple interfaces to I/O devices such as block/net, and so forth.  
>- Source [[Xen-users] Antti Kantee ](http://lists.xenproject.org/archives/html/xen-users/2013-08/msg00152.html)

The end result is truly amazing. The project end-up with a toolchain that easily makes an application run on bare metal x86, XEN and KVM. The [package repository](https://github.com/rumpkernel/rumprun-packages) demonstrate a few things they tested: nginx, redis, mysql, nodejs, rust, python, roundcube's webmail, etc. My [next post](TBD<<<<<<<<<<<<<<) will demonstrate a Qubes specific use case.

If you want to know everything there is to know about Rump kernel and Rumprun, read the publications on their [wiki](https://github.com/rumpkernel/wiki/wiki/Info%3A-Publications-and-Talks) and [Antti's book](https://github.com/rumpkernel/book).

#### What's in it for Qubes OS?
The advantage of the Rumprun unikernel translates in two main benefits for Qubes - but there may be others, time will tell:

1. Ease/encourage the use of concurrent security domains
  - There's a great potential to reduce the med to manage domains by lowering the strain on the system resources (e.g. stop some VMs to free memory);
  - Enhance the user experience with almost seamless boot time of domains;
  - Drive proper behavior to use trusted converters - maybe make them mandatory when sending to a domain of greater trust.

2. Mitigate a hypothetic chained TCP/IP stack exploit
	- We can fix issue [#806](https://github.com/QubesOS/qubes-issues/issues/806) by making use of a different TCP/IP stack codebase. This would reduce the chance for a single zero-day to cascade from the NetVM to FirewallVM to any AppVM (inbound) and from an unpriviledgeVM to the FirewallVM and back to any AppVM (local). More detail in my [next post](TBD<<<<<<<<<).

#### Current limitations of Rumprun Unikernel

There a few important limitations to a Rumprun unikernel:

- The application must support cross-compilation - no big deal;
- It's single process / single core, e.g. fork() and execve() won't work;
- No virtual memory, e.g. no mmap with MAP_FIXED or r/w mapping of files.
- It doesn't handle signals;

Briefly, this means creating a split-gpg or trusted converter domain would be more complex than simply accessing a shell command, getting a graphical window using X is out of question, etc.

Currently, the biggest limitation is the lack of vchan support... but looking at [Martin Lucina's presentation](http://events.linuxfoundation.org/sites/events/files/slides/xdps15-talk-final_0.pdf) in August 2015, this seems to be heading our way. Once we can communicate with other VMs using vchan, Rumprun will fit perfectly with Qubes' communication model/policy and should make things like implementing a trusted converter pretty straightforward (aside being lightweight and lightning fast).

#### Impacts on QubesOS

There are actually very few things that need to be added to dom0 as mostly everything is already in place:
To boot a Rumprun unikernel image we need to execute a few *special* steps. Fortunately, this part is managed by a very simple [shell script](https://github.com/rumpkernel/rumprun/blob/master/app-tools/rumprun) easily audited and integrated in Qubes toolstack. It takes a few arguments defining, as an example, the network configuration and rely on XEN's xl toolstack which is obviously already available. Obviously the Rumprun image must be sent on dom0 but will only be executed safely by XEN itself.

The biggest impact is on the build side which would require the integration of the Rumprun repository which includes NetBSD's source (an additional 350MB) and implies trusting them for whatever domains we're building.

<blockquote class="largeQuote">
  Rumprun is a natural fit for QubesOS.
</blockquote>

### What's next?
There are certainly a few things I haven't thought about and getting constructive feedback is what I'm looking for. At the same time I'll be working on the next post about the cascading zero-day TCP/IP stack exploit threat which will highlight some security value. At some point, a second project with something like a [trusted converter](http://theinvisiblethings.blogspot.ca/2013/02/converting-untrusted-pdfs-into-trusted.html) for images or MP3s (via vchan) would be useful to confirm or infirm the user experience value, i.e. boot time, and possibly generate new ideas. There still a lot of questions that needs answers, e.g. What would need to be modified on Qubes' side? What's the effort? Any significant problem with the approach?
