#!/usr/bin/env bash
# provision.sh – chuẩn bị VM clab-host. Vagrant chạy file này bằng root.
# Idempotent: chạy lại bao nhiêu lần cũng được, bước nào đã xong thì bỏ qua.
#   1) Docker Engine từ repo chính thức, ghim và giữ phiên bản (apt-mark hold)
#   2) containerlab 0.82.0 (gói .deb chính thức, nhóm clab_admins)
#   3) công cụ phụ (jq, dig, tcpdump…)
#   4) kéo image router/host, build image dịch vụ abc/web và abc/dns
set -euo pipefail

DOCKER_WANT="${DOCKER_WANT:-29.9.2}"        # phiên bản Docker Engine mong muốn
COMPOSE_WANT="${COMPOSE_WANT:-5.6.1}"       # phiên bản Docker Compose plugin
CLAB_VER="${CLAB_VER:-0.82.0}"
FRR_IMG="quay.io/frrouting/frr:containerlab-10.7.1"
HOST_IMG="nicolaka/netshoot:v0.16"
REPO=/vagrant
export DEBIAN_FRONTEND=noninteractive

log()  { echo -e "\n==> $*"; }
warn() { echo "!!! CANH BAO: $*" >&2; }

# Tìm chuỗi phiên bản apt đầy đủ (vd 5:29.9.2-1~ubuntu.24.04~noble) cho một gói
apt_ver() { apt-cache madison "$1" | awk -v w="$2" '{ if (index($3, w"-")>0) { print $3; exit } }'; }

# ---------- 1. Docker Engine ----------
if ! command -v docker >/dev/null 2>&1; then
  log "Cai Docker Engine tu download.docker.com"
  apt-get update -q
  apt-get install -y -q ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  cat >/etc/apt/sources.list.d/docker.sources <<SRC
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
SRC
  apt-get update -q
  DV=$(apt_ver docker-ce "$DOCKER_WANT"); CV=$(apt_ver docker-compose-plugin "$COMPOSE_WANT")
  if [ -n "$DV" ]; then PKG_DOCKER=(docker-ce="$DV" docker-ce-cli="$DV")
  else warn "khong thay docker-ce $DOCKER_WANT, cai ban moi nhat"; PKG_DOCKER=(docker-ce docker-ce-cli); fi
  if [ -n "$CV" ]; then PKG_COMPOSE=(docker-compose-plugin="$CV")
  else warn "khong thay compose $COMPOSE_WANT, cai ban moi nhat"; PKG_COMPOSE=(docker-compose-plugin); fi
  apt-get install -y -q "${PKG_DOCKER[@]}" containerd.io docker-buildx-plugin "${PKG_COMPOSE[@]}"
  apt-mark hold docker-ce docker-ce-cli docker-compose-plugin
else
  log "Docker da co: $(docker --version)"
fi
systemctl enable --now docker >/dev/null
usermod -aG docker vagrant

# ---------- 2. containerlab ----------
if ! containerlab version 2>/dev/null | grep -q "version: ${CLAB_VER}"; then
  log "Cai containerlab ${CLAB_VER}"
  deb="/tmp/containerlab_${CLAB_VER}.deb"
  curl -fsSL -o "$deb" \
    "https://github.com/srl-labs/containerlab/releases/download/v${CLAB_VER}/containerlab_${CLAB_VER}_linux_amd64.deb"
  apt-get install -y -q "$deb"
  rm -f "$deb"
else
  log "containerlab ${CLAB_VER} da co"
fi
# Thành viên clab_admins chạy containerlab không cần sudo (tránh sudo xóa biến CLAB_LABDIR_BASE)
getent group clab_admins >/dev/null || groupadd -r clab_admins
usermod -aG clab_admins vagrant

# ---------- 3. Công cụ phụ ----------
log "Cai cong cu phu"
apt-get install -y -q jq bc dnsutils tcpdump tree >/dev/null

# Thư mục runtime của lab nằm trên ext4 của VM, KHÔNG nằm trên /vagrant (vboxsf)
install -d -o vagrant -g vagrant /home/vagrant/clab-runtime

# Mỗi lần "vagrant ssh" tự vào /vagrant và có sẵn biến môi trường cho containerlab
cat >/etc/profile.d/lab.sh <<'PROFILE'
export CLAB_LABDIR_BASE=/home/vagrant/clab-runtime
[ "$USER" = vagrant ] && [ -d /vagrant ] && [ "$PWD" = "$HOME" ] && cd /vagrant
PROFILE

# ---------- 4. Image ----------
log "Keo image router va host"
for img in "$FRR_IMG" "$HOST_IMG"; do
  docker image inspect "$img" >/dev/null 2>&1 || docker pull -q "$img" || warn "khong keo duoc $img (thu lai: docker pull $img)"
done

log "Build image dich vu"
docker build -q -t abc/web:1.0 "$REPO/docker/web" >/dev/null
docker build -q -t abc/dns:1.0 -f "$REPO/docker/dns/Dockerfile" "$REPO" >/dev/null

# ---------- Tóm tắt ----------
log "KET QUA"
docker version --format 'Docker Engine: {{.Server.Version}}'
docker compose version
containerlab version | grep -E 'version:'
apt-mark showhold | tr '\n' ' '; echo
docker images --format '{{.Repository}}:{{.Tag}}  {{.Size}}' | grep -E 'abc/|frr|netshoot' || true
echo "Xong. Thoat roi 'vagrant ssh' lai de nhan nhom docker va clab_admins."
