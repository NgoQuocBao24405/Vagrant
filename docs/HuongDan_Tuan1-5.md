# Hướng dẫn thực hiện tuần 1–5

Tài liệu này dẫn từng bước từ máy Windows trống tới lúc lab "abc" chạy được và kiểm tra PASS. Mỗi bước có ba phần: **làm gì** (GUI hoặc lệnh), **vì sao** (cơ chế), và **kết quả mong đợi**. Ký hiệu nơi chạy lệnh:

- `[Windows]` – PowerShell trên Windows, đứng trong `D:\Vagrant`
- `[Windows Admin]` – PowerShell mở bằng *Run as administrator*
- `[VM]` – bên trong VM sau khi `vagrant ssh`

Tình trạng máy ngày 08/11/2026: Vagrant 2.4.9 và VirtualBox 7.2.22 đã cài, box `bento/ubuntu-24.04 202510.26.0` đã có trong cache, **hypervisor của Windows đang bật** (`HyperVisorPresent: True`, Memory integrity đang chạy). Vì vậy thứ tự làm là: Bước 1 → 2 → 3 → 4 → 5…

---

## Bước 1 – Kiểm tra máy bằng script (TC01/TC02)

```powershell
# [Windows Admin]
cd D:\Vagrant
powershell -ExecutionPolicy Bypass -File .\scripts\host-check.ps1
```

**Vì sao.** Script gom các kiểm tra rời rạc (RAM, ổ đĩa, hypervisor, VirtualBox, Vagrant, box, Git) thành một danh sách PASS/FAIL/WARN để lần nào cũng kiểm tra giống nhau.

**Kết quả mong đợi lúc này.** `HypervisorPresent = False` và `VBS` ở trạng thái **WARN**. Hãy **chụp màn hình lần chạy này trước khi sửa ở Bước 3**: đây là bằng chứng "phát hiện được hypervisor" (TC02). Lưu vào `docs/evidence/TC02_host-check_truoc.png`.

> `VBoxManage not recognized` khi gõ trực tiếp là bình thường: VirtualBox không tự thêm thư mục cài đặt vào PATH. Script tự tìm ở `C:\Program Files\Oracle\VirtualBox\`.

---

## Bước 2 – Lưu trữ box (việc gấp, làm trước mọi việc khác)

**Vì sao.** HCP Vagrant (kho box mặc định) đã hết hỗ trợ từ 02/11/2026 và dự kiến gỡ toàn bộ vào 31/12/2026. Box của bạn hiện chỉ nằm trong cache `%USERPROFILE%\.vagrant.d\boxes`. Nếu cache bị xóa sau 31/12, lệnh `vagrant up` sẽ không tải lại được. Script dưới đây xuất cache thành một file `.box`, tính SHA256 và tạo *catalog* `metadata.json` để Vagrant cài lại box từ ổ đĩa của bạn.

```powershell
# [Windows]
powershell -ExecutionPolicy Bypass -File .\scripts\box-archive.ps1
```

**Kết quả mong đợi.** Thư mục `D:\vagrant-boxes\` có 3 file: `bento-ubuntu-24.04-202510.26.0-virtualbox-amd64.box` (khoảng 1 GB trở lên), `SHA256SUMS.txt`, `metadata.json`. File `boxes\metadata.json` trong repo được cập nhật với SHA256 thật (commit file này, **không** commit file `.box`).

**GUI.** Dùng File Explorer chép cả thư mục `D:\vagrant-boxes\` sang **hai nơi**: ổ cứng ngoài/USB và Google Drive.

**Thử đường cài lại offline (TC06).** Làm khi đã có bản sao an toàn:

```powershell
# [Windows]
vagrant box list -i
vagrant box remove bento/ubuntu-24.04 --box-version 202510.26.0
vagrant box add D:\vagrant-boxes\metadata.json
vagrant box list -i          # box xuất hiện lại = catalog cục bộ hoạt động
```

Nếu `vagrant box add D:\...` báo lỗi, thử dạng URL: `vagrant box add file:///D:/vagrant-boxes/metadata.json`. Ghi lại dạng nào chạy vào `docs/weekly-log.md`. Lưu toàn bộ output thành `docs/evidence/TC06_box_archive.log`.

