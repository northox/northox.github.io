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

For some time, I've been asking myself how to enhance the compartmentalization capability of [Qubes OS](https://qubes-os.org). Playing with different security domains implemented as VMs running common Operating System with monolithic kernels comes at a price:

- The user experience drawbacks of managing resources contention caused by concurrent VMs, e.g. free some memory by stopping a VM to start another;
- The wait for launching an application or executing a task from within a stopped VM sometimes only to execute a specific task which takes a fraction of this time.

<small>
Basic stats collected from Qubes v2. Let me know if your results differs greatly.
</small>

```
                      | Memory | Boot time
Domains               |   (MB) | (seconds)
----------------------+--------+----------
NetVM & FirewallVM    |  ~ 300 |   ~8.5s
split GPG             |  ≥ 200 |   ~8.5s
trusted PDF converter |  ~ 280 |     TBC
```

Those numbers aren't awful but for sure, it could be a lot better. Nonetheless, there's huge advantage in using this approach. As ITL summarize it: everything just works. Being able to leverage what's already out there certainly have something to do with the success of such an _ambitious project_, e.g. Firefox, MS Word, network/graphical drivers. Building an OS which requires each and every components to be rewritten (like a micro-kernel) is sort of a show stopper if your goal is to build something actually useful - not pure research.

<blockquote class="largeQuote">
What if there was a middle ground between running a fat-OS and having to rewrite everything?
</blockquote>

What if we could reuse quality code without the kitchen sink, reduce the memory footprint by more than threefold and the startup time to something barely noticeable, subsecond?

### Enter the unikernel

Unikernels are single address space systems which bundle up an application and a *selection* of system components relevant for a specific purpose into a single lightweight image. The latter can then run on an hypervisor or directly on hardware. They are so fit for purpose that they don't need a file system unless made necessary by the use-case (e.g. configurations, data sets) or a required driver (e.g. open a device, load firmware).

Some implementation are meant to run single language such as Erlang, Haskell or OCaml and implement/maintain their own set of system components: drivers, protocols such as TLS, etc. Another approach is for the unikernel to reuse exciting/maintained software running on current Operating Systems.

