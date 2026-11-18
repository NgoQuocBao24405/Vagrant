# Kế hoạch địa chỉ IP – lab "congty"

Nguồn sự thật duy nhất: mọi `frr.conf`, lệnh `exec` trong topology và zone DNS đều suy ra từ bảng này.

## Hạ tầng

| Mạng | Dải | Ghi chú |
|---|---|---|
| VirtualBox NAT (NIC1) | 10.0.2.0/24 | VM ra Internet; SSH qua 127.0.0.1:2222 |
| Host-only (NIC2) | 192.168.56.0/24 | Windows .1, VM `may-ao-lab` .10 |
| Mgmt containerlab `clab` | 172.20.20.0/24 | GW 172.20.20.1 = VM |
| Compose `svc-test` | Docker tự cấp | chỉ để chạy thử |

## Liên kết

| Tên dây | Đầu A | Đầu B | Mạng | Vai trò |
|---|---|---|---|---|
| day-tru-so-bien | router-tru-so eth1 10.0.0.1/30 | router-bien eth1 10.0.0.2/30 | 10.0.0.0/30 | OSPF area 0 |
| day-tru-so-chi-nhanh | router-tru-so eth2 10.0.0.5/30 | router-chi-nhanh eth1 10.0.0.6/30 | 10.0.0.4/30 | OSPF area 1 (đường chính Branch–HQ) |
| day-bien-chi-nhanh | router-chi-nhanh eth2 10.0.0.9/30 | router-bien eth2 10.0.0.10/30 | 10.0.0.8/30 | OSPF area 1 (dự phòng, ra Internet) |
| day-bien-nha-mang | router-bien eth3 203.0.113.2/30 | router-nha-mang eth1 203.0.113.1/30 | 203.0.113.0/30 | eBGP AS65001 ↔ AS65000 |
| day-lan-tru-so | router-tru-so eth3 192.168.10.1/24 | may-tinh-tru-so eth1 .100 | 192.168.10.0/24 | LAN HQ người dùng |
| day-tru-so-switch | router-tru-so eth4 192.168.20.1/24 | switch-may-chu sw-tru-so | 192.168.20.0/24 | LAN HQ máy chủ |
| day-web-switch | may-chu-web eth1 192.168.20.10/24 | switch-may-chu sw-web | 192.168.20.0/24 | Web |
| day-dns-switch | may-chu-dns eth1 192.168.20.53/24 | switch-may-chu sw-dns | 192.168.20.0/24 | DNS |
| day-lan-chi-nhanh | router-chi-nhanh eth3 192.168.30.1/24 | may-tinh-chi-nhanh eth1 .100 | 192.168.30.0/24 | LAN Branch |
| day-nha-mang-internet | router-nha-mang eth2 198.51.100.1/24 | may-ngoai-internet eth1 .10 | 198.51.100.0/24 | "Internet" |

## Node

| Node | Image | Mgmt | Loopback / IP | Vai trò |
|---|---|---|---|---|
| router-tru-so | FRR 10.7.1 | 172.20.20.11 | 10.255.0.1 | ABR (area 0/1) |
| router-chi-nhanh | FRR 10.7.1 | 172.20.20.12 | 10.255.0.2 | router trong area 1 |
| router-bien | FRR 10.7.1 | 172.20.20.13 | 10.255.0.3 | ABR + ASBR, eBGP AS65001 |
| router-nha-mang | FRR 10.7.1 | 172.20.20.14 | 10.255.0.4 | ISP AS65000, phát default |
| may-tinh-tru-so | netshoot v0.16 | 172.20.20.21 | 192.168.10.100 | client HQ, iperf3 server |
| may-tinh-chi-nhanh | netshoot v0.16 | 172.20.20.22 | 192.168.30.100 | client Branch |
| may-ngoai-internet | netshoot v0.16 | 172.20.20.41 | 198.51.100.10 | máy "Internet" |
| may-chu-web | congty/web:1.0 | 172.20.20.31 | 192.168.20.10 | Nginx |
| may-chu-dns | congty/dns:1.0 | 172.20.20.32 | 192.168.20.53 | BIND9, zone congty.lab |

## Zone congty.lab

Tên dịch vụ: `ns1` 192.168.20.53 · `web` 192.168.20.10 · `www` → web · `inet` 198.51.100.10

Tên thiết bị: `may-chu-dns` .20.53 · `may-chu-web` .20.10 · `may-tinh-tru-so` 192.168.10.100 · `may-tinh-chi-nhanh` 192.168.30.100 · `may-ngoai-internet` 198.51.100.10 · `router-tru-so/router-chi-nhanh/router-bien` 10.255.0.1/2/3

## Bảng đổi tên (17/11/2026)

Tên cũ chỉ còn trong các file bằng chứng `docs/evidence/` ghi trước ngày đổi.

| Loại | Tên cũ | Tên mới |
|---|---|---|
| Router trụ sở (ABR) | r-hq | router-tru-so |
| Router chi nhánh | r-br | router-chi-nhanh |
| Router biên (ABR + ASBR) | r-edge | router-bien |
| Router nhà mạng (ISP) | r-isp | router-nha-mang |
| Máy tính trụ sở | pc-hq1 | may-tinh-tru-so |
| Máy tính chi nhánh | pc-br1 | may-tinh-chi-nhanh |
| Máy chủ web | srv-web | may-chu-web |
| Máy chủ DNS | srv-dns | may-chu-dns |
| Máy ngoài Internet | inet-host | may-ngoai-internet |
| Switch LAN máy chủ (bridge) | br-srv | switch-may-chu |
| Cổng bridge | p1-rhq / p2-web / p3-dns | sw-tru-so / sw-web / sw-dns |
| Tên container | clab-congty-&lt;node&gt; | &lt;node&gt; (topology đặt `prefix: ""`) |
| Dây | L01 | day-tru-so-bien |
| Dây | L02 | day-tru-so-chi-nhanh |
| Dây | L03 | day-bien-chi-nhanh |
| Dây | L04 | day-bien-nha-mang |
| Dây | L05 | day-lan-tru-so |
| Dây | L06 | day-tru-so-switch |
| Dây | L07 | day-web-switch |
| Dây | L08 | day-dns-switch |
| Dây | L09 | day-lan-chi-nhanh |
| Dây | L10 | day-nha-mang-internet |
| Máy ảo (VM) | clab-host | may-ao-lab |
| Script | scripts/deploy.sh | scripts/dung-lab.sh |
| Script | scripts/destroy.sh | scripts/go-lab.sh |
| Script | scripts/save.sh | scripts/luu-cau-hinh.sh |
| Script | scripts/provision.sh | scripts/cai-dat-may-ao.sh |
| Script | scripts/host-check.ps1 | scripts/kiem-tra-may-windows.ps1 |
| Script | scripts/box-archive.ps1 | scripts/luu-tru-box.ps1 |
| Script (mới) | – | scripts/cau-hinh-ssh.sh |
| Tài liệu | docs/ip-plan.md | docs/bang-dia-chi-ip.md |
| Tài liệu | docs/weekly-log.md | docs/nhat-ky-tuan.md |
