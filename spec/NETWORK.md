# Network: Smartlearn project environment "Projekt SAII HS2026"

The single source for the network facts of the project environment. It is the input for Netzwerkplan v3 and the Datenflussplan. Raw evidence (screenshots, day log) is in [tag09 work](tag09_2026-11-06/work/smartlearn-umgebung.md) and [its screenshots](tag09_2026-11-06/work/smartlearn-netzwerkplan/).

Last verified: 2026-11-12

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
   ├─ LM1 li264-vmLM1  .60      ├─ LM2 li264-vmLM2  ? (see below)
   └─ KL1 li261-vmKL1  .70      └─ KL2 li261-vmKL2  .70
```

## Machines

| Machine | OS | Zone | IP | MAC | Gateway | DNS | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| LF1 `if229-vmLF1` | IPFire 2.29 | all | WAN 10.50.199.219/16 · LAN 192.168.110.4/24 · DMZ 192.168.120.4/24 | WAN 00:0C:29:66:a9:72 | 10.50.0.1 | 9.9.9.9, 149.112.112.112 | ✅ routes to the internet |
| KL1 `li261-vmKL1.smartlearn.lan` | Kali | lan0 | 192.168.110.70/24 | 00:50:56:00:24:47 | 192.168.110.4 | 192.168.110.4, 9.9.9.9 | ✅ fixed, internet works |
| KL2 `li261-vmKL2` | Kali | dmz0 | 192.168.120.70/24 | 00:50:56:00:24:46 | 192.168.120.4 | 192.168.120.4, 9.9.9.9 | ✅ fixed, internet works |
| LM1 `li264-vmLM1` | Ubuntu 26.04 | lan0 | 192.168.110.60/24 | 00:50:56:00:24:3d | 192.168.110.1 (banner) | 192.168.110.1 (banner) | ⚠️ gateway wrong, not fixed yet |
| LM2 `li264-vmLM2` | Ubuntu 26.04 | dmz0 | **192.168.110.60/24 (wrong zone)**, target 192.168.120.60/24 | 00:50:56:00:24:3e | 192.168.110.1 (banner) | 192.168.110.1 (banner) | ❌ wrong subnet, not fixed yet |

The LM gateway/DNS values come from the login banners. They may not be the live config: KL1's banner showed .1 while its real route pointed at .2.

## Problem: no internet on the VMs

**Symptom.** On KL1, `ping 8.8.8.8` returned "From 192.168.110.70 … Destination Host Unreachable", and `curl` hung.

**Cause.** KL1 reported the error itself, which means its ARP request for the gateway got no answer on `lan0`. Every client pointed at a gateway that doesn't exist:
- the course guide (`docs/General/eth0 kali konfig.pdf`) says 192.168.110.2, probably from an older environment
- the login banners say .1

The firewall LF1 actually answers on **.4** in both zones, as its own console shows.

**Second problem.** Both Ubuntu VMs have 192.168.110.60 (MACs `:3d` and `:3e`). LM2 belongs in `dmz0` (192.168.120.0/24), like KL2. It can't work where it is: it is either attached to `dmz0` with a `lan0` address, or it collides with LM1.

**Fix on Kali (done on KL1 and KL2).** NetworkManager, connection `eth0`:

```bash
# lan0 (KL1)
sudo nmcli con mod eth0 ipv4.gateway 192.168.110.4 ipv4.dns "192.168.110.4 9.9.9.9"
# dmz0 (KL2)
sudo nmcli con mod eth0 ipv4.gateway 192.168.120.4 ipv4.dns "192.168.120.4 9.9.9.9"

sudo nmcli con up eth0
ping -c2 9.9.9.9 && curl -sI https://github.com | head -1
```

Verified: KL1 reaches 192.168.110.4, 9.9.9.9 and github.com. The user confirmed that KL2 has internet too.

**Fix on Ubuntu (to do on LM1 and LM2).** Edit the file in `/etc/netplan/`, then run `sudo netplan try`, which rolls back on its own unless confirmed:

```yaml
# LM1 (lan0)
network:
  version: 2
  ethernets:
    <iface>:                    # from `ip -br a`
      dhcp4: false
      addresses: [192.168.110.60/24]
      routes: [{to: default, via: 192.168.110.4}]
      nameservers: {addresses: [192.168.110.4, 9.9.9.9], search: [smartlearn.lan]}
