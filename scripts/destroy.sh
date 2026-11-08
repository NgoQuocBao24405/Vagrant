#!/usr/bin/env bash
# destroy.sh – gỡ lab "abc". Mặc định GIỮ thư mục lab (cấu hình đã lưu).
#   ./scripts/destroy.sh               gỡ container, giữ thư mục lab
#   ./scripts/destroy.sh --force-clean gỡ và XÓA luôn thư mục lab (hỏi xác nhận)
set -euo pipefail
cd "$(dirname "$0")/.."
export CLAB_LABDIR_BASE="${CLAB_LABDIR_BASE:-$HOME/clab-runtime}"

if [ "${1:-}" = "--force-clean" ]; then
  read -r -p "Xoa ca thu muc lab (cau hinh chua save se mat). Go 'yes' de tiep tuc: " ans
  [ "$ans" = "yes" ] || { echo "Huy."; exit 1; }
  containerlab destroy -t clab/abc.clab.yml --cleanup
else
  containerlab destroy -t clab/abc.clab.yml
fi
