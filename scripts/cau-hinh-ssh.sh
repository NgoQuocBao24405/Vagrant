#!/usr/bin/env bash
# cau-hinh-ssh.sh – cho phép gõ "ssh router-tru-so" (không cần admin@, không cần mật khẩu).
# Chạy bằng user vagrant trong VM. Idempotent: chạy lại bao nhiêu lần cũng được.
#   1) tạo khóa ~/.ssh/id_ed25519 nếu chưa có. Khi deploy, containerlab tự chép mọi
#      ~/.ssh/*.pub vào /home/admin/.ssh/authorized_keys của router FRR -> đăng nhập bằng khóa.
#   2) ghi khối cấu hình cho 4 router vào ~/.ssh/config (User admin, bỏ kiểm tra host key).
# Mật khẩu "admin" vẫn dùng được nếu khóa chưa được nạp (lab dựng trước khi có khóa).
set -euo pipefail
ROUTERS="router-tru-so router-chi-nhanh router-bien router-nha-mang"
D="$HOME/.ssh"; CFG="$D/config"
BEGIN="# >>> lab congty (scripts/cau-hinh-ssh.sh) >>>"; END="# <<< lab congty <<<"

install -d -m 700 "$D"
[ -f "$D/id_ed25519" ] || ssh-keygen -q -t ed25519 -N "" -C "vagrant@may-ao-lab" -f "$D/id_ed25519"

touch "$CFG"; chmod 600 "$CFG"
# Bỏ khối cũ (nếu có) rồi ghi lại khối mới ở đầu file (ssh lấy giá trị khớp đầu tiên)
old=$(awk -v b="$BEGIN" -v e="$END" '$0==b{s=1;next} $0==e{s=0;next} !s' "$CFG")
{
  echo "$BEGIN"
  echo "Host $ROUTERS"
  echo "    User admin"
  echo "    IdentityFile ~/.ssh/id_ed25519"
  echo "    StrictHostKeyChecking no"
  echo "    UserKnownHostsFile /dev/null"
  echo "    LogLevel ERROR"
  echo "$END"
  if [ -n "$old" ]; then printf '%s\n' "$old"; fi
} > "$CFG.new"
mv "$CFG.new" "$CFG"
echo "Da cau hinh SSH: ssh router-tru-so | router-chi-nhanh | router-bien | router-nha-mang"
