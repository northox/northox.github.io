---
published: false
layout: post
title:  "Immutable TorFirewallVM unikernel."
excerpt: ""
categories: low-level
tags:
- qubesos
- unikernel
- firewall
- tor
image:
  feature: piss-in-scotland.jpeg
  position: 'right center'
  topPosition: 0px
bgContrast: dark
bgGradientOpacity: darker
syntaxHighlighter: yes
---

_This post is the part of a series and assumes you have some basic understanding of [Qubes](https://qubes-os.org)' reason being, structure and terminology._

In the last post, I explained the advantage of replacing the FirewallVM (now called sys-firewall) with Rumprun's unikernel to fix an hypothetical flaw and drastically reduce its footprint. I've was wondering whether it was a good idea and the answer was pretty clear, [absolutely](https://groups.google.com/forum/#!msg/qubes-users/h03-1hiNMCc/C3E1IpenEAAJ). In this one, I create a simple proof of concept.

Also, since then, [Thomas Leonard](https://github.com/talex5) released a similar project using [MirageOS](https://mirage.io/) ([Ocaml](https://ocaml.org/)). This is great because both approaches have their advantages and usefulness. [Look it up](https://github.com/talex5/qubes-mirage-firewall)!

### The attack

Qubes' [architecture paper](https://www.qubes-os.org/attachment/wiki/QubesArchitecture/arch-spec-0.3.pdf) section 6.1 describe a hypothetical fatal flaw to its security model. The idea is that a single TCP/IP stack vulnerability could be used to cascade from VM to VM and break the intended isolation.

1. Inbound - from Internet to the NetVM to the FirewallVM and then to any network-enabled AppVM;
2. Local - from an untrusted/compromised VM to the FirewallVM and back to any network-enabled AppVM.
3. Outbound - from a compromised VM to the FirewallVM and to the Internet.

The reason it hasn't been fixed yet is mainly because it is thought to be very unlikely and it's prefered to work on other, more valuable things. The issue is due to the fact that the same TCP/IP codebase is used across different domains and thus acting as single point of failure. This has been documented extensively within issue [#806](https://github.com/QubesOS/qubes-issues/issues/806).

Even though there's a lot of other way I could have chosen to PoC Rumprun unikernel on Qubes, I feel this is the right place to begin as it's dressing the path to fix a potentially fatal flaw in a security oriented operating system and reducing the load of a default-and-always-on serviceVM.

### Let's use a different codebase

By making use of a different codebase, we make the attack more complex and thus less likely as the attacker need two consecutive zero-days/backdoors - one in Linux (sys-net) and one in NetBSD (sys-firewall). A fundamental assumption here is that the attack needs to be chained meaning there's little chance for a single malicious packet to directly hit the 2nd stack without being discarded by the 1st stack. In other words, we assume that using two different network stacks does not increasing the attack surface but instead expose two different attack surface consecutively.

The best place to have this different codebase is the FirewallVM as it's in the path of all AppVMs and doesn't impact much. Targeting the NetVM would  impact Qubes’s WIFI and NIC drivers support as Linux supports more devices.

![tcp ip full cascade](/img/posts/tcpip-full-cascade.png)  
![tcp ip stop cascade](/img/posts/tcpip-stop-cascade.png)  
<small>
In blue is the Rumprun FirewallVM preventing a chained Linux TCP/IP attack.
</small>

### Introducing the Rumprun TorFirewallVM

The actual PoC I came up with prevents someone from using this flaw to cascade *out* of Qubes' domain, e.g. hacking the Tor browser and getting out of the AnonVM to deanonimize a user.

--------------DOES Qubes do prevent this flaw by ????????????????? will only accepts: ????????????
----------------whonix

![tcp ip full reverse cascade](/img/posts/tcpip-full-reverse-cascade.png)
![tcp ip stop reverse cascade](/img/posts/tcpip-stop-reverse-cascade.png)
<small>
In blue is the Rumprun TorFirewallVM preventing an outbound TCP/IP exploit.
</small>

Within the next sections I'm providing a lot of information about the build process of Rumprun unikernels to reduce the learning curve of the readers. I'm convince there's tons of use cases I haven't though of or simply won't have the time to work on so pulling as much people as possible in this process is the best I can do.

If you're only interested in testing it and don't care about all of this, head straight to [rump-npfer's](https://github.com/northox/rump-npfer) repo and follow the instructions.

### Creating a Rumprun firewall

If you never seen this process before, I highly suggest looking at [rumprun-package](https://github.com/rumpkernel/rumprun-packages/) (e.g. [nginx](https://github.com/rumpkernel/rumprun-packages/tree/master/nginx)) to understand the *typical* build process which is very straightforward. This section is meant to demonstrate the work involved in creating a Rumprun unikernel running our own code interacting with driver components, i.e. the NetBSD's firewall (npf).

* The firewall isn't a binary we can wrap like we typically do. We can interact with it from a shell using the <kbd>npfctl</kbd> command but, obviously, it returns immediately after execution and thus our unikernel would die instantly. At one point, we'll need to make it act like a daemon.

* To start the firewall at boot time, normally we would simply add `npf_enable='yes'` to `rc.conf` and an init daemon would take care of it but since there's really no init daemon, we need to do it ourselves and call two commands sequentially: <kbd>npfctl reload</kbd> and <kbd>npftcl start</kbd>.

To get around this we can use rumprun's [`multibake`](https://github.com/rumpkernel/rumprun/blob/master/doc/config.md) feature. It can package the <kbd>ntpctl</kbd> binary  along with a program that <kbd>pause</kbd> or wait for user input then call them using `rc` unix-shell-like syntax that defines how they are called: in background `&`, as a pipe `|` or, the default, in foreground.

That's pretty cool because it means we can create neat unikernels without any code involved. We use the power of unix commands to create useful unikernels. Though, since eventually I want this unikernel to accept firewall rules edition dynamically, I've decided to use another approach and create my own program. I'll go over the `multibake` feature in another post.

#### The code
Ok, so we need to accomplish the same as expained above but programatically. Lets take a look at what the <kbd>npfctl</kbd> command is actually doing - [npfctl.c](http://repo.rumpkernel.org/src-netbsd/blob/appstack-src/usr.sbin/npf/npfctl/npfctl.c).

{% highlight c %}
//...

int main(int argc, char **argv)
{
  //...
  cmd = argv[1];
  //...
  for(int n = 0; operations[n].cmd != NULL; n++) {
    const char *opcmd = operations[n].cmd;
    if (strncmp(cmd, opcmd, strlen(opcmd)) != 0)
	    continue;

    npfctl(operations[n].action, argc, argv);
    return EXIT_SUCCESS;
  }
  usage();
}
{% endhighlight %}

The `main()` function calls `npfctl()` with an integer defining the actual actions to be done. This seems to be the perfect place to hook our own code. Obviously, we'll need to comment out this entire function to avoid collision with our own `main()`.

So here it is, the function declaration, the actions we need to call and an infinite loop to keep it running, i.e. `npfer.h` and `npfer.c`:

{% highlight c %}
#define NPFCTL_START 0
#define NPFCTL_RELOAD  2

void npfctl(int action, int argc, char **argv);
{% endhighlight %}

{% highlight c %}
include <stdio>
include <stdlib>
include "npfer.h"

int main(int argc, char **argv)
{
  printf("Loading npf rules.\n");
  npfctl(NPFCTL_RELOAD, argc, argv);

  printf("Starting npf.\n");
  npfctl(NPFCTL_START, argc, argv);

  printf("Sleeping forever.\n");
  for (;;) sleep(1000); // vchan request will go here

  return 0;
}
{% endhighlight %}
Yeah really, that's all the code we need.

#### Build
This part is well explained by [Rumprun's doc](http://wiki.rumpkernel.org/Repo%3A-rumprun#building) so I won't talk about how to build the toolchain but will only highlights some parts. There's two _somewhat special steps_ to make our program a unikernel: cross-compiling and baking.

##### Make - cross compile

Typically, it's only a matter of using a different compiler, i.e. on Qubes `x86_64-rumprun-netbsd-gcc`. For our `npfctl()` function call to work, we need to build and link its dependancies. All of this sorcery is taken care by <kbd>rumpmake</kbd> and this [Makefile](https://github.com/northox/rump-npfer/blob/master/Makefile). After <kbd>make npfer.bin</kbd>, we end up with this:

{% highlight bash %}
$ file npfer.bin; du -bh npfer.bin
npfer.bin: ELF 64-bit LSB relocatable, x86-64, version 1 (SYSV), not stripped
2.7M    npfer.bin
$ x86_64-rumprun-netbsd-strip npfer.bin; du -bh npfer.bin
499K    npfer.bin
{% endhighlight %}

##### Bake - convert our binary to a unikernel
To conclude the build part, the <kbd>rumprun-bake</kbd> command will integrate the required kernel components to our code in order to generate a Xen paravirtualized unikernel. But before we move ahead, we need to create a new component configuration which extend the default `xen_pv` config and add the firewall part.

{% highlight bash %}
$ cat npfer-bake.conf
version 20150930 # keep in sync with rumprun-bake.conf

create xen_pv_npf "Xen paravirtualized I/O AND npf"
  assimilate xen_pv_npf xen_pv # include xen_pv
  add xen_pv_npf -lrumpnet_npf # ... add the firewall
{% endhighlight %}

Put it in the oven...

{% highlight bash %}
$ rumprun-bake -c npfer-bake.conf xen_pv_npf npfer npfer.bin
$ file npfer; du -bh npfer
npfer: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, not stripped
22M    npfer
$ x86_64-rumprun-netbsd-strip npfer; du -bh npfer
5.2M    npfer
{% endhighlight %}

...and we're done. As simple as that.

This image constains our code, npfctl's stuff and all the components describe by `xen_pv_npf`:

{% highlight bash %}
$ rumprun-bake -c npfer-bake.conf describe xen_pv_npf
-lrumpvfs -lrumpkern_bmktc -lrumpdev -lrumpfs_tmpfs
-lrumpnet_config -lrumpnet -lrumpdev_bpf -lrumpdev_vnd
-lrumpdev_rnd -lrumpnet_netinet -lrumpnet_net
-lrumpnet_netinet6 -lrumpnet_local -lrumpfs_ffs
-lrumpfs_cd9660 -lrumpfs_ext2fs -lrumpdev_disk
-lrumpkern_sysproxy -lrumpfs_kernfs -lrumpnet_xenif
-lrumpxen_xendev -lrumpnet_npf
{% endhighlight %}

Not much but still, we could likely remove even more.

#### Setup and configuration

On dom0's part, we need two configuration files ([`xen.conf`](https://github.com/northox/rump-npfer/dom0/xen.conf), [`rump.conf`](https://github.com/northox/rump-npfer/dom0/rump.conf)) and one filesystem file ([`etc.iso`](https://github.com/northox/rump-npfer/dom0/fs/etc/)).

- Among other things, the two config files create two network interfaces and mount `etc.iso` to `/etc`. Typically we don't need to bother with those as the [<kbd>rumprun</kbd>](http://repo.rumpkernel/rumprun/blob/master/app-tools/rumprun) script takes care of them but since its future isn't quite clear and we need to understand and control the nitty-gritty details for Qubes' integration, I prefered to avoid the script altogether. This isn't a problem as its [json format](https://github.com/rumpkernel/rumprun/blob/master/doc/config.md) is very easy to understand and mostly needs to be kept in sync with `xen.conf` which you, hopefully, already understand.
- The `etc.iso` file contain a filesystem version of what's in [dom0/fs/etc](https://github.com/northox/rump-npfer/dom0/fs/etc/). This is where you can find [`npf.conf`](https://github.com/northox/rump-npfer/dom0/fs/etc/npfctl.conf).

#### Run

For basic test, to manually start the machine without Qubes's toolstack I used something like the following which does the start-paused-inject-unpaused dance I've talked about in the last post.

{% highlight bash %}
dom0$ sudo xl create -p xen.conf &&
      export ID=`xl domid npfer` &&
      xenstore-write /local/domain/$ID/rumprun/cfg "`cat rump.conf`" &&
      xl unpause $ID &&
      ./fix-console $ID &&
      sudo xl console $ID
...snip...
NetBSD 7.99.21 (RUMP-ROAST)
...snip...

=== calling "npfer" main() === ****************************************************************** set bpf.jit off

Loading firewall rules...
Starting firewall...
Sleeping forever.
{% endhighlight %}
<small>
The entire boot output is available [here](/misc/npfer.boot.txt).
</small>

That's it, up and running... but it can't do much as it's not interconnected to other VMs.

##### Qubes toolstack integration

I've found the integration with Qubes v3 to be very messy and cumbersome but seems like the next version should fix most irritation (Qubes release 4 with core3).

<kbd>qvm-create -p -l green rump-firewall</kbd>

<kbd>qvm-prefs rump-firewall</kbd>

autostart true
vcpus 1
memory 32
maxmem 32 - both = means remove balancing
kernel rump-npfer
netvm sys-net

<kbd>qvm-start rump-firewall</kbd>

cp etc.iso over xvdb private.img ***************
route add default 10.137.2.1

the road ahead
Replacing the sys-firewall with npfer will require a lot more work:

- Add Xen's vchan support to rumprun
- Qubes OS v4 (with QubesDB v3) for none linux specific firewall rules and hopefully, proper hooks.

### Usage - Modifying the rules, npf.conf

In the mean time, to change the rules we need to edit `npf.conf` manually, rebuild etc iso, copy it over to dom0 and restart the unikernel. I've made this process relatively easy:

{% highlight bash %}
$ vi fs/etc/npf.conf
$ make etc.iso
$ file etc.iso; du -bh etc.iso
XXK    etc.iso ********************************************
{% endhighlight %}
...and in dom0:

{% highlight bash %}
dom0$ npfer-update-rules
Copying etc.iso from work-devel ************************
Restarting rump-firewall ***************
{% endhighlight %}

### Some test

Latency
Throughput
Memory usage

### Conclusion

In this post, went over the steps to build Rumprun unikernels that interacts with kernel components and describe the missing parts to replace the Linux based FirewallVM.








{% comment %}

Thomas [blog post](http://roscidus.com/blog/blog/2016/01/01/a-unikernel-firewall-for-qubesos/) covers Qubes' networking so I won't go over it.


----------

What exactly would need to be modified on Qubes' side to be part of the default installation?
- we need QubesDB v3 ??
What's the effort?
- significant until v3 and unknown but less with v3
What's the best course of action?
Is it viable in practice? Does it make sense?
After my post and Thomas


//Assuming the exploit would be caught by the first stack on the path of a malicious packet,// by making use of a completely different codebase we double the difficulties of such an attack - two zero-day and/or backdoor needed.


### Perfection would

There's a few important assumption potential problems with this approach as it assumes the flaw would always be triggered by the first hop the attack encounters. What if the flaw can affect a specific hop, possibly based on the Time To Live (TTL) IP header.

IMAGE

Stats of TCP/IP attack surface.
relatively new code: SCTP, IPv6
how many line of codes?
{% endcomment %}
