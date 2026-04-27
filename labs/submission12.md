# Submission 12 — Kata Containers: VM-backed Container Sandboxing

> Repo: `DevSecOps-Intro`  
> Lab: `labs/lab12.md`

## Environment

- **Host OS / kernel**: `Linux fedora 6.19.10-200.fc43.x86_64 #1 SMP PREEMPT_DYNAMIC Wed Mar 25 16:09:19 UTC 2026 x86_64 GNU/Linux`
- **CPU virtualization flags count**: `16`
- **containerd**: `containerd containerd.io v2.2.2 301b2dac98f15c27117da5c8af12118a041a31d9`
- **nerdctl**: `nerdctl version 2.2.2`

---

## Task 1 — Install and Configure Kata (2 pts)

### Shim version

```text
Kata Containers containerd shim (Rust): id: io.containerd.kata.v2, version: 3.29.0, commit: d5785b4eba8c05dc9a82bdf35199b6298816936d
```

### Kata test run

```text
Linux 0f5aa85eacad 6.18.15 #1 SMP Sat Apr 18 10:30:20 UTC 2026 x86_64 Linux
```

---

## Task 2 — Run and Compare Containers (runc vs kata) (3 pts)

### Juice Shop (runc) health check

```text
juice-runc: HTTP 200
```

### Kata container evidence

```text
Linux 3468d66fa0d6 6.18.15 #1 SMP Sat Apr 18 10:30:20 UTC 2026 x86_64 Linux
6.18.15
model name	: Intel(R) Xeon(R) Processor @ 1.80GHz
```

### Kernel comparison

```text
=== Kernel Version Comparison ===
Host kernel (runc uses this): 6.19.10-200.fc43.x86_64
Kata guest kernel: Linux version 6.18.15 (@1612ad5dd3e1) (gcc (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, GNU ld (GNU Binutils for Ubuntu) 2.38) #1 SMP Sat Apr 18 10:30:20 UTC 2026
```

### CPU comparison

```text
=== CPU Model Comparison ===
Host CPU:
model name	: Intel(R) Core(TM) i7-10510U CPU @ 1.80GHz
Kata VM CPU:
model name	: Intel(R) Xeon(R) Processor @ 1.80GHz
```

### Isolation implications (brief)

- **runc**: uses the **host kernel**; isolation is namespaces/cgroups/seccomp/LSM. Kernel escape can become a **host compromise boundary**.
- **Kata**: workload runs in a **VM with its own guest kernel**; escape typically needs a **guest + hypervisor boundary** break for host impact.

---

## Task 3 — Isolation Tests (3 pts)

### dmesg (guest kernel evidence)

```text
=== dmesg Access Test ===
Kata VM (separate kernel boot logs):
time="2026-04-27T16:48:21+03:00" level=warning msg="default network named \"bridge\" does not have an internal nerdctl ID or nerdctl-managed config file, it was most likely NOT created by nerdctl"
time="2026-04-27T16:48:21+03:00" level=warning msg="cannot set cgroup manager to \"systemd\" for runtime \"io.containerd.kata.v2\""
[    0.000000] Linux version 6.18.15 (@1612ad5dd3e1) (gcc (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, GNU ld (GNU Binutils for Ubuntu) 2.38) #1 SMP Sat Apr 18 10:30:20 UTC 2026
[    0.000000] Command line: reboot=k panic=1 systemd.unit=kata-containers.target systemd.mask=systemd-networkd.service root=/dev/vda1 rootflags=data=ordered,errors=remount-ro ro rootfstype=ext4 agent.container_pipe_size=1 console=ttyS1 agent.log_vport=1025 agent.passfd_listener_port=1027 virtio_mmio.device=8K@0xe0000000:5 virtio_mmio.device=8K@0xe0002000:5
[    0.000000] BIOS-provided physical RAM map:
```

### /proc visibility

```text
=== /proc Entries Count ===
Host: 502
Kata VM: 51
```

### Network interfaces (Kata VM)

```text
=== Network Interfaces ===
Kata VM network:
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether 1e:f5:06:07:a4:29 brd ff:ff:ff:ff:ff:ff
    inet 10.88.0.11/16 brd 10.88.255.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::1cf5:6ff:fe07:a429/64 scope link tentative 
       valid_lft forever preferred_lft forever
```

### Kernel modules count (host vs guest)

```text
=== Kernel Modules Count ===
Host kernel modules: 371
Kata guest kernel modules: 72
```

### Security interpretation

- **Container escape in runc**: same kernel boundary → higher blast radius if attacker reaches kernel context.
- **Container escape in Kata**: usually compromises guest VM first → needs **second-stage** hypervisor/host escape for host impact.

---

## Task 4 — Performance Comparison (2 pts)

### Startup time (runc vs Kata)

```text
=== Startup Time Comparison ===
runc:
real	0m1.426s
Kata:
real	0m3.689s
```

### HTTP latency baseline (Juice Shop under runc)

```text
avg=0.0054s min=0.0038s max=0.0126s n=50
```

### Recommendations

- **Use runc when**: fastest startup, simplest ops, low overhead, trusted workloads or strong kernel hardening.
- **Use Kata when**: multi-tenant/untrusted workloads, need stronger isolation boundary than namespaces.

