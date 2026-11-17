# Giả lập và mô phỏng hạ tầng mạng dưới dạng mã

Đồ án chuyên ngành (HUTECH, Mạng máy tính). Toàn bộ phòng lab mạng của "Công ty ABC" được mô tả bằng mã:

- **Vagrant + VirtualBox** dựng VM Ubuntu 24.04 `may-ao-lab` (lớp hạ tầng).
- **Docker Engine** trong VM chạy mọi thiết bị dưới dạng container (lớp thực thi).
- **containerlab** đọc file YAML để nối các container thành topology mạng (lớp mô hình).
- **FRR** chạy OSPF hai vùng và eBGP trên 4 router; **BIND9** và **Nginx** là dịch vụ DNS/Web.

```
Windows (Vagrant, VirtualBox, Git)
 └─ VM may-ao-lab 192.168.56.10 (Ubuntu 24.04, Docker, containerlab)
     └─ lab "congty": router-tru-so, router-chi-nhanh, router-bien, router-nha-mang (FRR) · may-tinh-tru-so, may-tinh-chi-nhanh, may-ngoai-internet · may-chu-web, may-chu-dns · switch-may-chu
```

## Yêu cầu máy

| Thành phần | Phiên bản |
|---|---|
| Windows 10/11 64-bit, RAM ≥ 8 GB, ổ trống ≥ 40 GB | |
| VirtualBox | 7.2.x (đã thử 7.2.22) |
| Vagrant | 2.4.9 |
| Git | bất kỳ, đặt `core.autocrlf input` |

Kiểm tra nhanh: `powershell -ExecutionPolicy Bypass -File .\scripts\kiem-tra-may-windows.ps1`

## Chạy nhanh (5 lệnh)

```powershell
# Windows PowerShell
git clone -b main https://github.com/NgoQuocBao24405/Vagrant.git D:\Vagrant
cd D:\Vagrant
vagrant up          # lần đầu 10–20 phút: cài Docker, containerlab, build image
vagrant ssh
```
```bash
# Trong VM (tự vào /vagrant)
./scripts/dung-lab.sh && ./tests/kiem-tra-nhanh.sh
```

Máy yếu: `$env:LAB_CPUS=2; $env:LAB_MEM=4096; vagrant up`

## Thao tác hằng ngày

| Việc | Lệnh (trong VM, thư mục /vagrant) |
|---|---|
| Dựng lab | `./scripts/dung-lab.sh` |
| Kiểm tra lab | `./tests/kiem-tra-nhanh.sh` |
| Vào router bằng SSH (không cần mật khẩu) | `ssh router-tru-so` (hoặc router-chi-nhanh, router-bien, router-nha-mang) |
| Vào router (CLI FRR) | `docker exec -it router-tru-so vtysh` |
| Vào máy client | `docker exec -it may-tinh-chi-nhanh bash` |
| Lưu cấu hình đã sửa trên router | `./scripts/luu-cau-hinh.sh` rồi commit trên Windows |
| Sửa file trong `configs/` rồi áp dụng | `./scripts/go-lab.sh && ./scripts/dung-lab.sh` |
| Gỡ lab | `./scripts/go-lab.sh` |
| Tắt VM (trên Windows) | `vagrant halt` |

## Cấu trúc repo

```
Vagrantfile              VM may-ao-lab
scripts/                 kiem-tra-may-windows.ps1, luu-tru-box.ps1 (Windows) · cai-dat-may-ao.sh, dung-lab.sh, luu-cau-hinh.sh, go-lab.sh, cau-hinh-ssh.sh (VM)
boxes/metadata.json      catalog box cục bộ (file .box để ngoài Git)
docker/                  Dockerfile web/dns + compose.yaml chạy thử
configs/                 cấu hình router FRR và DNS – nguồn sự thật
clab/so-do-mang-congty.clab.yml   topology lab
tests/kiem-tra-nhanh.sh  13 phép kiểm tra PASS/FAIL
docs/                    hướng dẫn từng bước, IP plan, nhật ký tuần, bằng chứng
```

## Tên thiết bị và SSH

Tên container = tên node (topology đặt `prefix: ""`), containerlab tự thêm chúng vào `/etc/hosts` của VM.
Router: `router-tru-so`, `router-chi-nhanh`, `router-bien`, `router-nha-mang`. Máy: `may-tinh-tru-so`, `may-tinh-chi-nhanh`, `may-chu-web`, `may-chu-dns`, `may-ngoai-internet`. Switch: `switch-may-chu`.

```bash
ssh router-tru-so                              # vào vtysh của router, không hỏi mật khẩu
ssh router-tru-so "show ip ospf neighbor"      # chạy một lệnh rồi thoát
```

`scripts/cau-hinh-ssh.sh` (gọi từ `cai-dat-may-ao.sh` và `dung-lab.sh`) tạo khóa `~/.ssh/id_ed25519` cho user vagrant và khối `Host router-...` trong `~/.ssh/config` (User admin, bỏ kiểm tra host key). Khi deploy, containerlab chép `~/.ssh/*.pub` vào `/home/admin/.ssh/authorized_keys` của router. Dự phòng: `ssh admin@router-tru-so`, mật khẩu `admin`.

Từ Windows vào VM: `ssh may-ao-lab` (hoặc `vagrant ssh`). Bảng đổi tên cũ → mới: cuối [docs/bang-dia-chi-ip.md](docs/bang-dia-chi-ip.md).

Nhánh: `bao` (làm việc) → `dev` (gộp, chạy thử) → `main` (ổn định). Chi tiết ở Bước 4 của hướng dẫn.

Bảng IP: [docs/bang-dia-chi-ip.md](docs/bang-dia-chi-ip.md)