---

## Bước 3 – Tắt hypervisor của Windows ("rùa xanh")

**Docker có bị ảnh hưởng không?** Không. Trong đồ án này Docker là thành phần **không thể thiếu**, vì mọi router, máy trạm và máy chủ của lab đều là container. Nhưng Docker chạy **bên trong VM Ubuntu** do Vagrant dựng, không chạy trên Windows. Tắt hypervisor chỉ làm ngừng Docker Desktop và WSL2 **trên Windows**, hai thứ dự án không dùng.

**Vì sao phải tắt.** Khi Hyper-V, VBS hoặc Memory integrity bật, chính Windows chạy trên hypervisor của Microsoft và hypervisor này giữ VT-x của CPU. VirtualBox phải đi đường vòng qua Windows Hypervisor Platform (chế độ NEM), VM chạy chậm hẳn và có biểu tượng con rùa xanh ở góc cửa sổ VM.

**Trước khi làm: lưu khóa BitLocker.** Vào https://aka.ms/myrecoverykey hoặc chạy `manage-bde -protectors -get C:` trong PowerShell Admin, chụp lại khóa. Tắt Core isolation có thể làm máy hỏi khóa BitLocker ở lần khởi động sau.

1. **[GUI] Windows Security → Device security → Core isolation details.** Tắt **Memory integrity**. Nếu có, tắt thêm **Kernel-mode Hardware-enforced Stack Protection** và **Firmware protection**.
2. **[GUI] Gõ `optionalfeatures` vào Start.** Bỏ tick: *Hyper-V*, *Virtual Machine Platform*, *Windows Hypervisor Platform*, *Windows Sandbox*, *Windows Subsystem for Linux*. Bấm OK, **chưa** khởi động lại.
3. **[Windows Admin]**
   ```powershell
   bcdedit /set hypervisorlaunchtype off
   bcdedit /enum "{current}" | findstr hypervisorlaunchtype     # mong đợi: Off
   ```
   Muốn bật lại sau đồ án: `bcdedit /set hypervisorlaunchtype auto`.
4. Khởi động lại máy.
5. **Kiểm tra:** chạy lại `host-check.ps1`. `HypervisorPresent = False` phải là **PASS**. Mở `msinfo32`, dòng *Virtualization-based security* ở cuối trang System Summary phải là *Not enabled*. Chụp màn hình → `docs/evidence/TC01_host-check_sau.png`.

**Nếu vẫn `True`** (đã có báo cáo trên Windows 11 25H2): không sao, vẫn làm tiếp được. Vagrantfile đã đặt `boot_timeout = 600` cho chế độ chậm. Nếu VM quá chậm, chạy hồ sơ nhỏ `$env:LAB_CPUS=2; $env:LAB_MEM=4096`. Ghi vào `docs/weekly-log.md`: "HypervisorPresent vẫn True, chấp nhận chế độ NEM" – đây là rủi ro đã ghi nhận, nên ghi kèm thời gian `vagrant up` đo được.

---

## Bước 4 – Repo Git và quy tắc xuống dòng (LF)

**Vì sao.** Windows kết thúc dòng bằng CRLF, Linux bằng LF. Bash gặp `\r` sẽ báo `$'\r': command not found`, FRR có thể đọc tên interface thành `eth1\r`. File `.gitattributes` trong repo buộc Git checkout các file `.sh`, `.conf`, `.yml` bằng LF, còn `.ps1` bằng CRLF.

```powershell
# [Windows]
git config --global core.autocrlf input
cd D:\Vagrant
git pull                         # lấy toàn bộ file của đồ án
git add --renormalize .          # áp quy tắc LF cho file đã có (nếu Git báo thay đổi thì commit)
git ls-files --eol | Select-String "scripts/"    # cột "i/lf" cho mọi file .sh
```

**GUI.** Mở `D:\Vagrant` bằng VS Code. Ở thanh trạng thái góc phải dưới có chữ **LF** hoặc **CRLF**: mở `scripts/provision.sh` phải thấy **LF**. File `.vscode/settings.json` đã đặt VS Code luôn lưu bằng LF.

**Ba nhánh của repo.**

