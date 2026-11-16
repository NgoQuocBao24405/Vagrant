# Hướng dẫn tuần 6 (16/11 – 22/11/2026): topology "abc" thành mã, OSPF hai vùng hội tụ

Tuần này biến mô hình mạng "Công ty ABC" thành mã chạy được và chứng minh bằng 6 test case: **TC10, TC11, TC12, TC13, TC18, TC19**. Mọi lệnh `[VM]` chạy trong máy ảo (`vagrant ssh`, tự vào `/vagrant`); lệnh `[Windows]` chạy trong PowerShell hoặc Git Bash tại `D:\Vagrant`.

Kết quả chạy thật nằm ở `docs/evidence/W6_*.log`, tổng hợp ở `docs/evidence/W6_summary.log`.

---

## 0. Chuẩn bị (5 phút)

```powershell
# [Windows] – chỉ chạy MỘT dự án Vagrant: D:\DoAnChuyenNganh có VM trùng tên/IP
cd D:\Vagrant
git switch bao
vagrant status                 # running? nếu "poweroff" thì:
vagrant up                     # ~1 phút khi VM đã tạo sẵn
vagrant ssh
```

**GUI:** mở VirtualBox Manager, thấy `clab-host` ở trạng thái *Running*. Biểu tượng rùa xanh ở góc cửa sổ VM nghĩa là đang chạy chế độ NEM (Memory integrity bật) – lab vẫn chạy, chỉ chậm hơn.

---

## Bước 1: IP plan trước, YAML sau

**Vì sao:** `docs/ip-plan.md` là *nguồn sự thật duy nhất*. Mọi `frr.conf`, lệnh `exec` của host và zone DNS đều suy ra từ bảng này. Sai một địa chỉ ở đây thì OSPF không lên neighbor.

**Làm:** mở `docs/ip-plan.md` cạnh `03_MoHinh_LabMangVagrantDockerClab_v1.0.drawio` (draw.io Desktop). Soát từng liên kết L01–L10: tên interface hai đầu, mạng /30, area.

Tự đọc to một dòng để chắc mình hiểu, ví dụ:
> "L02: r-hq eth2 10.0.0.5/30 nối r-br eth1 10.0.0.6/30, area 1, đường chính."

---

## Bước 2: `clab/abc.clab.yml` và kiểm tra cú pháp (TC10, TC11)

Tệp đã có trong repo. Ba điểm cần hiểu:

| Khóa | Ý nghĩa |
|---|---|
| `groups.routers` | 4 router kế thừa `kind: frr` và image `quay.io/frrouting/frr:containerlab-10.7.1` |
| `enforce-startup-config: true` | **mỗi lần deploy** nạp lại `configs/<router>/frr.conf` → kho Git là nguồn sự thật |
| `br-srv: kind: bridge` | switch LAN máy chủ, là Linux bridge **phải có sẵn** trên VM (deploy.sh tạo) |

**Cơ chế `enforce-startup-config`:** lần deploy đầu, containerlab chép `startup-config` vào `~/clab-runtime/clab-abc/<node>/config/frr.conf` rồi bind-mount vào `/etc/frr`. Không có khóa này thì các lần sau *tệp trong thư mục lab thắng*, sửa `configs/` không có tác dụng. Đánh đổi: sửa bằng `vtysh` thì **phải chạy `./scripts/save.sh` ngay**, nếu không lần deploy sau sẽ ghi đè.

```bash
# [VM]
containerlab validate -t clab/abc.clab.yml          # TC10: không lỗi
```
TC11 – chứng minh containerlab 0.81+ từ chối khóa `extras` đã bị bỏ:
```bash
# [VM]
sed '/^    r-hq:$/a\      extras: {}' clab/abc.clab.yml > /tmp/abc-legacy.clab.yml
containerlab validate -t /tmp/abc-legacy.clab.yml   # TC11: PHẢI báo lỗi
```

**GUI:** mở `clab/abc.clab.yml` trong VS Code (Remote-SSH tới VM). Extension Containerlab tô lỗi YAML ngay khi gõ sai khóa.

---

## Bước 3: ba script vận hành

| Script | Làm gì | Lưu ý |
|---|---|---|
| `scripts/deploy.sh` | tạo `br-srv` nếu thiếu, mở chain `DOCKER-USER` cho br-srv, `containerlab deploy`, đo thời gian, **chờ OSPF hội tụ tối đa 120 s** | thư mục lab ở `~/clab-runtime` (ext4), không nằm trên `/vagrant` |
| `scripts/save.sh` | `write memory` + chép `show running-config` của 4 router về `configs/` | sau đó commit trên Windows |
| `scripts/destroy.sh` | gỡ lab, **giữ** thư mục lab | `--force-clean` + gõ `yes` mới xóa sạch |

```bash
# [VM]
./scripts/deploy.sh                 # TC12
containerlab inspect -t clab/abc.clab.yml   # 9 container running, IP quản lý .11–.14, .21, .22, .31, .32, .41
bridge link | grep br-srv           # 3 cổng: p1-rhq, p2-web, p3-dns
```

**Vì sao cần dòng `DOCKER-USER`:** Docker đặt chính sách FORWARD = DROP và bật `br_netfilter`, nên gói đi qua Linux bridge `br-srv` cũng bị iptables lọc. Chain `DOCKER-USER` là chỗ dành cho luật của người dùng – deploy.sh chèn luật cho phép lưu lượng trong br-srv.