```

For LM2 (dmz0) use `addresses: [192.168.120.60/24]`, `via: 192.168.120.4`, DNS `192.168.120.4, 9.9.9.9` and `search: [smartlearn.dmz]`. 192.168.120.60 is our choice to mirror KL2's .70; check it's free first (`ping 192.168.120.60` from KL2 should get no answer). To tell the two VMs apart, `hostnamectl` on each shows the full hostname.

## The two Ubuntu VMs are clones

Screenshots `13` and `14` show both Ubuntu VMs with identical config:
- **hostname:** `li264-vmLM.smartlearn.lan`, with no 1 or 2
- **eth0:** UP, 192.168.110.60/24, default via 192.168.110.1
- **eth1:** DOWN
- **netplan files:** `00-eth0.yaml`, `01-eth1.yaml`

They differ only in their MAC (`…:24:3d` and `…:24:3e`, readable from the IPv6 link-local address). The hostname can't tell them apart, so the test is which one reaches KL1 (192.168.110.70). KL1 only lives in `lan0`, so the VM that gets an answer is LM1. Once identified, set the hostnames to `li264-vmLM1` and `li264-vmLM2`.

**Identified** (screenshots `15`, `16`): the Smartlearn console tabs show the VM name and the attached network. `li264-vmLM1` = MAC `:3d`, attached to `lan0`. `li264-vmLM2` = MAC `:3e`, attached to `dmz0`. So LM2's `eth0` is plugged into `dmz0` but carries a `lan0` address.

## Firewall (LF1) behaviour

| Flow | Needed for | Status |
| --- | --- | --- |
| lan0 → internet (ICMP, HTTPS) | LM1 push to GitHub, package installs | ✅ works from KL1 |
| dmz0 → internet (HTTPS) | Argo CD on LM2 reading GitHub, image pull from the registry | ✅ works from KL2 |
| lan0 → dmz0 | KL1 tests against the Ingress on LM2, SSH into dmz0 | ✅ verified 2026-11-12: KL1 pings 192.168.120.4 and KL2, KL2's port 22 is open (443 untested until something listens) |
| dmz0 → lan0 | not needed | should stay blocked. IPFire blocks ORANGE → GREEN by default |
| internet → dmz0 | not needed for the course | no port forwarding planned |

The IPFire console takes `root`, not `vmadmin` (that login was rejected). Only needed if LF1 itself ever has to be checked.

## Open

- [ ] LM1 and LM2: identify which is which, then apply the netplan fix. LM2 moves to 192.168.120.60.
- [ ] Test lan0 → dmz0 on 443 once something listens on LM2.
- [ ] Mattermost: on LM2 or a central instance?

## Remote access: Tailscale subnet router on KL1

Setup (2026-11-12): KL1 runs Tailscale with `--ssh --advertise-routes=192.168.110.0/24,192.168.120.0/24` and IP forwarding on. The laptop reaches all VMs through KL1.

Why this reaches `dmz0`: a DMZ protects the internal network *from* the DMZ, not the other way round. LF1 lets lan0 → dmz0 through (IPFire default GREEN → ORANGE allowed), because admins manage DMZ servers from inside. It blocks dmz0 → lan0 (ORANGE → GREEN), so a compromised DMZ server can't attack the internal network. The internet can't open connections into the DMZ either, except for explicitly published services.

Risk: the tunnel makes the laptop, and anyone else on the tailnet, a member of `lan0`, passing LF1 as if it were inside. That is acceptable for a lab (allowed by the lecturer), but:

- keep the tailnet to own devices, and enable key expiry
- advertise only what's needed (e.g. `192.168.120.60/32` instead of the whole `dmz0`) if the full subnets aren't used
- `sudo tailscale down` when not working on the project; remove it at the end of the semester
- document it as a known risk in the hardening Abgabe (20.11, ZeroTrust)

Status 2026-11-12:
- **Tunnel:** laptop ↔ KL1 works. Tailscale SSH to `li261-vmkl1` works, and KL1 advertises both subnets with IP forwarding on. The routes are **not yet approved** in the admin console, so the laptop can't reach 192.168.x directly yet.
- **Jump host:** `ssh -J vmadmin@li261-vmkl1 vmadmin@192.168.120.70` reaches KL2's sshd. Login needs the password or a key.
- **LM1:** port 22 is open, reached from KL1.
- **LM2:** 192.168.120.60 doesn't answer yet (netplan fix pending).

Status 2026-11-12 (later): routes approved. The laptop reaches both subnets directly through KL1. KL2 checked over SSH (key login works):
- `li261-vmKL2.smartlearn.dmz`, 192.168.120.70/24
- default via 192.168.120.4, DNS 192.168.120.4 + 9.9.9.9
- ping 9.9.9.9 OK, `curl https://github.com` → HTTP/2 200
- sshd active and enabled

LM1 answers ping and SSH, but there is no key on it yet. LM2 (192.168.120.60) doesn't answer yet.
