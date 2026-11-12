# Smartlearn project environment "Projekt SAII HS2026"

Read from the lecturer's Smartlearn network plan screenshots in [smartlearn-netzwerkplan/](smartlearn-netzwerkplan/) (2026-11-12). The screenshots show names and zones only, no IPs.

## Zones and machines

| Zone | Colour on the plan | Machines | Role for us |
| --- | --- | --- | --- |
| `lan0` | green | `li264-vmLM1` (Ubuntu), `li261-vmKL1` (Kali), switch `lan0` | Entwicklungsnetz: LM1 and the developer-side Kali |
| `dmz0` | yellow | `li264-vmLM2` (Ubuntu), `li261-vmKL2` (Kali), switch `dmz0` | Kundennetz: LM2 and a second Kali inside the customer zone |
| `wan0` | red | switch `wan0` | Uplink to the outside (internet, GitHub) |
| – | red | `if229-vmLF1` (firewall/router) | Connects `lan0`, `dmz0` and `wan0`. Every flow between zones passes it |

## What this changes against Netzwerkplan v2

- **Firewall between the zones:** there is a firewall, `if229-vmLF1`, between the zones. v2 drew direct arrows between LM1, Zentrale Dienste and LM2. Every cross-zone arrow now goes through LF1, and that is where the trust boundaries are.
- **Customer zone is a DMZ:** the customer zone is a DMZ (`dmz0`), not a plain "Kundennetz".
- **Second Kali:** there is a second Kali, `li261-vmKL2`, inside `dmz0`. Tests against LM2 can run from inside the DMZ (KL2) or from `lan0` through the firewall (KL1). The second case shows what the firewall lets through.
- **Zentrale Dienste:** they have no machine of their own in the environment. Git is GitHub (`HF_SAII_f-ju-gothe`), so it sits behind `wan0`, which means:
  - LM1 → LF1 → wan0 → GitHub
  - LM2 (Argo CD) → LF1 → wan0 → GitHub
  - registry likely GHCR, same path
- **`lan0` subnet:** v2 already used the name `lan0` for LM1 and KL1. The Kali config PDF gives KL1 = 192.168.110.70/24 with gateway 192.168.110.2, which is probably LF1's `lan0` interface. With LM1 = 192.168.110.60, that puts `lan0` at 192.168.110.0/24.
- **`dmz0` subnet:** the hand-drawn v1 had 192.168.200.0/24 for the customer net. That is a guess and not confirmed by the Smartlearn plan.

## Still unknown

- IP/subnet of `dmz0`, and the IPs of LM2 and KL2
- the interface IPs of LF1 (`lan0` gateway confirmed as .2? `dmz0` gateway, `wan0`)
- firewall rules on LF1: which ports `lan0` → `dmz0` and `dmz0` → `wan0` allows (we need 443 out to GitHub, 443 `lan0` → LM2 for KL1 tests)
- DNS: internal names like `*.smartlearn.lan` (LM1's hostname is `li264-vmLM1.smartlearn.lan`), and which DNS server LM2 uses
- whether Mattermost runs on LM2 or somewhere central

## Internet access (what the course material says)

The only network setup guide in `docs/` is `General/eth0 kali konfig.pdf`, four screenshots and no text:

1. On Kali, open "Advanced Network Configuration" (search "netw").
2. Edit `eth0`, tab IPv4 Settings, Method **Manual**: address `192.168.110.70`, netmask `24`, gateway `192.168.110.2`, DNS `8.8.8.8`.
3. Save, then in the panel's network menu "Disconnect" `eth0` and connect it again so the settings apply.

So in `lan0` the default gateway, and with it the way to the internet, is `192.168.110.2` (presumably LF1). Nothing in the material covers `dmz0` (LM2, KL2). The Qwen guide only lists "Internetzugriff für Downloads" as a prerequisite.

## 2026-11-12 · KL1 has no internet either

Screenshot `smartlearn-netzwerkplan/04-kl1-no-internet.png`: KL1 is configured exactly as in the guide (192.168.110.70/24, default via 192.168.110.2), but `ping 8.8.8.8` answers "From 192.168.110.70 Destination Host Unreachable". KL1 reports that itself, so it can't even reach the gateway on the local network (ARP gets no answer). Either nothing answers on 192.168.110.2 in the new project environment (LF1's `lan0` address differs, or LF1 is powered off), or the Kali guide belongs to the old environment.

## 2026-11-12 · Login banners of all machines

Screenshots `05`–`09` in [smartlearn-netzwerkplan/](smartlearn-netzwerkplan/). The banners are printed at login and may show the template's intended values rather than the live config (KL1's banner says gateway .1, its `ip r` said .2).

| Machine | IP | MAC | Gateway (banner) | DNS (banner) | Domain |
| --- | --- | --- | --- | --- | --- |
| LF1 `if229-vmLF1` (IPFire 2.29) | WAN 10.50.199.219/16 · **LAN 192.168.110.4/24** · **DMZ 192.168.120.4/24** | WAN 00:0C:29:66:a9:72 | 10.50.0.1 | 9.9.9.9, 149.112.112.112 | smartlearn.lan |
| KL1 `li261-vmKL1` | 192.168.110.70/24 | 00:50:56:00:24:47 | 192.168.110.1 | 192.168.110.1 | smartlearn.lan |
| KL2 `li261-vmKL2` | 192.168.120.70/24 | 00:50:56:00:24:46 | 192.168.120.1 | 8.8.8.8 | smartlearn.dmz |
| `li264-vmLM…` (screenshot 06) | 192.168.110.60/24 | 00:50:56:00:24:3d | 192.168.110.1 | 192.168.110.1 | smartlearn.lan |
| `li264-vmLM…` (screenshot 09) | 192.168.110.60/24 | 00:50:56:00:24:3e | 192.168.110.1 | 192.168.110.1 | smartlearn.lan |

Findings:

- **Wrong gateway on the clients:** the firewall answers on **.4** in both zones, but every client points at .1 (banner) or .2 (Kali guide). That alone explains "Destination Host Unreachable".
- **LM1 and LM2 both have 192.168.110.60:** two different MACs (`:3d`, `:3e`) with the same IP and the same truncated hostname. One of them is LM2, which belongs in `dmz0` (192.168.120.0/24), like KL2. LM2 is configured for the wrong zone.
- **Subnets:** `lan0` = 192.168.110.0/24, `dmz0` = 192.168.120.0/24 (not 192.168.200.0/24 as guessed in Netzwerkplan v1).
- **LF1 console login:** `vmadmin` was rejected on the LF1 console. IPFire's console user is `root`.

## 2026-11-12 · KL1 fixed

Setting the gateway to LF1 fixed it (`sudo nmcli con mod eth0 ipv4.gateway 192.168.110.4 ipv4.dns "192.168.110.4 9.9.9.9" && sudo nmcli con up eth0`). Screenshot `11`: ping to 192.168.110.4 and 9.9.9.9 works, and `curl https://github.com` returns the page. LF1 itself is therefore fine. Still open: KL2, LM1, LM2 (wrong zone).
