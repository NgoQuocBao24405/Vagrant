# abc/dns:1.0 – DNS nội bộ zone abc.lab (srv-dns, 192.168.20.53)
# Build context = GỐC repo, để dùng chung một nguồn cấu hình configs/srv-dns/
#   docker build -t abc/dns:1.0 -f docker/dns/Dockerfile .
FROM alpine:3.24
RUN apk add --no-cache bind bind-tools iproute2 \
 && mkdir -p /run/named /var/bind \
 && chown -R named:named /run/named /var/bind
COPY configs/srv-dns/named.conf /etc/bind/named.conf
COPY configs/srv-dns/db.abc.lab /etc/bind/db.abc.lab
# Cấu hình sai thì build thất bại ngay, không đợi tới lúc chạy
RUN named-checkconf /etc/bind/named.conf && named-checkzone abc.lab /etc/bind/db.abc.lab
EXPOSE 53/udp 53/tcp
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD dig @127.0.0.1 web.abc.lab +short | grep -q 192.168.20.10
CMD ["named", "-g", "-4", "-u", "named", "-c", "/etc/bind/named.conf"]