**Lỗi hay gặp:**
- `bridge br-srv not found` → chạy lại `deploy.sh` (bridge mất sau khi khởi động lại VM).
- Thư mục `clab-abc` xuất hiện trong `/vagrant/clab/` → chạy bằng `sudo` làm mất `CLAB_LABDIR_BASE`; chạy không sudo (user `vagrant` thuộc nhóm `clab_admins`).
- `$'\r': command not found` → CRLF; kiểm bằng `file scripts/*.sh`.

---

## Bước 4: OSPF hai vùng (TC13)

**Cơ chế (cần nói lại được trước hội đồng):**
- Router gửi **Hello** (IP protocol 89, 224.0.0.5, 10 s; dead 40 s) → Init → 2-Way → ExStart → Exchange → Loading → **Full**.
- Liên kết `point-to-point` không bầu DR/BDR → trạng thái `Full/-`.
- **Area 0** (r-hq, r-edge, LAN HQ) là backbone; **area 1** (r-br, L02, L03, LAN chi nhánh). r-hq và r-edge là **ABR**, tóm tắt route liên vùng thành LSA type 3 → r-br thấy `IA`.
- r-edge là **ASBR**: `default-information originate` đưa default route vào OSPF → r-br thấy `E2`.
- Interface LAN dùng `ip ospf passive` (dạng cấp interface – chỉnh sửa #5) để không gửi Hello ra mạng người dùng.

```bash
# [VM]
docker exec clab-abc-r-hq  vtysh -c "show ip ospf neighbor"     # 2 dòng Full/-
docker exec clab-abc-r-br  vtysh -c "show ip ospf route"        # 192.168.10.0/24, .20.0/24 là IA
docker exec clab-abc-r-br  vtysh -c "show ip route ospf"
docker exec clab-abc-r-hq  vtysh -c "show ip ospf border-routers"
docker exec clab-abc-r-br  vtysh -c "show ip ospf neighbor json" # khóa JSON cho test tuần 7
```
Hoặc vào thẳng CLI router: `ssh admin@clab-abc-r-hq` (mật khẩu `admin`, vào thẳng vtysh).

**Lỗi hay gặp:**

| Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|
| Kẹt ExStart/Exchange | lệch MTU | `ip ospf mtu-ignore` hoặc đồng bộ MTU |
| Không có neighbor | sai area/subnet hai đầu; quên `point-to-point` một đầu | đối chiếu ip-plan; `show ip ospf interface` |
| Sửa `configs/` không tác dụng | lab dir thắng | đã có `enforce-startup-config`; hoặc `deploy.sh --reconfigure` |
| Máy chạy NEM (rùa xanh) hội tụ chậm | CPU ảo hóa qua Hyper-V | chờ tới 60 s; deploy.sh đã chờ 120 s |

---

## Bước 5: truy cập node bằng ssh / exec / graph (TC18)

```bash
# [VM]
ssh admin@clab-abc-r-hq                                   # CLI router
containerlab exec -t clab/abc.clab.yml --label clab-node-name=pc-br1 --cmd "ip -br addr show eth1"
docker exec -it clab-abc-pc-br1 bash                      # shell máy trạm
containerlab graph -t clab/abc.clab.yml                   # web sơ đồ tại :50080
```
**GUI:** trong lúc lệnh `graph` chạy, mở trình duyệt Windows `http://192.168.56.10:50080` → thấy sơ đồ 10 node. Trong VS Code, **Ctrl+Alt+G** mở TopoViewer; chuột phải r-hq → *SSH*. Chụp màn hình cả hai cho báo cáo.

---

## Bước 6: "cấu hình là mã" (TC19)

```text
r-hq# conf t
r-hq(config)# interface eth3
r-hq(config-if)# description TEST-TC19
r-hq(config-if)# end
r-hq# write memory
```
```bash
# [VM]
./scripts/save.sh && ./scripts/destroy.sh && ./scripts/deploy.sh
docker exec clab-abc-r-hq vtysh -c "show running-config" | grep TEST-TC19   # vẫn còn
```
**GUI:** GitHub Desktop (hoặc VS Code tab Source Control) hiện diff của `configs/r-hq/frr.conf` → chụp màn hình → commit `feat(r-hq): TC19 description test`.

Cuối buổi: `vagrant snapshot save w6-ospf` (trên Windows).

---

## Chạy tất cả một lần

```bash
# [VM]
bash tests/w6_check.sh        # in PASS/FAIL từng TC, ghi docs/evidence/W6_*.log, exit = số TC FAIL
./tests/smoke.sh              # 13 kiểm tra nhanh (OSPF, BGP, ping, DNS, HTTP)
```

## Đẩy lên GitHub (luồng bao → dev → main)

```bash
# [Windows – Git Bash] trong D:\Vagrant
git add tests/w6_check.sh docs/ configs/r-hq/frr.conf
git commit -m "test(w6): TC10-TC13, TC18, TC19 - topology abc, OSPF hai vung"
git push origin bao           # rồi mở Pull Request bao → dev trên GitHub
```

## Trình GVHD tuần này
TopoViewer hoặc ảnh `:50080`; `show ip ospf neighbor` trên 3 router; diff Git của TC19; `W6_summary.log`.
