# Git Radar - Omarchy Linux İçin Canlı Git Deposu ve Commit Takip Eklentisi

[![Omarchy Verified Plugin](https://img.shields.io/badge/Omarchy-Verified_Plugin-22c55e?style=for-the-badge&logo=omarchy)](https://github.com/ozdil)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_A_Coffee-Support_Development-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/ozdil)

Omarchy Linux masaüstü ortamı için gerçek zamanlı çoklu Git deposu izleme, değişiklik (dirty state) tespiti ve geliştirici nabzı eklentisi.

Geliştirici: Ozan Özdil (ozdil)  
Lisans: MIT  
Eklenti Kimliği: ozdil.git-radar

---

## Yetenekler ve Özellikler

- Geliştirici Nabzı: Belirlenen çalışma dizinlerini (Projects, Documents/antigravity, .config/omarchy/plugins vb.) 3 dizin derinliğine kadar sürekli izler ve Git depolarını tespit eder.
- İnteraktif İnceleme Menüsü: Depo kayıtlarını genişleterek güncel dal, son commit özeti, yazar, göreceli zaman ve upstream senkronizasyon (ahead/behind) durumunu görüntüler.
- Dosya Düzeyinde İnceleme: Değiştirilen, izlenmeyen, silinen ve stage edilmiş dosyaları açık durum rozetleriyle ([MOD], [NEW], [DEL], [STG]) listeler.
- Filtre Navigasyonu: Değişiklik içeren (Uncommitted) depolar ile tüm kayıtlı depolar arasında tek tıkla veya klavyeyle geçiş yapar.
- Tek Tıkla Başlatıcılar: Tercih edilen terminal öykünücüsünü (xdg-terminal-exec, foot, alacritty, kitty) veya dosya yöneticisini (xdg-open) doğrudan ilgili deponun kök dizininde açar.
- Wayland Yerel Pano Desteği: Depo mutlak yolunu doğrudan Wayland sistem panosuna (wl-copy / xclip) kopyalar ve kullanıcıya anlık toast bildirimi sunar.
- Klavye Odaklı Kullanım: Ok tuşlarıyla liste gezintisi, Space/Enter ile genişletme, r (yenile), f (filtre), t (terminal aç), o (dosya yöneticisi aç), c (yolu panoya kopyala) ve a (künye/hakkında) kısayolları.
- Dinamik Durum Çubuğu: Üst panel simgesi, izlenen depolarda değişiklik olduğunda dikkat çekici uyarı renkleriyle durumu canlı yansıtır.
- Omarchy Tema Entegrasyonu: Sistem renk paleti ve JetBrainsMono Nerd Font tipografi standardı ile kusursuz uyum sağlar.
- Yüksek Performanslı Rust Motoru: Kesin zaman aşımı (monotonic deadline) ve 64 KiB bellek sınırı içinde çalışan güvenli yerel motor.

---

## Gereksinimler

- git
- cargo ve rustc (Rust derleme araçları, kaynaktan derleme için)

---

## Kurulum ve Yapılandırma

### Omarchy Eklentisini Ekleme
```bash
omarchy plugin add https://github.com/ozdil/omarchy-git-radar.git
```

### Motoru Kaynaktan Derleme
```bash
cd ~/.config/omarchy/plugins/ozdil.git-radar
cargo build --release --locked
install -m 755 target/release/gitradar-engine ./gitradar-engine
```

### Omarchy Kabuğuna Ekleme
`~/.config/omarchy/shell.json` dosyasında `bar.layout.right` altına ekleyin:
```json
{
  "id": "ozdil.git-radar"
}
```

Kabuğu yeniden başlatın:
```bash
omarchy-restart-shell
```

---

## Güvenlik ve Mimari Standartları

Git Radar, Omarchy Linux Güvenlik Standartlarına (AGENTS.md) tam uyumludur:
- Komut Enjeksiyonu Koruması: Tüm Git komutları ayrık argüman dizisi olarak çalıştırılır. Parametreler denetlenir.
- Süreç İzolasyonu: Süreçler sıkı zaman aşımları ve tampon sınırları ile izole edilir; askıda kalma engellenir.
- Düz Metin Arayüz: QML bileşenlerinde `textFormat: Text.PlainText` kullanılarak script/biçimlendirme enjeksiyonu önlenir.

---

## Lisans

MIT Lisansı. Ayrıntılar için [LICENSE](LICENSE) dosyasına bakınız.
