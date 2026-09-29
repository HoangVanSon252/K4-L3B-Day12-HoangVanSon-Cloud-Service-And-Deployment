# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
#
# Dưới đây là Dockerfile "chạy được nhưng chưa production": một stage,
# chạy bằng user root, không có health check, base image nặng.
#
# NHIỆM VỤ: sửa file này thành bản production-ready. Yêu cầu:
#   [ ] Multi-stage build: stage `builder` cài dependency, stage runtime
#       chỉ copy kết quả sang → image nhỏ hơn, không mang theo compiler.
#       Cú pháp: `FROM python:3.11-slim AS builder`
#   [ ] Base image slim (hoặc alpine), không dùng `python:3.11` bản đầy đủ
#   [ ] COPY requirements.txt và pip install TRƯỚC khi COPY source code
#       (Docker cache theo layer: sửa 1 dòng code không phải cài lại thư viện)
#   [ ] Tạo user thường và chuyển sang bằng lệnh `USER` — container chạy
#       root nghĩa là ai thoát được khỏi app cũng thành root trên host
#   [ ] Có `HEALTHCHECK` gọi vào endpoint /health
#   [ ] Đọc cổng từ biến môi trường PORT (cloud tự gán cổng, không cố định 8000)
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# -----------------------------------------------------
# STAGE 1: Builder (Chỉ dùng để cài đặt thư viện)
# -----------------------------------------------------
FROM python:3.11-slim AS builder

WORKDIR /app

# Tạo môi trường ảo (venv) để lát nữa dễ dàng bê sang stage sau
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy file requirements trước để tận dụng Docker Cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# -----------------------------------------------------
# STAGE 2: Runtime (Môi trường chạy thực tế siêu nhẹ)
# -----------------------------------------------------
FROM python:3.11-slim

WORKDIR /app

# Tạo user không phải root (vì lý do bảo mật)
RUN useradd -m -r agentuser

# Copy các gói thư viện đã cài đặt từ stage builder sang
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Khai báo cổng mặc định
ENV PORT=8000

# Copy mã nguồn vào (bước này làm cuối cùng để không bị mất cache khi sửa code)
COPY . .

# Chuyển sang user thường
USER agentuser

# Chạy Healthcheck bằng Python (không cần cài thêm curl để image gọn nhất có thể)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request, os; urllib.request.urlopen('http://localhost:' + os.environ.get('PORT', '8000') + '/health')" || exit 1

# Lệnh khởi động app, đọc cổng từ biến môi trường PORT
CMD sh -c "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"
