#!/usr/bin/env bash
# save.sh – chép cấu hình đang chạy của 4 router về configs/<router>/frr.conf
# Dùng sau khi sửa router bằng vtysh, TRƯỚC khi destroy/deploy lại
# (lab dùng enforce-startup-config: configs/ là nguồn sự thật).
set -euo pipefail
cd "$(dirname "$0")/.."
for r in r-hq r-br r-edge r-isp; do
  c="clab-abc-$r"
  docker exec "$c" vtysh -c "write memory" >/dev/null
  docker exec "$c" vtysh -c "show running-config" \
    | sed '1,/^Current configuration:/d' | sed '/^end$/d' > "configs/$r/frr.conf.new"
  mv "configs/$r/frr.conf.new" "configs/$r/frr.conf"
  echo "Da luu configs/$r/frr.conf"
done
echo; git status --short configs/ 2>/dev/null || true
echo "Nho commit thay doi (tren Windows: GitHub Desktop hoac VS Code)."
