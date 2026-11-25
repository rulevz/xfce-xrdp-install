# xfce-xrdp-install

Install GUI (Xfce + XRDP + Firefox) di Ubuntu 24.04 — misalnya VPS — lengkap dengan user RDP dan perbaikan TLS supaya koneksi RDP stabil.

## Yang dilakukan script ini

1. Install `xfce4`, `xfce4-goodies`, `xrdp`, `firefox` (via apt)
2. Bersihkan session RDP lama yang nyangkut (kalau ada)
3. Buat user RDP (default: `admin`) + password + grup `sudo`
4. Set session Xfce (`.xsession`) untuk user tersebut
5. Perbaiki TLS XRDP (user `xrdp` masuk grup `ssl-cert`) supaya NLA jalan dan client RDP tidak disconnect sendiri
6. Buka port 3389 di ufw (kalau ufw terpasang)
7. Enable + restart `xrdp` & `xrdp-sesman`, lalu verifikasi

## Cara pakai

### Via git

```bash
git clone https://github.com/rulevz/xfce-xrdp-install.git
cd xfce-xrdp-install
chmod +x install-gui-xrdp.sh
sudo ./install-gui-xrdp.sh admin 'password-rahasia'
```

### Via wget (tanpa git)

```bash
wget https://raw.githubusercontent.com/rulevz/xfce-xrdp-install/main/install-gui-xrdp.sh
chmod +x install-gui-xrdp.sh
sudo ./install-gui-xrdp.sh admin 'password-rahasia'
```

Password juga bisa diisi lewat environment variable:

```bash
RDP_PASS='password-rahasia' sudo -E ./install-gui-xrdp.sh admin
```

## Catatan

- Password **jangan** ditulis di dalam script. Isi lewat argumen / env var seperti contoh di atas.
- Script ini idempotent (aman dijalankan ulang). Tapi kalau dijalankan saat ada user RDP yang sedang login, session tersebut akan diputus (langkah bersih-bersih) dan service di-restart. Pakai saat VPS fresh/reset, atau saat tidak ada yang login.
- Setelah selesai, login RDP ke `<IP-VPS>:3389` dengan user yang dibuat.
- Kalau login gagal, cek log di VPS: `sudo tail -50 /var/log/xrdp.log` dan `sudo tail -50 /var/log/xrdp-sesman.log`.
- Diuji di Ubuntu 24.04.5 LTS (VPS 2 CPU / 2 GB RAM).