#### Rumprun unikernel
The [Rump kernel](http://rumpkernel.org) project uses the second approach with their [Rumprun](http://repo.rumpkernel.org/rumprun) unikernel. It allows the use of unmodified [NetBSD's](https://netbsd.org) components of your choice and unmodified / real world software (POSIX). The project started as an implementation of the [anykernel](http://wiki.rumpkernel.org/Repo#the-big-picture) concept to provide [Rump kernels](https://en.wikipedia.org/wiki/Rump_kernel) but end up also creating a unikernel. The story of how they got there is [truly fascinating](https://blog.xenproject.org/2015/08/06/on-rump-kernels-and-the-rumprun-unikernel/).

Very briefly, the goal of the anykernel is to provide the possibility to run unmodified kernel component almost anywhere in an environment called rump kernel. In other words, it is an architecture-agnostic approach to drivers. Rump kernels can run in kernel/user space of POSIX operating systems (e.g. Linux, BSD, Windows via Cygwin). This is huge! At that point, to get to a unikernel they needed just a few more things; low-level code as described below and to put libc on top for the application to interact with:

> I started looking at the Xen Mini-OS to figure out how to bootstrap a domU, and quickly realized that Mini-OS implements almost everything the rump kernel hypercall layer requires: a build infra, cooperative thread scheduling, physical memory allocation, simple interfaces to I/O devices such as block/net, and so forth.
>- Source [[Xen-users] Antti Kantee ](http://lists.xenproject.org/archives/html/xen-users/2013-08/msg00152.html)

![anykernel and rumpkernel to unikernel](/img/posts/anyunirumpkernel.png)
<small>
source: [http://wiki.rumpkernel.org/Repo](http://wiki.rumpkernel.org/Repo)
</small>

The end result is simply amazing. It provides a toolchain that easily makes an application run on bare metal x86, x86_64, ARM, KVM and Xen. A few interesting examples from the [package repository](http://repo.rumpkernel.org/rumprun-packages) are; nginx, redis, mysql, nodejs, rust, python and even roundcube's webmail. If you want to know everything there is to know about Rump kernel, read the [publications](http://wiki.rumpkernel.org/Info%3A-Publications-and-Talks) and [Antti's book](http://repo.rumpkernel.org/book).

#### Current limitations of Rumprun unikernels

We can't expect unikernels to fit for all use-cases and they certainly aren't expected to replace general-purpose domains such as *work*, *personal* and *untrusted*. Also they come with some technical limitations:

- The application must support cross-compilation. No big deal;
- Single process, e.g. fork() and execve() won't work but that's expected;
- No virtual memory but again, it's presumed;
- Don't expect to run a GUI! Actually, I don't quite see when this would be necessary;
- It doesn't support vchan, for now...

It seems like the biggest limitation is the lack of vchan support which is required to become a first class citizen on Qubes or in other words, to fit with its communication model ([qrexec](https://www.qubes-os.org/en/doc/qrexec/) to send/receive files/actions/messages to other domains based on the policy engine. But really, this shouldn't be too hard to implement and looking at Martin Lucina's [presentation](http://events.linuxfoundation.org/sites/events/files/slides/xdps15-talk-final_0.pdf) from August 2015, we're not the only one in need for it.

#### What's in it for Qubes OS?

![monolithic kernel v unikernel](/img/posts/mono-v-uni.png)

Unikernels can enhance Qubes in many ways. They're a perfect fit for domains which doesn't require direct user interactions such as serviceVMs used in-line/pipe-like use cases. Here's some advantage I could come up with. I'm sure there's many more:

##### Ease/encourage the use of concurrent security domains

1. There's a great potential to reduce the management of VMs, e.g. reduce the need to stop some VMs to free memory;
1. Enhance the user experience and possibly create new patterns with almost seamless boot time of some serviceVMs.

##### Increase security

1. The first two benefits could lead us to enforce the usage of [trusted converters](http://blog.invisiblethings.org/2013/02/21/converting-untrusted-pdfs-into-trusted.html), e.g. from untrusted to trusted domains;

2. The approach values minimalism over -featurism-. This mainly translate in making exploitation harder and probably less management;
  - Not much to play with, e.g. there's no shell;
  - Not much to gain persistence with, e.g. mostly read-only.

3. It has the potential to provide even more network operations opportunities: lean and slim FirewallVM, ProxyVM and NetVM.
  - **Bonus point!** We can mitigate an hypothetic chained TCP/IP stack exploit [#806](https://github.com/QubesOS/qubes-issues/issues/806) by making use of a different TCP/IP stack codebase (BSD). This would reduce the chance for a single zero-day to cascade from the NetVM to FirewallVM to any AppVM (inbound) and from an unpriviledgeVM to the FirewallVM and back to any AppVM (local). More detail in the next post.
  - Hardware can be directly accessed via PCI passthrough (while being safely isolated using IOMMU/VT-d);

#### Impacts on QubesOS

Currently, to boot a Rumprun unikernel image we need to execute a few *special* steps: start paused, inject some configurations in XenStore, unpause. Fortunately, this part is managed by a very simple [shell script](https://github.com/rumpkernel/rumprun/blob/master/app-tools/rumprun) that can easily be audited and integrated in Qubes' toolstack. Even better, there's some discussion toremove it altogether and only rely on the hypervisor’s toolstack instead - like any other VM.

The biggest impact is on the build side which would require the integration of the Rumprun repository which includes NetBSD's source (an additional 350MB) and implies trusting them for whatever domains we're building. This doesn't sound unrealistic.

<blockquote class="largeQuote">
  Rumprun unikernel seems to be a natural fit to QubesOS
</blockquote>

#### What's next?

- Get some constructive feedback and answer a few questions such as:
  - Is this viable in practice?
  - What exactly would need to be modified on Qubes' side and what's the effort?;
- I'll post the instructions and code for the *TCP/IP stack mitigation* case which will shed some light over the practicality of Rumprun and its security value;
- If everything goes well, at some point we should get a [trusted converter](http://theinvisiblethings.blogspot.ca/2013/02/converting-untrusted-pdfs-into-trusted.html) for pictures which would be useful to explore the user experience value and possibly spawn new ideas.

Interested in contributing? Drop me a line!
