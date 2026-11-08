# Kế hoạch địa chỉ IP – lab "abc"

Nguồn sự thật duy nhất: mọi `frr.conf`, lệnh `exec` trong topology và zone DNS đều suy ra từ bảng này.

## Hạ tầng

| Mạng | Dải | Ghi chú |
|---|---|---|
| VirtualBox NAT (NIC1) | 10.0.2.0/24 | VM ra Internet; SSH qua 127.0.0.1:2222 |
| Host-only (NIC2) | 192.168.56.0/24 | Windows .1, VM `clab-host` .10 |
| Mgmt containerlab `clab` | 172.20.20.0/24 | GW 172.20.20.1 = VM |
| Compose `svc-test` | Docker tự cấp | chỉ để chạy thử |

## Liên kết

| Mã | Đầu A | Đầu B | Mạng | Vai trò |
|---|---|---|---|---|
| L01 | r-hq eth1 10.0.0.1/30 | r-edge eth1 10.0.0.2/30 | 10.0.0.0/30 | OSPF area 0 |
| L02 | r-hq eth2 10.0.0.5/30 | r-br eth1 10.0.0.6/30 | 10.0.0.4/30 | OSPF area 1 (đường chính Branch–HQ) |
| L03 | r-br eth2 10.0.0.9/30 | r-edge eth2 10.0.0.10/30 | 10.0.0.8/30 | OSPF area 1 (dự phòng, ra Internet) |
| L04 | r-edge eth3 203.0.113.2/30 | r-isp eth1 203.0.113.1/30 | 203.0.113.0/30 | eBGP AS65001 ↔ AS65000 |
| L05 | r-hq eth3 192.168.10.1/24 | pc-hq1 eth1 .100 | 192.168.10.0/24 | LAN HQ người dùng |
| L06 | r-hq eth4 192.168.20.1/24 | br-srv p1-rhq | 192.168.20.0/24 | LAN HQ máy chủ |
| L07 | srv-web eth1 192.168.20.10/24 | br-srv p2-web | 192.168.20.0/24 | Web |
| L08 | srv-dns eth1 192.168.20.53/24 | br-srv p3-dns | 192.168.20.0/24 | DNS |
| L09 | r-br eth3 192.168.30.1/24 | pc-br1 eth1 .100 | 192.168.30.0/24 | LAN Branch |
| L10 | r-isp eth2 198.51.100.1/24 | inet-host eth1 .10 | 198.51.100.0/24 | "Internet" |

## Node

| Node | Image | Mgmt | Loopback / IP | Vai trò |
|---|---|---|---|---|
| r-hq | FRR 10.7.1 | 172.20.20.11 | 10.255.0.1 | ABR (area 0/1) |
| r-br | FRR 10.7.1 | 172.20.20.12 | 10.255.0.2 | router trong area 1 |
| r-edge | FRR 10.7.1 | 172.20.20.13 | 10.255.0.3 | ABR + ASBR, eBGP AS65001 |
| r-isp | FRR 10.7.1 | 172.20.20.14 | 10.255.0.4 | ISP AS65000, phát default |
| pc-hq1 | netshoot v0.16 | 172.20.20.21 | 192.168.10.100 | client HQ, iperf3 server |
| pc-br1 | netshoot v0.16 | 172.20.20.22 | 192.168.30.100 | client Branch |
| inet-host | netshoot v0.16 | 172.20.20.41 | 198.51.100.10 | máy "Internet" |
| srv-web | abc/web:1.0 | 172.20.20.31 | 192.168.20.10 | Nginx |
| srv-dns | abc/dns:1.0 | 172.20.20.32 | 192.168.20.53 | BIND9, zone abc.lab |

## Zone abc.lab

`ns1` 192.168.20.53 · `web` 192.168.20.10 · `www` → web · `pc-hq1` 192.168.10.100 · `pc-br1` 192.168.30.100 · `r-hq/r-br/r-edge` 10.255.0.1/2/3 · `inet` 198.51.100.10