| Nhánh | Vai trò | Ai ghi vào |
|---|---|---|
| `bao` | nhánh làm việc hằng ngày: sửa, commit, push | bạn push trực tiếp |
| `dev` | nhánh gộp và chạy thử: lab phải `deploy` + `smoke.sh` PASS ở đây | chỉ nhận merge từ `bao` qua Pull Request |
| `main` | bản ổn định để nộp/trình GVHD, gắn tag phiên bản | chỉ nhận merge từ `dev` qua Pull Request |

Vòng làm việc:
```bash
git checkout bao                 # luôn làm trên bao
git pull                         # lấy bản mới nhất
# ... sửa file, chạy thử trong VM ...
git add -A && git commit -m "feat(lab): mo ta ngan"
git push
```
Trên GitHub: *Pull requests → New → base: `dev` ← compare: `bao`* → Merge. Trong VM chuyển sang `dev` (`git checkout dev && git pull` trên Windows), chạy `./scripts/deploy.sh && ./tests/smoke.sh`. Tất cả PASS thì mở PR *base: `main` ← compare: `dev`* → Merge, rồi gắn tag (vd `v0.1-vm`) trên `main`. Sau mỗi lần merge, đồng bộ lại `bao`: `git checkout bao && git merge origin/main && git push`.

Bảo vệ nhánh (khuyến nghị): *Settings → Branches → Add branch ruleset* cho `main` và `dev`, bật *Require a pull request before merging*, để không lỡ tay push thẳng vào hai nhánh này.

**Quy ước commit.** `feat(...)`, `fix(...)`, `docs:`, `test:`, `chore:`. Chỉ dùng Git ở phía Windows (VS Code, GitHub Desktop hoặc Git Bash). Thư mục `/vagrant` trong VM là cùng một thư mục nên không cần commit từ VM.

---

## Bước 5 – Dựng VM bằng Vagrant

**Vagrantfile làm gì** (đọc file `Vagrantfile` song song):

| Dòng | Ý nghĩa |
|---|---|
| `config.vm.box`, `box_version` | dùng đúng box `bento/ubuntu-24.04` bản `202510.26.0` (ghim để dựng lại y hệt) |
| `box_url` từ `LAB_BOX_URL` | khi cache mất, trỏ tới `D:\vagrant-boxes\metadata.json` |
| `box_check_update = false` | không hỏi HCP Vagrant mỗi lần `up` |
| `private_network 192.168.56.10` | NIC2 host-only: Windows (192.168.56.1) nói chuyện trực tiếp với VM. NIC1 luôn là NAT để VM ra Internet; SSH đi qua 127.0.0.1:2222 |
| `synced_folder ".", "/vagrant"` | thư mục `D:\Vagrant` hiện ra trong VM tại `/vagrant` (sửa ở Windows, thấy ngay trong VM) |
| `vb.cpus/memory` | 4 vCPU / 6 GB mặc định, đổi bằng `LAB_CPUS`/`LAB_MEM` |
| `provision "setup"` | chạy `scripts/provision.sh` ở lần `up` đầu tiên |
| `provision "br-srv"` (`run: always`) | mỗi lần `up` tạo lại bridge `br-srv` và luật cho phép gói qua bridge |

```powershell
# [Windows]
vagrant validate                                          # Vagrantfile validated successfully.
Measure-Command { vagrant up | Out-Host } | Select-Object TotalSeconds   # GHI LẠI số giây (NFR01)
vagrant status                                            # clab-host  running (virtualbox)
ping 192.168.56.10
```

Lần `up` đầu mất 10–20 phút vì `provision.sh` cài Docker, containerlab và build image. Cuối output có khối **KET QUA** in phiên bản Docker, Compose, containerlab và danh sách image.

**GUI: VirtualBox Manager** (để hiểu Vagrant đã tạo gì):
1. VM `clab-host` ở trạng thái *Running*.
2. *Settings → Network*: Adapter 1 = NAT, Adapter 2 = Host-only Adapter.
3. *File → Tools → Network Manager → Host-only Networks*: có adapter 192.168.56.1/24.
4. Bấm *Show* để xem màn hình VM: **không có rùa xanh** ở thanh trạng thái (nếu Bước 3 thành công).

**Kết nối VS Code vào VM (Remote-SSH)**, dùng từ đây về sau:

