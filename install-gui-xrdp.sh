#!/bin/bash
# ============================================================
# install-gui-xrdp.sh — Install GUI (Xfce + XRDP + Firefox)
# di Ubuntu 24.04, hasil rangkuman install manual + semua
# perbaikan yang sudah diverifikasi di VPS GTPS.
#
# Yang dilakukan script ini:
#   1. Install xfce4, xfce4-goodies, xrdp, firefox (via apt)
#   2. Buat user RDP (default: admin) + password + grup sudo
#   3. Set session Xfce (.xsession) untuk user tersebut
#   4. Perbaiki TLS XRDP (xrdp masuk grup ssl-cert) supaya
#      NLA jalan dan client RDP tidak disconnect sendiri
#   5. Bersihkan session lama yang nyangkut (kalau ada)
#   6. Enable + restart xrdp & xrdp-sesman, lalu verifikasi
#
# Cara pakai (jalankan sebagai root / sudo):
#   sudo ./install-gui-xrdp.sh admin 'password-rahasia'
#   atau:
#   RDP_PASS='password-rahasia' sudo -E ./install-gui-xrdp.sh admin
#
# Catatan:
#   - Password JANGAN ditulis di dalam script ini. Isi lewat
#     argumen / env var seperti contoh di atas.
#   - Script ini idempotent: aman dijalankan ulang. Tapi kalau
#     dijalankan saat ada user RDP yang sedang login, session
#     tersebut akan diputus (langkah 5) dan service di-restart.
#   - Jangan upload script ini ke tempat publik dalam keadaan
#     password sudah terisi di command history / shell.
# ============================================================
set -euo pipefail

RDP_USER="${1:-admin}"
RDP_PASS="${2:-${RDP_PASS:-}}"

if [ -z "$RDP_PASS" ]; then
  echo "Usage: sudo $0 [username] <password>" >&2
  echo "   atau: RDP_PASS='<password>' sudo -E $0 [username]" >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Script ini harus dijalankan sebagai root (pakai sudo)." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "== [1/7] Update apt & install xfce4 + xrdp + firefox =="
apt update
apt install -y xfce4 xfce4-goodies xrdp firefox

echo "== [2/7] Bersihkan session RDP lama yang nyangkut (jika ada) =="
if id "$RDP_USER" >/dev/null 2>&1; then
  # Session yatim (mis. sisa restart xrdp-sesman) bikin login baru
  # bentrok: window manager langsung mati, RDP ke-disconnect.
  pkill -u "$RDP_USER" 2>/dev/null || true
  sleep 2
fi

echo "== [3/7] Buat user RDP '$RDP_USER' =="
if ! id "$RDP_USER" >/dev/null 2>&1; then
  # Grup 'admin' biasanya sudah ada di Ubuntu -> useradd gagal
  # kalau coba bikin grup dengan nama yang sama. Pakai grup itu.
  if getent group admin >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g admin "$RDP_USER"
  else
    useradd -m -s /bin/bash "$RDP_USER"
  fi
  echo "User $RDP_USER dibuat."
else
  echo "User $RDP_USER sudah ada, lanjut."
fi
usermod -aG sudo "$RDP_USER"
printf '%s:%s\n' "$RDP_USER" "$RDP_PASS" | chpasswd
echo "Password & grup sudo sudah diset."

echo "== [4/7] Set session Xfce untuk $RDP_USER =="
printf 'xfce4-session\n' > "/home/$RDP_USER/.xsession"
chown "$RDP_USER:$RDP_USER" "/home/$RDP_USER/.xsession"
chmod 644 "/home/$RDP_USER/.xsession"

echo "== [5/7] Perbaiki TLS XRDP (xrdp masuk grup ssl-cert) =="
# Tanpa ini xrdp tidak bisa baca /etc/xrdp/key.pem, TLS/NLA mati,
# server cuma tawarkan RDP polos dan client modern akan disconnect.
adduser xrdp ssl-cert 2>/dev/null || true
if sudo -u xrdp head -c 1 /etc/xrdp/key.pem >/dev/null 2>&1; then
  echo "TLS key sudah bisa dibaca user xrdp."
else
  echo "WARNING: user xrdp masih tidak bisa baca /etc/xrdp/key.pem!" >&2
fi

echo "== [6/7] Buka port 3389 di ufw (kalau ufw terpasang) =="
if command -v ufw >/dev/null 2>&1; then
  ufw allow 3389/tcp || true
fi

echo "== [7/7] Enable + restart xrdp & xrdp-sesman =="
systemctl enable xrdp
systemctl restart xrdp xrdp-sesman
sleep 2

echo "== Verifikasi =="
systemctl is-active xrdp xrdp-sesman
ss -tln | grep 3389 || { echo "ERROR: port 3389 tidak listen!" >&2; exit 1; }

echo
echo "Selesai. Login RDP ke <IP-VPS>:3389 dengan user '$RDP_USER'."
echo "Kalau login gagal, cek log: sudo tail -50 /var/log/xrdp.log"
echo "dan: sudo tail -50 /var/log/xrdp-sesman.log"
