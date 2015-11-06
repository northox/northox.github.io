---
layout: post
title: Enhancing Qubes with Rumprun unikernels.
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
syntaxHighlighter: no
---

_This post is the first of a series and assumes you have some basic understanding of [Qubes](https://qubes-os.org)' reason being, structure and terminology._

For some time, I've been asking myself how to enhance Qubes. Working with different security domains implemented as VMs running traditional Operating System with monolithic kernels comes at a price:

- The user experience drawbacks of managing memory-hungry concurrent VMs (&ge; 300MB), e.g. freeing some memory by stopping a VM to start another, or waiting for a VM to boot (~8.5s) to launch an app and sometimes only to execute something which takes a fraction of this time.
- From a security perspective, memory consumption limits our ability to introduce more domain segmentation.

Nonetheless, there are huge advantages in using traditional OS. Being able to leverage what's already out there (e.g. Firefox, MS Word, network/graphic drivers) without any effort certainly has something to do with the success of such an _ambitious project_. Building an OS which requires each and every component to be written (like traditional micro-kernels) is a show stopper if your goal is to build something actually useful - not pure research.

<blockquote class="largeQuote">
What if there was a middle ground between running a fat-OS and having to rewrite everything?
</blockquote>

What if we could reuse quality code without the kitchen sink while reducing the memory footprint by more than tenfold and the startup time to something barely noticeable, subsecond?

### Enter the unikernel

Unikernels are single address space systems which bundle up an application and a *selection* of system components relevant for a specific purpose into a single lightweight image that can run on an hypervisor or directly on hardware. To illustrate how different they are from traditional OS, just consider they don't even need a file system unless made necessary by the use-case.

#### What's in it for Qubes?

Fit-for-purpose is the word and as such, unikernels consume a lot less memory and boot in a split second, 10MB and ~150ms respectively is quite standard. This is huge and opens many doors.

##### Enhance the user experience

There's great potential to reduce the management of VMs (e.g. reduce the need to stop some VMs to free memory) and seamless boot time could open up new opportunities.

##### Increase security

**The potential to leverage more compartmentalization**  
  If we can fit more domains in the same amount of memory we're increasing our ability to run more concurrent domains. This has direct impact on our ability to segregate more components without affecting the UX. As an example, if there was a benefit to run two firewallVM, we might not be inclined to do so by default if it would consume ~600MB (2x ~300MB) while it would be painless using unikernels which take a fraction of this memory.

  - More network segmentation: run more _lean and slim_ FirewallVM, ProxyVM, VpnVM TorVM, NetVM.
    - **Bonus point!** We can mitigate a hypothetical chained TCP/IP stack exploit ([#806](https://github.com/QubesOS/qubes-issues/issues/806)) by making use of a different TCP/IP stack codebase. This reduces the chance for a single zero-day to cascade from the NetVM to FirewallVM to any network-enabled AppVM (inbound) and from an untrustedVM to the FirewallVM and back to any network-enabled AppVM (local). More details in the [next blog post](<<<<<<<<<<<<).
  - Lead to the enforcement of [trusted converters](http://blog.invisiblethings.org/2013/02/21/converting-untrusted-pdfs-into-trusted.html).
  - More device domains: USB, BlueTooth, audio, hard drive/file system.

**It values minimalism over _featurism_**  
  Obviously, this is always a good thing for security and mainly translates into less management and making exploitation harder (but really nothing to get too excited about): there's not much to play with, e.g. no shell, and not much to gain persistence with, e.g. mostly read-only.

### Rumprun unikernel
Most unikernels run single language such as Erlang, Haskell or OCaml and implement/maintain their own set of system components, e.g. drivers, protocols such as TLS. While such approach can be useful in special use-cases, what Qubes is really looking for is to reuse exciting/maintained code (apps and drivers).

The [Rumprun unikernel](http://repo.rumpkernel.org/rumprun) from the [Rump kernel](http://rumpkernel.org) project does exactly this. It allows the use of unmodified [NetBSD's](https://netbsd.org) [components](/misc/rump-make_describe-2015-10.txt) of your choice and unmodified, real world software (POSIX). I won't go into the details of how it work and came to be - a truly [fascinating story](https://blog.xenproject.org/2015/08/06/on-rump-kernels-and-the-rumprun-unikernel/) - but to motivate your curiosity, here's a ten thousand feet diagram:

![anykernel and rumpkernel to unikernel](/img/posts/anyunirumpkernel.png)
<small>
source: [http://wiki.rumpkernel.org/Repo](http://wiki.rumpkernel.org/Repo)
</small>

The end result is simply amazing. It provides a toolchain that easily makes an application and the minimal set of system components to run on bare metal x86, x86_64, ARM, KVM or Xen. Here's a few interesting examples which mostly make use of the network component: nginx, redis, mysql, python, rust and roundcube's webmail. Systems components worth of mention for Qubes' developers include USB, BlueTooth, hard drive/file system, audio and network stacks. See this [list of components](/misc/rump-make_describe-2015-10.txt) and the [package repository](http://repo.rumpkernel.org/rumprun-packages) for more info.

In essence, Rumprun foster Qubes' components disaggregation and compartmentalization efforts by supporting its requirement to use existing/supported system components and to run real-world applications while mitigating the inherent issues of such prerequisite. In other words, it's supporting Qubes' pseudo-micro-kernel-using-monolithic-kernel-components approach.

![tcp ip stop reverse cascade](/img/posts/qubes-full-vs-uni.png)
<small style="font-size: 16px">
Conceptual diagram depicting the difference between full-os and unikernel serviceVMs.
</small>

If you want to know everything there is to know about Rumprun, read the [publications](http://wiki.rumpkernel.org/Info%3A-Publications-and-Talks) and [Antti Kantee's book](http://repo.rumpkernel.org/book).

#### Current limitations and usage

Rumprun comes with its own technical limitations:

- The application must support cross-compilation. No big deal;
- Single process. Obviously, fork() and execve() won't work;
- No virtual memory but again, it's presumed;
- For now, don't expect to run a GUI. Still, based on Antti's comment, it would be feasible;
- It doesn't support vchan, for now but to fit with Qubes' communication model ([qrexec](https://www.qubes-os.org/en/doc/qrexec/)) and becomes a first class citizen, vchan is a must. The discussions I had with the Rumpkernel team (mainly Antti) suggest it would be pretty easy to implement.

In summary, we can't expect unikernels to fit for all use-cases and they certainly aren't expected to replace the general-purpose domains such as *work*, *personal* and *untrusted*. However, currently they're a perfect fit for domains which doesn't require direct user interactions such as serviceVMs used in in-line/pipe-like use cases. In the future, it might be great for single-purpose domains like [split GPG](https://www.qubes-os.org/doc/split-gpg/) or email-dedicated domains.

#### Impacts on Qubes

Currently, to boot a Rumprun unikernel image we need to execute a few *special* steps: start paused, inject some config in XenStore, unpause. Fortunately, this part is managed by a very simple [shell script](https://github.com/rumpkernel/rumprun/blob/master/app-tools/rumprun) that can easily be audited and integrated to Qubes' toolstack. Even better, when challenged with this already known problem, the Rumpkernel team quickly sparked a discussion to remove it altogether and try to rely solely on the hypervisor’s toolstack - like any other VM.

On the build side, it requires the integration of Rumprun's repository which includes NetBSD's source (~350MB which can be trimmed down) and implies trusting them for whatever domains we're building. This doesn't sound unrealistic.

### Conclusion

In this post we explored the substantial and concrete value of integrating unikernels or more precisely Rumprun to Qubes. We also went over the challenges and than demonstrated why Rumprun seems to be a natural fit.

Now, I'm looking for constructive feedback from Qubes' community and will try to answer a few questions: What exactly would need to be modified on Qubes' side to be part of the default installation? What's the effort? What's the best course of action? Is it viable in practice? Does it make sense?

To shed some light over the practicality of Rumprun's integration and its security value, the next post of this series will be about the implementation of the *TCP/IP stack mitigation* case. Afterward, creating a [trusted converter](http://theinvisiblethings.blogspot.ca/2013/02/converting-untrusted-pdfs-into-trusted.html) for PDFs or pictures will underline the user experience value and possibly spawn new ideas. Stay tuned!

Interested in contributing? [Drop me a line](/about/#contact)!
