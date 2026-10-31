# AGENTS.md – Kart Savaşı Projesi

Bu dosya, projenin nerede kaldığını ve sıradaki işleri gösterir.
Yeni bir sohbete başlarken bu dosyayı Claude'a yapıştırın.

## Proje özeti
- **Oyun:** Mobil kart savaşı (Card Battle), dikey ekran, Türkçe arayüz
- **Teknoloji:** Flutter + Flame (savaş arenası), Provider (oyuncu verisi)
- **Repo:** github.com/ganyansosyal/fotoproje (dal: `main`)
- **Geliştirme yöntemi:** Sadece telefondan. Kod GitHub web arayüzünden yüklenir, APK GitHub Actions ile derlenir.
- **Firebase:** Şimdilik ertelendi (bağımlılıklar `pubspec.yaml` içinde, `main.dart` try/catch ile korumalı)

## Klasör yapısı
```
fotoproje/
├─ .github/workflows/build.yml   # APK derleme (sadece elle çalışır)
├─ assets/images/                # 16 görsel (aşağıda listelendi)
├─ pubspec.yaml
└─ lib/
   ├─ main.dart                  # Giriş, tema, rotalar, OyuncuDurumu
   ├─ screens/
   │   ├─ main_menu_screen.dart  # Ana menü
   │   └─ battle_screen.dart     # Flame GameWidget sarmalayıcı
   └─ game/
       └─ battle_game.dart       # Savaş arenası (Flame)
```
`android/` klasörü repoda yok. Workflow derleme sırasında `flutter create` ile otomatik üretir.

## Yapılanlar
- [x] **Adım 1:** `pubspec.yaml` bağımlılıkları ve `main.dart` iskeleti
- [x] **Adım 2:** Ana menü (seviye, altın, elmas, SAVAŞA BAŞLA, Deste/Mağaza/Görevler/Ayarlar)
- [x] **Adım 3:** Savaş arenası kodu yazıldı (**henüz derlenip test edilmedi**)
  - Kart sürükle-bırak, slot vurgulama, mana kontrolü
  - Tur sistemi: TURU BİTİR → kartlar saldırır → bot rakip oynar
  - Hasar yazıları, kart ölümü, kazanma/kaybetme ekranı, kazanınca +50 altın
- [x] **Görseller:** Leonardo/Gemini ile üretildi, adlandırıldı, GitHub'a yüklendi
- [x] **GitHub Actions:** `build.yml` hazır, otomatik tetikleme kapalı

## Sıradaki işler (öncelik sırasıyla)
1. [ ] Actions'ta derle, APK'yı telefona kur, savaşı test et ve hataları düzelt
2. [ ] **Adım 4:** Deste kurulumu ve koleksiyon ekranı (üstte 15 slot, altta kart gridi)
3. [ ] **Adım 5:** Mağaza ve paket açılış animasyonu (Temel / Epik / Efsanevi)
4. [ ] Ana menüyü tasarıma göre yenile (koyu kahve + altın çerçeve, avatar çerçevesi, altın/elmas ikonları)
5. [ ] Görevler ve Ayarlar ekranları
6. [ ] Oyuncu verisini kalıcı yap (önce `shared_preferences`, sonra Firebase)
7. [ ] **Adım 6:** Firebase (Firestore) ile `GameDatabaseService`
8. [ ] Ses efektleri ve müzik (`flame_audio`)
9. [ ] Denge ayarı: kart istatistikleri, farklı yetenekler, daha akıllı bot
10. [ ] Canlı PvP (en sona, ayrı sunucu mantığı gerekir)

## APK nasıl derlenir
1. Repo → **Actions** → **APK Derle** → **Run workflow**
2. 5–8 dakika bekleyin. Yeşil tik olunca en alttaki **Artifacts** bölümünden `kart-savasi-apk` indirin.
3. Zip'i açıp APK'yı telefona kurun.
4. Kırmızı çarpı çıkarsa hata metnini Claude'a gönderin.

## Görseller (`assets/images/`)
| Dosya | İçerik |
|---|---|
| `ejderha.jpg`, `buyucu.jpg`, `savasci.jpg`, `okcu.jpg`, `suikastci.jpg` | 5 sınıf kart illüstrasyonu |
| `kart_sablon.jpg` | Boş kart şablonu |
| `paket_temel.jpg`, `paket_epik.jpg`, `paket_efsanevi.jpg`, `paket_bos.jpg` | Paket arka yüzleri |
| `panel.jpg` | Boş panel |
| `altin.png`, `elmas.png`, `avatar_cerceve.png` | Şeffaf ikonlar |
| `arena.jpg`, `arena_alt.jpg` | Savaş arka planı (dikey) |

## Oyun kuralları (şu anki sürüm)
- Her kart: Saldırı 1000, Can 1500 (görsellerdeki yazıyla aynı)
- Mana bedelleri: Savaşçı 2, Okçu 3, Suikastçı 3, Büyücü 4, Ejderha 5
- Kahraman canı: 5000. Başlangıç mana 3, her tur +1 (en fazla 10)
- Masada 3 slot. Karşı slotta kart yoksa hasar kahramana gider
- Elde en fazla 4 kart, her tur 1 kart çekilir

## Bilinen notlar ve kısıtlar
- Kart görsellerindeki "1000 / 1500" yazıları resme gömülü. Farklı stat için `kart_sablon.jpg` üzerine kodla yazı çizilmeli.
- Derleme ortamı olmadığı için kod yazılırken derlenemiyor, hatalar Actions'tan öğreniliyor.
- Play Store yayını için geliştirici hesabı gerekir (tek seferlik ücret).
- Dosya yüklerken yol `.github/workflows` içinde kalırsa `lib/...` yerine yanlış klasöre düşer. Ana dizinden başlayın.

## Sohbet notları
- Kısa cevap isteniyor, adım adım ilerleniyor.
- Promptlar kopyalanabilir kutu içinde verilmeli.
- GitHub yükleme linki: `github.com/ganyansosyal/fotoproje/upload/main/<klasör>`
