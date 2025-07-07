# vpn-tunnel
Tunnel VPN Installer by REGAR STORE (Vmess, Vless, Trojan, SSH)
## 💻 Dikembangkan oleh
REGAR STORE  
Telegram: @REGAR_STORE 

Telegram Grup: @regar_stores

## 📌 Catatan Penting
- Sertifikat dummy (`cert.crt`, `priv.key`) hanya untuk testing. Untuk produksi, gunakan sertifikat dari [Let's Encrypt](https://letsencrypt.org/).
- Script ini **tidak menyembunyikan aktivitas ilegal**. Pastikan Anda mematuhi hukum setempat.

## 🔧 Fitur
- Instalasi Xray untuk Vmess (port 443), Vless (port 80), dan Trojan (port 443).
- Instalasi OpenSSH.
- Speed test dengan `speedtest-cli`.
- Menu interaktif untuk pilihan instalasi.
- **Lifetime Activation**: Layanan Xray dan SSH diatur untuk berjalan selamanya dengan `systemctl enable`.

---

## 📦 Port yang Digunakan
| Protokol | Port | Jenis Koneksi         |
|---------|------|------------------------|
| Vmess   | 443  | WebSocket + TLS        |
| Vless   | 80   | WebSocket              |
| Trojan  | 443  | TCP + TLS              |
| SSH     | 22   | Default                |

---

## 🚀 Cara Instalasi
# REGAR STORE VPN MANAGER
```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/regarstore/repository.git
cd repository
chmod +x regar-vpn.sh
sudo ./regar-vpn.sh


   
