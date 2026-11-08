#!/usr/bin/env bash
# smoke.sh – kiểm tra nhanh lab "abc" sau khi deploy. Mỗi mục in PASS/FAIL.
# Exit code = số mục FAIL (0 = tất cả PASS).
cd "$(dirname "$0")/.."
fail=0
check() { local name="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $name"; else echo "FAIL  $name"; fail=$((fail+1)); fi; }
nbr_full() { [ "$(docker exec "clab-abc-$1" vtysh -c 'show ip ospf neighbor' | grep -c Full)" -ge "$2" ]; }
bgp_up()   { docker exec clab-abc-r-edge vtysh -c 'show bgp summary' | grep -E '^203\.0\.113\.1 ' | awk '{print $10}' | grep -Eq '^[0-9]+$'; }
ping_ok()  { docker exec "clab-abc-$1" ping -c 3 -W 1 "$2"; }
dns_ok()   { [ "$(docker exec clab-abc-pc-br1 dig @192.168.20.53 web.abc.lab +short)" = "192.168.20.10" ]; }
nx_ok()    { docker exec clab-abc-pc-br1 dig @192.168.20.53 khongco.abc.lab | grep -q NXDOMAIN; }
web_ok()   { [ "$(docker exec clab-abc-pc-br1 curl -s -o /dev/null -w '%{http_code}' http://web.abc.lab)" = "200" ]; }

check "OSPF r-hq co 2 neighbor Full"     nbr_full r-hq 2
check "OSPF r-br co 2 neighbor Full"     nbr_full r-br 2
check "OSPF r-edge co 2 neighbor Full"   nbr_full r-edge 2
check "BGP r-edge <-> r-isp Established" bgp_up
check "r-br co default route (O E2)"     sh -c "docker exec clab-abc-r-br vtysh -c 'show ip route 0.0.0.0/0' | grep -q ospf"
check "pc-br1 -> pc-hq1"                 ping_ok pc-br1 192.168.10.100
check "pc-br1 -> srv-web"                ping_ok pc-br1 192.168.20.10
check "pc-br1 -> srv-dns"                ping_ok pc-br1 192.168.20.53
check "pc-br1 -> inet-host (qua ISP)"    ping_ok pc-br1 198.51.100.10
check "pc-hq1 -> inet-host (qua ISP)"    ping_ok pc-hq1 198.51.100.10
check "DNS web.abc.lab = 192.168.20.10"  dns_ok
check "DNS ten la -> NXDOMAIN"           nx_ok
check "HTTP http://web.abc.lab = 200"    web_ok
echo "----"; [ "$fail" -eq 0 ] && echo "TAT CA PASS" || echo "$fail muc FAIL"
exit "$fail"
