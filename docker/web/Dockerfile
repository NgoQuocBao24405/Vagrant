# abc/web:1.0 – máy chủ web nội bộ của công ty ABC (srv-web, 192.168.20.10)
# Lệnh ít thay đổi đặt trước (cache layer), file hay sửa đặt sau.
FROM nginx:1.30.6-alpine
# iproute2: containerlab gán IP cho eth1 bằng lệnh "ip"
RUN apk add --no-cache iproute2
COPY index.html /usr/share/nginx/html/index.html
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
