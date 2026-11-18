#!/usr/bin/env bash
# kiem-tra-nhanh.sh – kiểm tra nhanh lab "congty" sau khi deploy. Mỗi mục in PASS/FAIL.
# Exit code = số mục FAIL (0 = tất cả PASS).
cd "$(dirname "$0")/.."
fail=0
check() { local name="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $name"; else echo "FAIL  $name"; fail=$((fail+1)); fi; }
nbr_full() { [ "$(docker exec "$1" vtysh -c 'show ip ospf neighbor' | grep -c Full)" -ge "$2" ]; }
bgp_up()   { docker exec router-bien vtysh -c 'show bgp summary' | grep -E '^203\.0\.113\.1 ' | awk '{print $10}' | grep -Eq '^[0-9]+$'; }
ping_ok()  { docker exec "$1" ping -c 3 -W 1 "$2"; }
dns_ok()   { [ "$(docker exec may-tinh-chi-nhanh dig @192.168.20.53 web.congty.lab +short)" = "192.168.20.10" ]; }
nx_ok()    { docker exec may-tinh-chi-nhanh dig @192.168.20.53 khongco.congty.lab | grep -q NXDOMAIN; }
web_ok()   { [ "$(docker exec may-tinh-chi-nhanh curl -s -o /dev/null -w '%{http_code}' http://web.congty.lab)" = "200" ]; }

check "OSPF router-tru-so co 2 neighbor Full"     nbr_full router-tru-so 2
check "OSPF router-chi-nhanh co 2 neighbor Full"     nbr_full router-chi-nhanh 2
check "OSPF router-bien co 2 neighbor Full"   nbr_full router-bien 2
check "BGP router-bien <-> router-nha-mang Established" bgp_up
check "router-chi-nhanh co default route (O E2)"     sh -c "docker exec router-chi-nhanh vtysh -c 'show ip route 0.0.0.0/0' | grep -q ospf"
check "may-tinh-chi-nhanh -> may-tinh-tru-so"                 ping_ok may-tinh-chi-nhanh 192.168.10.100
check "may-tinh-chi-nhanh -> may-chu-web"                ping_ok may-tinh-chi-nhanh 192.168.20.10
check "may-tinh-chi-nhanh -> may-chu-dns"                ping_ok may-tinh-chi-nhanh 192.168.20.53
check "may-tinh-chi-nhanh -> may-ngoai-internet (qua ISP)"    ping_ok may-tinh-chi-nhanh 198.51.100.10
check "may-tinh-tru-so -> may-ngoai-internet (qua ISP)"    ping_ok may-tinh-tru-so 198.51.100.10
check "DNS web.congty.lab = 192.168.20.10"  dns_ok
check "DNS ten la -> NXDOMAIN"           nx_ok
check "HTTP http://web.congty.lab = 200"    web_ok
echo "----"; [ "$fail" -eq 0 ] && echo "TAT CA PASS" || echo "$fail muc FAIL"
exit "$fail"