```powershell
# [Windows]
New-Item -ItemType Directory -Force $HOME\.ssh | Out-Null
vagrant ssh-config --host clab-host | Out-File -Encoding ascii -Append $HOME\.ssh\config
ssh clab-host            # thử bằng terminal trước, gõ exit để thoát
```

Phải có `-Encoding ascii`: PowerShell 5 mặc định ghi UTF-16, OpenSSH không đọc được. Trong VS Code: cài extension **Remote - SSH** → F1 → *Remote-SSH: Connect to Host…* → `clab-host` → *Linux* → *Open Folder* `/vagrant`.

---

## Bước 6 – Kiểm tra Docker trong VM (TC07)

`provision.sh` đã cài Docker Engine **29.9.2** và Compose **5.6.1** từ repo chính thức của Docker, rồi `apt-mark hold` để `apt upgrade` không tự nâng cấp.

**Cơ chế cần nắm.** Docker Engine có ba lớp: `dockerd` nhận lệnh qua socket `/var/run/docker.sock`; `containerd` quản lý vòng đời container và image; `runc` tạo container bằng *namespace* (mạng, tiến trình, mount…) và *cgroup* của nhân Linux. User `vagrant` được thêm vào nhóm `docker` nên không cần `sudo`, nhưng nhóm chỉ có hiệu lực từ lần đăng nhập sau.

```powershell
# [Windows]
vagrant ssh
```
```bash
# [VM]
docker run --rm hello-world
docker version --format '{{.Client.Version}} / {{.Server.Version}}'    # 29.9.2 / 29.9.2
docker compose version                                                # v5.6.1
systemctl is-enabled docker                                           # enabled
apt-mark showhold                                                     # docker-ce docker-ce-cli docker-compose-plugin
docker info | grep -Ei 'storage driver|cgroup'
```
Lưu output thành `docs/evidence/TC07_docker_ok.log`. Lỗi `permission denied … docker.sock` nghĩa là chưa đăng nhập lại: `exit` rồi `vagrant ssh` lại.

**Thử tính idempotent (TC04).** `vagrant provision` lần 2 phải in các dòng "da co" và gần như không cài gì thêm.

**Chốt tuần 4.**
```powershell
# [Windows]
vagrant halt
vagrant snapshot save base-docker      # điểm khôi phục; quay lại bằng: vagrant snapshot restore base-docker
vagrant up
```
Merge `bao` → `dev` → `main` như Bước 4, rồi trên GitHub web: *Releases → Draft a new release → tag `v0.1-vm`*, chọn target `main`.

---

## Bước 7 – Image dịch vụ và Docker Compose (tuần 5, TC08)

**Cơ chế layer.** Mỗi lệnh trong Dockerfile tạo một *layer* chỉ đọc; image là chồng các layer; container là image cộng một layer ghi được. Docker cache layer theo nội dung, nên lệnh ít đổi (`apk add`) đặt trước, file hay sửa (`COPY index.html`) đặt sau. Image DNS chạy `named-checkconf` và `named-checkzone` lúc build: cấu hình sai thì build thất bại ngay.

```bash
# [VM] (đang ở /vagrant)
docker build -t abc/web:1.0 docker/web
docker build -t abc/dns:1.0 -f docker/dns/Dockerfile .
docker history abc/web:1.0                       # mỗi dòng là một layer
docker compose -f docker/compose.yaml up -d
docker compose -f docker/compose.yaml ps         # chờ cả hai STATUS (healthy)
curl -I http://127.0.0.1:8080                    # HTTP/1.1 200 OK
dig @127.0.0.1 -p 5353 web.abc.lab +short        # 192.168.20.10
docker run --rm abc/dns:1.0 named -v             # ghi lại phiên bản BIND
```

**GUI – bằng chứng bảo mật (TC08).** Trên Windows mở trình duyệt vào `http://192.168.56.10:8080`: phải **không truy cập được**, vì `compose.yaml` chỉ mở cổng trên `127.0.0.1` của VM. Chụp màn hình. Sau đó trong VS Code (đang Remote-SSH) mở tab **Ports** → *Forward a Port* → `8080`, rồi mở `http://localhost:8080` trên Windows: trang ABC hiện ra qua đường hầm SSH. Cặp ảnh này cho thấy cổng không mở ra mạng nhưng vẫn quản trị được qua kênh SSH.

