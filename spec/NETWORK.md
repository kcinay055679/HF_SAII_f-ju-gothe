# Network: Smartlearn project environment "Projekt SAII HS2026"

The single source for the network facts of the project environment. It is the input for Netzwerkplan v3 and the Datenflussplan. Check it before touching VM networking. Raw evidence (screenshots, day log) is in [tag09 work](tag09_2026-11-06/work/smartlearn-umgebung.md) and [its screenshots](tag09_2026-11-06/work/smartlearn-netzwerkplan/).

Last verified: 2026-11-12. All five VMs have working networking.

## Topology

```text
                         wan0  (10.50.0.0/16, uplink 10.50.0.1)
                           │
                  10.50.199.219
                ┌──────────┴──────────┐
                │  LF1 if229-vmLF1    │  IPFire 2.29 firewall/router
                │  DNS 9.9.9.9,       │
                │      149.112.112.112│
                └───┬─────────────┬───┘
       192.168.110.4│             │192.168.120.4
                    │             │
   lan0 192.168.110.0/24        dmz0 192.168.120.0/24
   Entwicklungsnetz             Kundennetz
   (smartlearn.lan)             (smartlearn.dmz)
   ├─ LM1 li264-vmLM1  .60      ├─ LM2 li264-vmLM2  .60
   └─ KL1 li261-vmKL1  .70      └─ KL2 li261-vmKL2  .70
                 │
            Tailscale subnet router → laptop (see Remote access)
```

## Machines

| Machine | OS | Zone | IP | MAC | Gateway | DNS | vCPU / RAM / Disk |
| --- | --- | --- | --- | --- | --- | --- | --- |
| LF1 `if229-vmLF1` | IPFire 2.29 | all | WAN 10.50.199.219/16 · LAN 192.168.110.4/24 · DMZ 192.168.120.4/24 | WAN 00:0C:29:66:a9:72 | 10.50.0.1 | 9.9.9.9, 149.112.112.112 | – |
| LM1 `li264-vmLM1.smartlearn.lan` | Ubuntu 26.04 | lan0 | 192.168.110.60/24 | 00:50:56:00:24:3d | 192.168.110.4 | 192.168.110.4, 9.9.9.9 | 1 / 15 GiB / 63 GB |
| KL1 `li261-vmKL1.smartlearn.lan` | Kali | lan0 | 192.168.110.70/24 | 00:50:56:00:24:47 | 192.168.110.4 | 192.168.110.4, 9.9.9.9 | – |
| LM2 `li264-vmLM2.smartlearn.dmz` | Ubuntu 26.04 | dmz0 | 192.168.120.60/24 | 00:50:56:00:24:3e | 192.168.120.4 | 192.168.120.4, 9.9.9.9 | 1 / 15 GiB / 63 GB |
| KL2 `li261-vmKL2.smartlearn.dmz` | Kali | dmz0 | 192.168.120.70/24 | 00:50:56:00:24:46 | 192.168.120.4 | 192.168.120.4, 9.9.9.9 | – |

All verified live over SSH or the console: default route, DNS, `ping 9.9.9.9`, `curl https://github.com` → 200.

Access and config:
- **User:** `vmadmin` everywhere. LM1 and LM2 have passwordless `sudo`.
- **SSH:** sshd runs on LM1, LM2 and KL2 (on KL2 enabled by hand). The laptop's key is installed on LM1, LM2 and KL2. KL1 is reached via Tailscale SSH.
- **Network config:** Ubuntu uses netplan + systemd-networkd (`/etc/netplan/00-eth0.yaml`; `01-eth1.yaml` keeps `eth1` down and unused). Kali uses NetworkManager, connection `eth0`.
- **Login banners:** the banners printed at login show the template's values (gateway/DNS .1, hostname `li264-vmLM`). They are static text, not the live config. Ignore them.
- **LF1 console:** takes `root`, not `vmadmin`. Its web UI is `https://192.168.110.4:444` (IPFire default, untested).

## Firewall (LF1) behaviour

| Flow | Needed for | Status |
| --- | --- | --- |
| lan0 → internet | LM1 push to GitHub, package installs | ✅ verified |
| dmz0 → internet | Argo CD on LM2 reading GitHub, image pull from the registry | ✅ verified |
| lan0 → dmz0 | KL1 tests against the Ingress on LM2, SSH into dmz0 | ✅ verified (ICMP, SSH 22). 443 untested until something listens on LM2 |
| dmz0 → lan0 | not needed | ✅ verified blocked: LM2 can't ping KL1 or open LM1:22 |
| internet → dmz0 | not needed for the course | no port forwarding |

These are IPFire's defaults: GREEN → ORANGE allowed, ORANGE → GREEN blocked, outgoing allowed. Nothing on LF1 was changed.

