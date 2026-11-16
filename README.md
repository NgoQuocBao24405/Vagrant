# Giả lập và mô phỏng hạ tầng mạng dưới dạng mã

Đồ án chuyên ngành (HUTECH, Mạng máy tính). Toàn bộ phòng lab mạng của "Công ty ABC" được mô tả bằng mã:

- **Vagrant + VirtualBox** dựng VM Ubuntu 24.04 `clab-host` (lớp hạ tầng).
- **Docker Engine** trong VM chạy mọi thiết bị dưới dạng container (lớp thực thi).
- **containerlab** đọc file YAML để nối các container thành topology mạng (lớp mô hình).
- **FRR** chạy OSPF hai vùng và eBGP trên 4 router; **BIND9** và **Nginx** là dịch vụ DNS/Web.

```
Windows (Vagrant, VirtualBox, Git)
 └─ VM clab-host 192.168.56.10 (Ubuntu 24.04, Docker, containerlab)
     └─ lab "abc": r-hq, r-br, r-edge, r-isp (FRR) · pc-hq1, pc-br1, inet-host · srv-web, srv-dns · br-srv
```

## Yêu cầu máy

| Thành phần | Phiên bản |
|---|---|
| Windows 10/11 64-bit, RAM ≥ 8 GB, ổ trống ≥ 40 GB | |
| VirtualBox | 7.2.x (đã thử 7.2.22) |
| Vagrant | 2.4.9 |
| Git | bất kỳ, đặt `core.autocrlf input` |

Kiểm tra nhanh: `powershell -ExecutionPolicy Bypass -File .\scripts\host-check.ps1`

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
./scripts/deploy.sh && ./tests/smoke.sh
```

Máy yếu: `$env:LAB_CPUS=2; $env:LAB_MEM=4096; vagrant up`

## Thao tác hằng ngày

| Việc | Lệnh (trong VM, thư mục /vagrant) |
|---|---|
| Dựng lab | `./scripts/deploy.sh` |
| Kiểm tra lab | `./tests/smoke.sh` |
| Vào router (CLI FRR) | `docker exec -it clab-abc-r-hq vtysh` |
| Vào máy client | `docker exec -it clab-abc-pc-br1 bash` |
| Lưu cấu hình đã sửa trên router | `./scripts/save.sh` rồi commit trên Windows |
| Sửa file trong `configs/` rồi áp dụng | `./scripts/destroy.sh && ./scripts/deploy.sh` |
| Gỡ lab | `./scripts/destroy.sh` |
| Tắt VM (trên Windows) | `vagrant halt` |

## Cấu trúc repo

```
Vagrantfile              VM clab-host
scripts/                 host-check.ps1, box-archive.ps1 (Windows) · provision.sh, deploy.sh, save.sh, destroy.sh (VM)
boxes/metadata.json      catalog box cục bộ (file .box để ngoài Git)
docker/                  Dockerfile web/dns + compose.yaml chạy thử
configs/                 cấu hình router FRR và DNS – nguồn sự thật
clab/abc.clab.yml        topology lab
tests/smoke.sh           13 phép kiểm tra PASS/FAIL
docs/                    hướng dẫn từng bước, IP plan, nhật ký tuần, bằng chứng
```

Nhánh: `bao` (làm việc) → `dev` (gộp, chạy thử) → `main` (ổn định). Chi tiết ở Bước 4 của hướng dẫn.

Hướng dẫn chi tiết tuần 1–5: [docs/HuongDan_Tuan1-5.md](docs/HuongDan_Tuan1-5.md) · Bảng IP: [docs/ip-plan.md](docs/ip-plan.md)
