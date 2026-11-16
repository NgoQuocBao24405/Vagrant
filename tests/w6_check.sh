#!/usr/bin/env bash
# w6_check.sh – kiểm thử tuần 6 (TC10, TC11, TC12, TC13, TC18, TC19) và lưu bằng chứng.
# Chạy trong VM:  cd /vagrant && bash tests/w6_check.sh
# Mỗi TC in PASS/FAIL; log đầy đủ ở docs/evidence/W6_<TC>.log. Exit code = số TC FAIL.
set -uo pipefail
cd "$(dirname "$0")/.."
export CLAB_LABDIR_BASE="${CLAB_LABDIR_BASE:-$HOME/clab-runtime}"
EV=docs/evidence; mkdir -p "$EV"
TOPO=clab/abc.clab.yml
fail=0; summary=()
log() { echo "$*" | tee -a "$CUR"; }
run() { log ""; log "\$ $*"; "$@" 2>&1 | tee -a "$CUR"; return "${PIPESTATUS[0]}"; }
start_tc() { CUR="$EV/W6_$1.log"; : > "$CUR"; log "# $1 – $2 ($(date -Iseconds))"; }
result() { if [ "$2" = 0 ]; then summary+=("PASS  $1  $3"); else summary+=("FAIL  $1  $3"); fail=$((fail+1)); fi; log "=> $1: $([ "$2" = 0 ] && echo PASS || echo FAIL)"; }

# ---------- TC10: topology hợp lệ ----------
start_tc TC10 "containerlab validate topology abc"
run containerlab validate -t "$TOPO"; rc=$?
result TC10 $rc "validate abc.clab.yml không lỗi"

# ---------- TC11: khóa 'extras' (đã bỏ từ 0.81) phải bị từ chối ----------
start_tc TC11 "topology cố ý chứa khóa extras phải bị từ chối"
LEG=/tmp/abc-legacy.clab.yml
sed '/^    r-hq:$/a\      extras: {}' "$TOPO" > "$LEG"
run grep -n -A2 '^    r-hq:' "$LEG"
run containerlab validate -t "$LEG"; rc=$?
[ "$rc" -ne 0 ] && r=0 || r=1
result TC11 $r "bản có extras bị báo lỗi (exit=$rc)"

# ---------- TC12: deploy đủ 9 container + br-srv 3 cổng ----------
start_tc TC12 "deploy lab abc: 9 container + br-srv 3 cổng"
containerlab destroy -t "$TOPO" >/dev/null 2>&1 || true
t0=$(date +%s); run ./scripts/deploy.sh; drc=$?; T_DEPLOY_END=$(date +%s)
log "thoi_gian_deploy=$((T_DEPLOY_END-t0))s"
run containerlab inspect -t "$TOPO"
n=$(docker ps --filter label=containerlab=abc --format '{{.Names}}' | wc -l)
p=$(bridge link 2>/dev/null | grep -c 'master br-srv')
run bash -c "bridge link | grep br-srv"
log "so_container=$n  so_cong_br_srv=$p  deploy_exit=$drc"
[ "$drc" = 0 ] && [ "$n" = 9 ] && [ "$p" = 3 ]; result TC12 $? "9 container, br-srv $p cổng"

# ---------- TC13: OSPF hai vùng hội tụ ----------
start_tc TC13 "OSPF: mỗi router 2 neighbor Full, r-br có route liên vùng tới LAN HQ"
ok=0
# Chờ SPF chạy xong (tối đa 90s) trước khi kiểm tra: ngay sau deploy neighbor vừa Full nhưng chưa có route IA.
for i in $(seq 1 90); do
  docker exec clab-abc-r-br vtysh -c "show ip ospf route" | grep -E '192\.168\.(10|20)\.0/24' | grep -c 'IA' | grep -qx 2 && break
  sleep 1
done
log "thoi_gian_hoi_tu_sau_deploy=$(( $(date +%s)-T_DEPLOY_END ))s (cho toi da 90s)"
for r in r-hq r-br r-edge; do
  run docker exec clab-abc-$r vtysh -c "show ip ospf neighbor"
  c=$(docker exec clab-abc-$r vtysh -c "show ip ospf neighbor" | grep -c Full)
  log "$r: $c neighbor Full"; [ "$c" -ge 2 ] || ok=1
done
run docker exec clab-abc-r-br vtysh -c "show ip ospf route"
run docker exec clab-abc-r-br vtysh -c "show ip route ospf"
run docker exec clab-abc-r-hq vtysh -c "show ip ospf border-routers"
run docker exec clab-abc-r-br vtysh -c "show ip ospf database summary"
run docker exec clab-abc-r-hq vtysh -c "show ip ospf interface eth2"
run docker exec clab-abc-r-br vtysh -c "show ip ospf neighbor json"
docker exec clab-abc-r-br vtysh -c "show ip ospf route" | grep -E '192\.168\.10\.0/24|192\.168\.20\.0/24' | grep -q 'IA' || ok=1
result TC13 $ok "3 router x 2 neighbor Full; r-br thấy 192.168.10/20.0 dạng IA"

# ---------- TC18: truy cập node bằng ssh / exec / graph ----------
start_tc TC18 "truy cập node: cổng SSH, containerlab exec, docker exec, graph"
ok=0
run bash -c "timeout 3 bash -c '</dev/tcp/172.20.20.11/22' && echo 'cong SSH 22 cua r-hq mo'" || ok=1
run containerlab exec -t "$TOPO" --label clab-node-name=pc-br1 --cmd "ip -br addr show eth1" || ok=1
run docker exec clab-abc-r-hq vtysh -c "show version" || ok=1
run containerlab graph -t "$TOPO" --mermaid || ok=1
ls clab/*.mermaid "$CLAB_LABDIR_BASE"/clab-abc/*.mermaid 2>/dev/null | tee -a "$CUR"
( timeout 15 containerlab graph -t "$TOPO" --srv 0.0.0.0:50080 >/dev/null 2>&1 & ); sleep 5
run bash -c "curl -s -o /dev/null -w 'graph web http_code=%{http_code}\n' http://127.0.0.1:50080" || ok=1
log "Mo tren Windows: http://192.168.56.10:50080 trong luc chay: containerlab graph -t $TOPO"
result TC18 $ok "ssh port/exec/graph đều phản hồi"

# ---------- TC19: cấu hình là mã (save -> destroy -> deploy giữ thay đổi) ----------
start_tc TC19 "sửa trên router, save.sh, destroy, deploy lại vẫn còn thay đổi"
run docker exec clab-abc-r-hq vtysh -c "conf t" -c "interface eth3" -c "description TEST-TC19" -c "end" -c "write memory"
run ./scripts/save.sh
run git --no-pager diff --stat configs/
run git --no-pager diff configs/r-hq/frr.conf
run ./scripts/destroy.sh
run ./scripts/deploy.sh
run bash -c "docker exec clab-abc-r-hq vtysh -c 'show running-config' | grep -B1 -A3 TEST-TC19"
docker exec clab-abc-r-hq vtysh -c "show running-config" | grep -q TEST-TC19; result TC19 $? "description TEST-TC19 còn sau destroy/deploy"

# ---------- Tổng kết ----------
CUR="$EV/W6_summary.log"; : > "$CUR"
log "# W6 tổng kết ($(date -Iseconds))"
for s in "${summary[@]}"; do log "$s"; done
log "----"; [ "$fail" = 0 ] && log "TAT CA PASS" || log "$fail TC FAIL"
exit "$fail"