---

## Bước 8 – Nhìn tận mắt mạng Docker (TC09)

**Cơ chế.** Mỗi container có network namespace riêng. Docker tạo một **cặp veth**: một đầu thành `eth0` trong container, đầu kia (`vethXXXX`) nằm ở VM và cắm vào bridge của network. Luật NAT trong iptables cho container ra Internet. containerlab dùng đúng các khối này, chỉ khác là liên kết giữa hai router là veth nối **thẳng** hai container, không qua bridge.

```bash
# [VM] khi stack Compose đang chạy
docker network ls
docker network inspect abc-svc_svc-test | less          # subnet, gateway, các container
ip -br link show type veth
bridge link
PID=$(docker inspect -f '{{.State.Pid}}' abc-svc-dns-1); sudo nsenter -t $PID -n ip -br addr
sudo iptables -t nat -S | grep -i docker
docker compose -f docker/compose.yaml down
ip -br link show type veth                              # các veth đã biến mất
```
Tên container chính xác xem bằng `docker compose -f docker/compose.yaml ps`. Lưu toàn bộ output thành `docs/evidence/TC09_docker_network.log`.

---

## Bước 9 – containerlab và lab mẫu frr01

`provision.sh` đã cài containerlab **0.82.0** từ gói `.deb` chính thức và thêm `vagrant` vào nhóm `clab_admins` (chạy containerlab không cần `sudo`).

```bash
# [VM]
containerlab version                   # version: 0.82.0
ls -l "$(which containerlab)"          # -rwsr-xr-x (bit SUID)
id | tr ',' '\n' | grep -E 'docker|clab_admins'
cp -r /etc/containerlab/lab-examples/frr01 ~/frr01 && cd ~/frr01
containerlab deploy -t frr01.clab.yml
containerlab inspect -t frr01.clab.yml
docker exec clab-frr01-router1 vtysh -c "show ip ospf neighbor"    # 2 neighbor Full
containerlab destroy -t frr01.clab.yml --cleanup
cd /vagrant
```

**GUI – VS Code extension Containerlab.** Trong cửa sổ Remote-SSH, cài extension `srl-labs.vscode-containerlab` (phía remote). Chuột phải file `.clab.yml` → *Deploy*; Ctrl+Alt+G mở TopoViewer để xem sơ đồ; chuột phải một router → mở shell. GUI và CLI làm cùng một việc.

---

## Bước 10 – Chạy lab "abc"

**Topology** (`clab/abc.clab.yml`): 4 router FRR (r-hq, r-br, r-edge, r-isp), 3 máy netshoot (pc-hq1, pc-br1, inet-host), 2 máy chủ (srv-web, srv-dns) nối qua bridge `br-srv`. OSPF area 0 ở HQ, area 1 ở Branch; r-edge chạy eBGP AS65001 với r-isp AS65000. Bảng IP: [ip-plan.md](ip-plan.md).

```bash
# [VM]
./scripts/deploy.sh        # tạo br-srv, dựng lab, chờ OSPF hội tụ; in deploy_s=…
containerlab inspect -t clab/abc.clab.yml
./tests/smoke.sh           # 13 mục, mong đợi "TAT CA PASS"
```

**Lệnh xem trạng thái định tuyến:**
```bash
docker exec clab-abc-r-hq  vtysh -c "show ip ospf neighbor"      # Full/- với r-edge và r-br
docker exec clab-abc-r-br  vtysh -c "show ip route"              # O tới LAN HQ, O E2 default
docker exec clab-abc-r-edge vtysh -c "show bgp summary"          # 203.0.113.1 có số prefix (không phải "(Policy)")
docker exec clab-abc-r-isp vtysh -c "show bgp ipv4 unicast"      # 3 prefix 192.168.x.0/24 từ AS65001
docker exec clab-abc-pc-br1 traceroute -n 198.51.100.10          # 192.168.30.1 → 10.0.0.10 → 203.0.113.1 → 198.51.100.10
docker exec clab-abc-pc-br1 curl -s http://web.abc.lab           # trang ABC
```