Why lan0 may reach the DMZ: a DMZ protects the internal network *from* the DMZ (a compromised public server can't attack inside), not the other way round. Admins manage DMZ servers from inside.

## Problems found and fixed (2026-11-12)

### 1. No VM had internet: wrong gateway

- **Symptom:** On KL1, `ping 8.8.8.8` → "From 192.168.110.70 … Destination Host Unreachable"; `curl` hung.
- **Cause:** KL1 reported the error itself, so its ARP request for the gateway got no answer. Every VM pointed at a gateway that doesn't exist: .2 from the course guide (`docs/General/eth0 kali konfig.pdf`, probably an older environment) or .1 from the VM template. LF1, the real router, answers on **.4** in both zones (read from its console).
- **Fix on Kali** (KL1 and KL2):
  ```bash
  sudo nmcli con mod eth0 ipv4.gateway 192.168.110.4 ipv4.dns "192.168.110.4 9.9.9.9"   # KL1
  sudo nmcli con mod eth0 ipv4.gateway 192.168.120.4 ipv4.dns "192.168.120.4 9.9.9.9"   # KL2
  sudo nmcli con up eth0
  ```
- **Fix on Ubuntu** (LM1): in `/etc/netplan/00-eth0.yaml`, change gateway and DNS from 192.168.110.1 to 192.168.110.4 and add 9.9.9.9, then `sudo netplan apply`.

### 2. LM2 had LM1's address: cloned VMs

- **Symptom:** Both Ubuntu VMs showed 192.168.110.60, hostname `li264-vmLM`, identical netplan files. Only the MAC differed.
- **Cause:** both are clones of one template. LM2's `eth0` is attached to `dmz0` in Smartlearn but carried the `lan0` address, so it reached nothing.
- **How they were told apart:** the Smartlearn console tab shows the VM name and the attached network (`li264-vmLM1` = `:3d` / lan0, `li264-vmLM2` = `:3e` / dmz0).
- **Fix** (typed in the LM2 console, since copy-paste into Smartlearn doesn't work):
  ```bash
  sudo sed -i 's/110\.1\b/120.4/;s/110/120/;s/\.lan/.dmz/' /etc/netplan/00-eth0.yaml && sudo netplan apply
  ```
  Then over SSH: second DNS server 9.9.9.9 added, hostname set.
- **Hostnames:** `sudo hostnamectl set-hostname li264-vmLM1` / `li264-vmLM2`, and the `127.0.1.1` line in `/etc/hosts` updated to match (`.smartlearn.lan` / `.smartlearn.dmz`).
- **Backups:** the original netplan configs are in `/root/netplan-backup-*` on LM1 and LM2.

### Final netplan on LM2 (LM1 is the same with 110 / .lan)

```yaml
network:
  ethernets:
    eth0:
      addresses:
      - 192.168.120.60/24
      routes:
        - to: default
          via: 192.168.120.4
      nameservers:
        addresses:
        - 192.168.120.4
        - 9.9.9.9
        search:
        - smartlearn.dmz
  version: 2
```

## Remote access: Tailscale subnet router on KL1

The lecturer allowed remote access. Smartlearn can't be reached from the internet: LF1's WAN 10.50.199.219 is itself a private address. So KL1 opens an outgoing tunnel.

- **KL1:** Tailscale installed (`curl -fsSL https://tailscale.com/install.sh | sh`), `net.ipv4.ip_forward=1` in `/etc/sysctl.d/99-ts.conf`, and `sudo tailscale up --ssh --qr --advertise-routes=192.168.110.0/24,192.168.120.0/24`. Login was done by scanning the QR code with a phone.
- **Admin console:** both routes approved on `li261-vmKL1`.
- **Laptop:** `sudo tailscale up --accept-routes`. Then `ssh vmadmin@192.168.110.60` (LM1), `ssh vmadmin@192.168.120.60` (LM2), `ssh vmadmin@192.168.120.70` (KL2), `ssh vmadmin@li261-vmkl1` (KL1, Tailscale SSH).
- **Source address:** traffic from the laptop arrives at the VMs from KL1's address (Tailscale SNAT), so LF1 sees ordinary lan0 → dmz0 traffic.

Risk: the tunnel makes the laptop, and anyone else on the tailnet, a member of `lan0`, bypassing LF1's "nothing from outside" protection. Mitigations:
- keep the tailnet to own devices, and enable key expiry
- narrow the routes to single hosts (e.g. `192.168.120.60/32`) if the full subnets aren't needed
- `sudo tailscale down` on KL1 when not working; remove it at semester end
- document it as a known risk in the hardening Abgabe (20.11, Zero Trust)

## Constraints for the project

- **Only 1 vCPU per LM.** Kubernetes, Argo CD, Prometheus, Grafana, ELK and the app all on LM2 will be CPU-bound. RAM (15 GiB) is fine. Prefer lightweight choices (k3s, Loki instead of ELK, few replicas), or ask the lecturer for more vCPUs.
- **No copy-paste into the Smartlearn consoles.** Do everything over SSH from the laptop. Typing in the console is only for bootstrapping.

## Open

- [ ] Test lan0 → dmz0 on 443 once the Ingress runs on LM2.
- [ ] Mattermost: on LM2 or a central instance?
- [ ] Decide whether to narrow the Tailscale routes to single hosts.

## Log

| When (2026-11-12) | What |
| --- | --- |
| afternoon | Smartlearn network plan screenshots: zones lan0 / dmz0 / wan0, firewall LF1, second Kali KL2 |
| ~18:00 | KL1 has no internet; gateway .2 unreachable |
| ~18:05 | Console banners of all VMs: LF1 is .4 in both zones; LM1 and LM2 both 192.168.110.60 |
| ~18:10 | KL1 fixed (gateway .4), then KL2 |
| ~18:25 | LM1/LM2 identified via the Smartlearn console tabs |
| ~18:45 | Tailscale on KL1, routes approved; KL2 checked over SSH |
| ~18:58 | LM1 gateway fixed and hostname set over SSH |
| ~19:10 | LM2 address fixed in the console (`sed`), finished over SSH; dmz0 → lan0 verified blocked |
