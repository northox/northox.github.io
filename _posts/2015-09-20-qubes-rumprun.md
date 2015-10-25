---
layout: post
title: Enhancing Qubes OS with Rumprun unikernels.
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

For some time, I've been asking myself how to enhance the compartmentalization capability of Qubes. Working with different security domains implemented as VMs running traditional Operating System with monolithic kernels comes at a price:

- The user experience drawbacks of managing resources contention caused by concurrent VMs, e.g. freeing some memory by stopping a VM to start another;
- The wait for launching an application or executing a task from within a stopped VM and sometimes only to execute a specific task which takes a fraction of this time.

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

Nonetheless, there are huge advantages in using traditional OS. Being able to leverage what's already out there (e.g. Firefox, MS Word, network/graphic drivers) without any effort certainly has something to do with the success of such an _ambitious project_. As ITL summarizes it: everything just works. Building an OS which requires each and every component to be rewritten (like traditional micro-kernels) is a show stopper if your goal is to build something actually useful - not pure research.

<blockquote class="largeQuote">
What if there was a middle ground between running a fat-OS and having to rewrite everything?
</blockquote>

What if we could reuse quality code without the kitchen sink while reducing the memory footprint by more than tenfold and the startup time to something barely noticeable, subsecond?

### Enter the unikernel

Unikernels are single address space systems which bundle up an application and a *selection* of system components relevant for a specific purpose into a single lightweight image that can run on an hypervisor or directly on hardware. They are so fit for purpose that they don't need a file system unless made necessary by the use-case (e.g. configurations, data sets) or a required driver.

Unikernels can enhance Qubes in many ways. They're a perfect fit for domains which doesn't require direct user interactions such as serviceVMs used in-line/pipe-like use cases.

![monolithic kernel v unikernel](/img/posts/mono-v-uni.png)

Here are some advantages I could come up with. I'm sure there are many more.

#### Ease/encourage the use of concurrent security domains

1. There's a great potential to reduce the management of VMs, e.g. reduce the need to stop some VMs to free memory;
1. Enhance the user experience and possibly create new patterns with almost seamless boot time of some serviceVMs.

#### Increase security

1. Potential to leverage more compartmentalization;
  - The first two benefits could lead us to enforce the usage of [trusted converters](http://blog.invisiblethings.org/2013/02/21/converting-untrusted-pdfs-into-trusted.html), e.g. from untrusted to trusted domains;
  - Encourage more network segmentation: run more _lean and slim_ FirewallVM, ProxyVM, TorVM, NetVM, etc.
     - **Bonus point!** We can mitigate a hypothetical chained TCP/IP stack exploit ([#806](https://github.com/QubesOS/qubes-issues/issues/806)) by making use of a different TCP/IP stack codebase. This reduces the chance for a single zero-day to cascade from the NetVM to FirewallVM to any AppVM (inbound) and from an untrustedVM to the FirewallVM and back to any AppVM (local). More details in the next [blog post](<<<<<<<<<<<<).
  - Encourage more device domains;
     - Hardware can be dedicated via PCI passthrough and handled by a fit-for-purpose unikernel (and safely isolated with IOMMU). See this [list of rump components](/misc/rump-make_describe-2015-10.txt), e.g. BlueTooth, audio, SMB, USB.

2. The approach values minimalism over _featurism_.
  - This mainly translate in making exploitation harder (but really nothing to get too excited about) and probably less management: not much to play with, e.g. there's no shell; not much to gain persistence with, e.g. mostly read-only.

### Rumprun unikernel
Most unikernels run single language such as Erlang, Haskell or OCaml and implement/maintain their own set of system components: drivers, protocols such as TLS, etc. While such approach can be useful in special case, what Qubes is really looking for is to reuse exciting/maintained code.

The [Rumprun unikernel](http://repo.rumpkernel.org/rumprun) from the [Rump kernel](http://rumpkernel.org) project does exactly this. It allows the use of unmodified [NetBSD's](https://netbsd.org) components of your choice and unmodified, real world software (POSIX). I won't go into the details of how it work and came to be - a truly [fascinating story](https://blog.xenproject.org/2015/08/06/on-rump-kernels-and-the-rumprun-unikernel/) - but to motivate your curiosity, here's a ten thousand feet diagram:

![anykernel and rumpkernel to unikernel](/img/posts/anyunirumpkernel.png)
<small>
source: [http://wiki.rumpkernel.org/Repo](http://wiki.rumpkernel.org/Repo)
</small>

The end result is simply amazing. It provides a toolchain that easily makes an application run on bare metal x86, x86_64, ARM, KVM and - what we need - Xen. A few interesting examples from the [package repository](http://repo.rumpkernel.org/rumprun-packages) are nginx, redis, mysql, nodejs, rust, python and even roundcube's webmail.

If you want to know everything there is to know about it, read the [publications](http://wiki.rumpkernel.org/Info%3A-Publications-and-Talks) and [Antti Kantee's book](http://repo.rumpkernel.org/book).

#### Current limitations of Rumprun unikernels

We can't expect unikernels to fit for all use-cases and they certainly aren't expected to replace general-purpose domains such as *work*, *personal* and *untrusted*. Also they come with some technical limitations:

- The application must support cross-compilation. No big deal;
- Single process. Obviously, fork() and execve() won't work;
- No virtual memory but again, it's presumed;
- For now, don't expect to run a GUI. Still, based on Antti's comment, it would be feasible;
- It doesn't support vchan, for now...

To fit with Qubes' communication model ([qrexec](https://www.qubes-os.org/en/doc/qrexec/)) and becomes a first class citizen, vchan is a must. The discussions I had with the Rumpkernel team (mainly Antti) says it should be pretty easy to implement.

#### Impacts on Qubes

Currently, to boot a Rumprun unikernel image we need to execute a few *special* steps: start paused, inject some config in XenStore, unpause. Fortunately, this part is managed by a very simple [shell script](https://github.com/rumpkernel/rumprun/blob/master/app-tools/rumprun) that can easily be audited and integrated to Qubes' toolstack. Even better, when challenged with this problematic, the Rumpkernel team quickly sparked a discussion to remove it altogether and try to rely solely on the hypervisor’s toolstack - like any other VM.

On the build side, it requires the integration of Rumprun's repository which includes NetBSD's source (~350MB that could be striped down) and implies trusting them for whatever domains we're building. This doesn't sound unrealistic.

### Conclusion

In this post we explored the substantial and concrete value of integrating unikernels to Qubes. We also went over the challenges and demonstrated how Rumprun seems to be a natural fit.

Now, I'm looking for constructive feedback from Qubes' community and will try to answer a few questions: What exactly would need to be modified on Qubes' side, what's the effort, what's the best course of action and ultimately, is it viable in practice?

To shed some light over the practicality of Rumprun's integration and its security value, the next post of this series will talk about the implementation of the *TCP/IP stack mitigation* case. Afterward, creating a [trusted converter](http://theinvisiblethings.blogspot.ca/2013/02/converting-untrusted-pdfs-into-trusted.html) for PDFs or pictures will underline the user experience value and possibly spawn new ideas. Stay tuned!

Interested in contributing? [Drop me a line](/about/#contact)!