**Sửa cấu hình – hai cách, chọn một:**

1. *Sửa file* (khuyến nghị): sửa `configs/r-hq/frr.conf` trong VS Code → `./scripts/destroy.sh && ./scripts/deploy.sh`. Topology đặt `enforce-startup-config: true` nên mỗi lần deploy đều nạp lại đúng file trong `configs/`.
2. *Sửa trên router*: `docker exec -it clab-abc-r-hq vtysh` → `conf t` → … → `end` → thoát, rồi **chạy ngay** `./scripts/save.sh` để chép cấu hình đang chạy về `configs/`. Không save thì lần deploy sau sẽ ghi đè mất thay đổi.

Sau đó commit thay đổi trong `configs/` từ Windows. Ví dụ kiểm chứng "cấu hình là mã" (TC19): thêm `description TEST-TC19` vào `interface eth3` của r-hq bằng vtysh → `./scripts/save.sh` → `./scripts/destroy.sh && ./scripts/deploy.sh` → `docker exec clab-abc-r-hq vtysh -c "show run" | grep TEST-TC19` vẫn thấy.

**Kết thúc buổi:** `./scripts/destroy.sh`, rồi trên Windows `vagrant halt`.

---

## Xử lý lỗi thường gặp

| Triệu chứng | Nguyên nhân hay gặp | Cách xử lý |
|---|---|---|
| `vagrant up` treo ở "SSH auth method: private key" | VM boot chậm (chế độ NEM) hoặc VT-x tắt trong BIOS | Mở VirtualBox Manager xem màn hình VM; làm lại Bước 3; chờ tới 10 phút |
| `VERR_NEM_VM_CREATE_FAILED` | Xung đột Hyper-V | Bước 3 |
| "Failed to create the host-only adapter" | Thiếu thành phần Networking của VirtualBox | Cài lại VirtualBox bằng quyền Admin, giữ thành phần Networking |
| Tên VM `clab-host` đã tồn tại | VM cũ chưa xóa | VirtualBox Manager → chuột phải VM → *Remove → Delete all files* |
| `apt-get update` trong VM lỗi "Temporary failure in name resolution" | DNS NAT khi dùng VPN/mạng trường | Bỏ dấu `#` dòng `--natdnshostresolver1` trong Vagrantfile, `vagrant reload --provision` |
| `$'\r': command not found` | File bị CRLF | Bước 4 (`core.autocrlf input`, `git add --renormalize .`), kiểm bằng `file scripts/*.sh` trong VM |
| `permission denied … docker.sock` | Chưa đăng nhập lại sau khi vào nhóm docker | `exit` rồi `vagrant ssh` |
| `docker pull` báo `toomanyrequests` | Giới hạn Docker Hub | `docker login` (image FRR lấy từ quay.io không bị giới hạn này) |
| Deploy báo "bridge br-srv not found" | VM vừa khởi động lại | `./scripts/deploy.sh` tự tạo; hoặc `vagrant reload` |
| Ping tới srv-web/srv-dns mất 100% | Docker chặn FORWARD qua bridge | `deploy.sh` tự thêm luật; kiểm `sudo iptables -S DOCKER-USER` phải có dòng `-i br-srv -o br-srv -j ACCEPT` |
| OSPF neighbor kẹt ExStart/Exchange | Lệch MTU | Thêm `ip ospf mtu-ignore` vào interface hai đầu |
| `show bgp summary` hiện `(Policy)` | Thiếu route-map vào/ra (FRR bắt buộc chính sách cho eBGP) | Kiểm tra `route-map … in/out` trong `configs/r-edge` và `configs/r-isp` |

## Bằng chứng cần lưu vào `docs/evidence/`

| Mã | Nội dung |
|---|---|
| TC01/TC02 | ảnh host-check trước và sau khi tắt hypervisor |
| TC06 | log lưu trữ box và cài lại từ catalog cục bộ |
| TC07 | log kiểm tra Docker |
| TC08 | ảnh trình duyệt bị từ chối + ảnh forward cổng qua VS Code |
| TC09 | log khảo sát mạng Docker |
| frr01 | ảnh TopoViewer + output `show ip ospf neighbor` |
| abc | output `./tests/smoke.sh` |
