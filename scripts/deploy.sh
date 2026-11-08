#!/usr/bin/env bash
# deploy.sh – dựng lab "abc" bằng containerlab. Chạy trong VM: cd /vagrant && ./scripts/deploy.sh
# Tham số thêm được chuyển thẳng cho containerlab, vd: ./scripts/deploy.sh --reconfigure
set -euo pipefail
cd "$(dirname "$0")/.."

# Thư mục runtime của lab nằm trên ext4 của VM, không nằm trong /vagrant (vboxsf)
export CLAB_LABDIR_BASE="${CLAB_LABDIR_BASE:-$HOME/clab-runtime}"
mkdir -p "$CLAB_LABDIR_BASE"

# 1) Bridge br-srv (switch LAN máy chủ) phải có trước khi deploy
ip link show br-srv >/dev/null 2>&1 || sudo ip link add br-srv type bridge
sudo ip link set br-srv up

# 2) Docker đặt FORWARD policy DROP và bật br_netfilter: gói đi qua br-srv sẽ bị chặn.
#    Cho phép lưu lượng bên trong br-srv qua chain DOCKER-USER (chain dành cho người dùng).
sudo iptables -C DOCKER-USER -i br-srv -o br-srv -j ACCEPT 2>/dev/null \
  || sudo iptables -I DOCKER-USER -i br-srv -o br-srv -j ACCEPT

# 3) Dựng lab và đo thời gian
start=$(date +%s)
containerlab deploy -t clab/abc.clab.yml "$@"
echo "deploy_s=$(( $(date +%s) - start ))"

# 4) Chờ OSPF hội tụ (r-hq có 2 neighbor Full), tối đa 120 s
echo "Cho OSPF hoi tu..."
for i in $(seq 1 60); do
  n=$(docker exec clab-abc-r-hq vtysh -c "show ip ospf neighbor" 2>/dev/null | grep -c "Full" || true)
  if [ "${n:-0}" -ge 2 ]; then echo "OSPF hoi tu sau ~$(( $(date +%s) - start )) s"; exit 0; fi
  sleep 2
done
echo "OSPF CHUA hoi tu sau 120 s – xem: docker exec clab-abc-r-hq vtysh -c 'show ip ospf neighbor'" >&2
exit 1
