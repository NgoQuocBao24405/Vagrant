# Nhật ký tuần

Mỗi tuần ghi: đã làm gì, lệnh/kết quả quan trọng (dán output), lỗi gặp và cách xử lý, quyết định đã chọn.

## Tuần 1–3 (12/10 – 01/11/2026)
- Đã cài Vagrant 2.4.9, VirtualBox 7.2.22r175245.
- Box `bento/ubuntu-24.04 (virtualbox, 202510.26.0, amd64)` đã có trong cache.

## Tuần 4 (02/11 – 08/11/2026)
- Máy: Acer Nitro AN515-57, i7-11800H, 16 GB RAM, Windows 11 Pro 25H2 (build 26200).
- `HyperVisorPresent=True`, Memory integrity đang chạy (08/11). Quyết định xử lý: **HypervisorPresent vẫn True, chấp nhận chế độ NEM** (rủi ro đã ghi nhận). Đo được: `vagrant up` lần đầu (có provision) 204 s, `vagrant up` sau snapshot 56 s, `vagrant provision` lần 2 21 s.
- Box đã lưu trữ: `D:\vagrant-boxes\bento-ubuntu-24.04-202510.26.0-virtualbox-amd64.box` (649 771 027 byte), SHA256 = `f77c344626eb150d6426435b30eee267d406272a3646c1ba25b4cd58bd630494`. Evidence: `TC02_host-check_truoc.txt`.
- Lỗi `vagrant up` lần 1 (`TC03_vagrant_up_lan1_loi.log`): provision dừng ngay sau `apt-get update` repo Docker. Nguyên nhân: `apt_ver` trong `provision.sh` dùng `awk … exit`, awk thoát sớm làm `apt-cache` nhận SIGPIPE (mã 141), `set -o pipefail` + `set -e` dừng script. Sửa: awk đọc hết input. `vagrant destroy -f` rồi `up` lại thì thành công (`TC03_vagrant_up.log`).
- Lần đầu kéo `nicolaka/netshoot:v0.16` lỗi tạm thời (mạng); `docker pull` lại thì được, `provision` lần 2 thấy image đã có.
- TC04: `vagrant provision` lần 2 in "da co", không cài gì thêm (`TC04_provision_lan2.log`).
- TC07: Docker 29.9.2 / Compose v5.6.1 / containerlab 0.82.0, giữ phiên bản bằng `apt-mark hold`; storage overlayfs, cgroup v2 + systemd (`TC07_docker_ok.log`).
- Snapshot `base-docker` đã lưu (`W4_snapshot.log`).

## Tuần 5 (09/11 – 15/11/2026)
- TC08: Compose web + dns healthy sau ~12 s; `curl -I 127.0.0.1:8080` → 200; `dig … web.congty.lab` → 192.168.20.10; BIND 9.20.30. Từ Windows `http://192.168.56.10:8080` không kết nối được (đúng thiết kế) (`TC08_compose.log`).
- TC09: veth ↔ bridge `br-<id>`, `eth0@if15` trong namespace dns, DNAT chỉ cho `127.0.0.1`; sau `compose down` còn 0 veth (`TC09_docker_network.log`).
- frr01: chờ 40 s thì OSPF còn ExStart (hội tụ chậm ở chế độ NEM); sau 60 s cả 2 neighbor Full, PC1 → PC3 ping OK (`W5_frr01.log`).
- Lab congty: `deploy_s=10`, OSPF hội tụ ~18 s, `kiem-tra-nhanh.sh` 13/13 PASS (`W5_lab_deploy.log`, `W5_lab_smoke.log`, `W5_lab_routing.log`).

## Tuần 6 (16/11 – 22/11/2026)
- Chạy `bash tests/kiem-thu-tuan6.sh` ngày 16/11 trên máy Shiro (NEM): **6/6 PASS** (`W6_summary.log`). Toàn bộ script 64 s.
- TC10: `Topology is valid name=congty nodes=10 links=10`. TC11: bản có `extras` bị từ chối ("the extras node field is removed").
- TC12: 9 container running + `br-srv` 3 cổng; `deploy_s=10`, cả `deploy.sh` (kèm chờ OSPF) 18 s.
- TC13: r-hq, r-br, r-edge mỗi router 2 neighbor `Full/-`; r-br có `N IA 192.168.10.0/24`, `N IA 192.168.20.0/24`, `N E2 0.0.0.0/0`; 10.255.0.1 = ABR, 10.255.0.3 = ABR/ASBR. Khóa JSON xác nhận trên 10.7.1: `neighbors` → mảng, `nbrState` = "Full/-", `converged` = "Full".
- Lỗi gặp: lần chạy 1 TC13 FAIL vì kiểm tra ~1 s sau khi neighbor Full, SPF chưa tính tuyến. Sửa script: chờ tối đa 90 s tới khi có 2 tuyến IA (thực tế 4 s). Lab không sai.
- TC18: cổng SSH 22 của r-hq mở; `containerlab exec`, `docker exec … show version` (FRRouting 10.7.1_git) OK; `graph --mermaid` tạo `~/clab-runtime/clab-congty/graph/so-do-mang-congty.clab.mermaid`; web graph :50080 trả 200.
- TC19: description eth3 của r-hq đổi thành `TEST-TC19` → `save.sh` → `destroy.sh` → `deploy.sh` → vẫn còn. Ghi nhận: `save.sh` xuất định dạng chuẩn FRR 10.7.1 (thêm `exit`, đổi thứ tự lệnh) nên lần lưu đầu diff cả 4 tệp; nghĩa không đổi.
- Commit `f02df17` trên `bao`, đã push. Snapshot `w6-ospf` (27 s).
- Quyết định: giữ `enforce-startup-config: true` (configs/ là nguồn sự thật; sửa bằng vtysh phải `save.sh` ngay).
- 16/11: đổi tên abc → congty, abc.lab → congty.lab cho dễ hiểu (topology `clab/so-do-mang-congty.clab.yml`, `tests/kiem-tra-nhanh.sh`, `tests/kiem-thu-tuan6.sh`, image `congty/web:1.0`, `congty/dns:1.0`).
