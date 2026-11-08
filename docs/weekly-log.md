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
- TC08: Compose web + dns healthy sau ~12 s; `curl -I 127.0.0.1:8080` → 200; `dig … web.abc.lab` → 192.168.20.10; BIND 9.20.30. Từ Windows `http://192.168.56.10:8080` không kết nối được (đúng thiết kế) (`TC08_compose.log`).
- TC09: veth ↔ bridge `br-<id>`, `eth0@if15` trong namespace dns, DNAT chỉ cho `127.0.0.1`; sau `compose down` còn 0 veth (`TC09_docker_network.log`).
- frr01: chờ 40 s thì OSPF còn ExStart (hội tụ chậm ở chế độ NEM); sau 60 s cả 2 neighbor Full, PC1 → PC3 ping OK (`W5_frr01.log`).
- Lab abc: `deploy_s=10`, OSPF hội tụ ~18 s, `smoke.sh` 13/13 PASS (`W5_abc_deploy.log`, `W5_abc_smoke.log`, `W5_abc_routing.log`).
