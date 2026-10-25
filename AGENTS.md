# AGENTS.md: EditPro projesi

Bu dosya, projeye sonradan giren bir yapay zekanın nerede kaldığımızı anlaması için yazıldı. Önce bunu oku.

## 1. Proje nedir
**EditPro**: Flutter ile yapılan, sadece **Android** için foto ve video düzenleme uygulaması. 10 ekranlık bir tasarım görseli var (koyu mavi/mor tema): Açılış, Ana Sayfa, Video Düzenleme, Yazı Ekle, Dışa Aktar, Fotoğraf Düzenleme, Efektler ve Filtreler, Şablonlar, Galeri, Profil.

Uygulamayı kullanacak kişi telefondan çalışıyor (bilgisayar yok), kodlar GitHub web arayüzünden elle yükleniyor, APK GitHub Actions ile üretiliyor.

## 2. Kapsam kararları (baştan konuşulanlar)
- **Fotoğraf:** kırp, döndür, parlaklık/kontrast, filtreler (Instagram tarzı çok sayıda filtre isteniyor), telefona kaydet.
- **Video:** hazır videoyu seç, üstüne **yazı (altyazı)** ekle, **720p MP4** olarak kaydet.
  - Asıl kullanım: yaklaşık 3 dakikalık, bir adamın konuştuğu videoya konuşmasını yazıyla dökmek. Yazıyı kullanıcı **kendi elle yazacak**, otomatik konuşma tanıma (Whisper vb.) **istenmiyor**.
  - Her yazı satırının başlangıç ve bitiş saniyesi olacak (onlarca satır olabilir).
  - Planlanan kolaylıklar: bir satırın bitişi sonrakinin başlangıcı olsun; satıra dokununca video o saniyeye atlasın; "şimdi başlasın / şimdi bitsin" butonları.
  - Yazı görünümü sorusu (altta klasik altyazı mı, ortada büyük mü, ikisi de mi) henüz **cevaplanmadı**.
  - Müzik ekleme, kesme, animasyon ilk sürümde **yok**.
- **Video motoru için plan:** Android **Media3 Transformer** (Google'ın ücretsiz kütüphanesi) + küçük bir **Kotlin köprüsü** (MethodChannel). FFmpeg önerilmedi çünkü `ffmpeg_kit_flutter` bırakıldı.
- Tasarımdaki Şablonlar ve Profil ekranları en sona bırakıldı, gerekmezse hiç yapılmayabilir.

## 3. Çalışma sırası kararı
Önce ekranlar/arayüz, sonra gerçek işlevler. Fotoğraf tarafı gerçek çalışır hale getirildi. Video tarafı en sona, en büyük iş olarak bırakıldı.

## 4. Teknik yapı
- Repo adı: `fotoproje` (GitHub, public). Adı değişse bile build etkilenmez.
- Uygulama adı: EditPro, paket: `com.editpro`, proje adı `editpro`.
- **Önemli:** Repoda `android/` klasörü **yok**. Workflow her build'de `flutter create --org com.editpro --project-name editpro --platforms android .` çalıştırıp `android/` klasörünü üretiyor, sonra `AndroidManifest.xml` içindeki uygulama adını `sed` ile "EditPro" yapıyor. Mevcut `lib/` ve `pubspec.yaml` ezilmez.
  - **Sonuç:** Kotlin köprüsü, manifest izinleri vb. native değişiklikler için workflow'a "repodaki hazır dosyaları `android/` içine kopyala" adımı eklenmeli (örneğin `android_overrides/` klasörü). Bu henüz yapılmadı.
- APK build **sadece elle** çalışır (`workflow_dispatch`), her push'ta otomatik build **istenmiyor**. Dosya: `.github/workflows/build.yml`. Çıktı: artifact `EditPro-APK` (zip içinde `app-release.apk`).
- Paketler (`pubspec.yaml`): `image_picker` (telefonun kendi seçicisi, izin gerekmez), `gal` (galeriye kaydetme).

## 5. Dosya yapısı
```
pubspec.yaml
.github/workflows/build.yml
lib/
  main.dart                      MaterialApp, koyu tema, SplashScreen ile başlar
  theme.dart                     AppColors + appGradient (mavi #3B82F6 -> mor #8B5CF6, arka plan #0B1226, kart #16204A)
  filters.dart                   FilterItem + photoFilters (renk matrisi, ~48 filtre, yardımcılarla zincirleniyor)
  screens/
    splash_screen.dart           Açılış, "Başla" -> MainShell
    main_shell.dart              Alt menü: Ana Sayfa / Projeler / Profil (Projeler ve Profil boş yer tutucu)
    home_screen.dart             Banner, 6 kutu, Son Projeler (renkli yer tutucu)
    gallery_screen.dart          Fotoğraflar/Videolar sekmesi, seçici ile seçilenleri ızgarada gösterir
    edit_photo_screen.dart       Fotoğraf düzenleme (aşağıya bak)
AGENTS.md
```

## 6. Neler yapıldı
- Açılış ekranı, Ana Sayfa (banner, 6 kutu, son projeler yer tutucusu), alt menü.
- Galeri: fotoğraf (çoklu) ve video seçme, ızgarada gösterme. Fotoğrafa dokununca düzenleme açılır. Videoya dokununca "Video düzenleme yakında" der.
- Fotoğraf düzenleme: ~48 filtre (Instagram tarzı Clarendon, Gingham, Moon, Lark, Juno, X-Pro II vb. + eski basit olanlar), parlaklık, kontrast, 90° döndürme, kırpma oranları (Orijinal, 1:1, 4:3, 3:4, 16:9, 9:16), **✓ ile telefon galerisine "EditPro" albümüne PNG kaydetme**.
- Build hattı: GitHub Actions ile APK üretimi çalıştı (açılış ve Ana Sayfa ekranı telefonda görüldü).

## 7. Bilinen durum ve eksikler
- **Son sürüm (filtreler, kırp, kaydet, galeri) henüz APK olarak test edilmedi.** Sıradaki ilk iş: build al, hata varsa düzelt.
- Kırpma sadece ortadan, oran seçmeli. Sürükleyerek serbest kırpma yok.
- Kayıt çözünürlüğü ekran boyutuna bağlı (RepaintBoundary, pixelRatio 3), orijinal çözünürlük korunmuyor.
- Filtreler Instagram'ın gizli formüllerinin birebir kopyası değil, renk matrisi ile yapılmış benzerleri.
- Görsel zenginlik düşük: banner'da fotoğraf yok, ikonlar tek renk, proje küçük resimleri düz gradient. Kullanıcı bunu "sonra yaparız" dedi.
- Yapılmayanlar: Video Düzenleme, Yazı Ekle, Dışa Aktar (720p MP4), Projeler, Şablonlar, Profil, Kamera, Metin Ekle (ana sayfa kutusu), proje kaydetme.

## 8. Sıradaki işler (önerilen)
1. Mevcut halde APK build al, fotoğraf akışını telefonda test et, hataları düzelt.
2. Video ekranı: video oynatma (`video_player`), zaman çizelgesi, yazı satırları listesi (metin, başlangıç, bitiş), satıra dokununca videoyu o saniyeye atlatma.
3. Workflow'a native dosya kopyalama adımı ekle, sonra Kotlin + Media3 Transformer köprüsüyle yazıları videoya işle, 720p MP4 dışa aktar.
4. Yazı görünümü kararı ve stil seçenekleri (font, renk, konum).
5. Projeler listesi, Şablonlar, Profil, görsel cilalama.

## 9. Kullanıcıyla çalışma kuralları (önemli)
- Kullanıcı **Türkçe** yazıyor, cevaplar **Türkçe**, **kısa, basit, anlaşılır** olmalı. Uzun yazı sevmiyor.
- Kurulum ve yükleme işleri **tane tane, sıra sıra adım adım** anlatılmalı.
- Telefondan çalışıyor: kodu **indirilebilir dosya olarak** ver. **GitHub linki verme**, sadece dosyanın hangi klasöre (örn. `lib/screens/`) konacağını ve "kalem ile hepsini sil, yapıştır" gibi adımı yaz.
- Yeni dosya için GitHub'da **Add file > Create new file**; isim kutusuna `/` yazınca klasör oluşur. Var olan dosyayı değiştirmek için dosyayı aç, kalem ikonu, hepsini sil, yapıştır, **Commit changes**.
- Performans (donma/kasma yok), animasyon yok, gölge yok kuralı için 10. bölüme bak.
- Büyük kararlarda önce kısaca konuşmak, sonra yapmak istiyor. Kod parçalarının ayrı dosyalarda olmasını (bir ekran bir dosya) tercih ediyor.
- Build hatası olursa kullanıcı hata metnini yapıştırıyor. Genelde eksik yüklenmiş dosya yüzünden oluyor, önce dosya yollarını kontrol et.

## 10. Performans ve tasarım kuralları (zorunlu)
Hedef: telefonda **donma, kasma, takılma (jank) olmasın**. Her yeni kod bu kurallara uymalı.

**Yasaklar**
- **Animasyon yok.** `AnimatedContainer`, `AnimatedOpacity`, `Hero`, sayfa geçiş animasyonu, kayan/solan efekt, Lottie vb. kullanma. Sayfa geçişleri anında olmalı (tema içinde `pageTransitionsTheme` ile animasyonsuz yapılmalı). Dokunma dalgası (ripple/splash) da kapatılmalı (`splashFactory: NoSplash.splashFactory`).
- **Gölge yok.** `BoxShadow`, `elevation`, `Material` gölgesi kullanma. Butonlarda `elevation: 0`. Gradient ve düz renk serbest.
- Ağır efekt yok: `BackdropFilter`/blur, gereksiz `Opacity`, `ShaderMask`, `saveLayer` tetikleyen yapılar.

**Yapılacaklar**
- Mümkün olan her widget `const` olsun.
- Uzun listeler/ızgaralar `ListView.builder` / `GridView.builder` ile tembel yüklensin.
- Resimler `cacheWidth` ile küçültülerek yüklensin (küçük resim için küçük boyut). Büyük fotoğrafı tam boyutta çözme.
- `setState` ile tüm ekranı yeniden çizme. Sık değişen küçük şeyler (kaydırıcı, video süresi) için `ValueNotifier` + `ValueListenableBuilder` veya küçük ayrı widget kullan.
- Ağır işleri (resim işleme, dosya okuma/yazma, videoya yazı gömme) UI iş parçacığında yapma: `compute`/Isolate ya da **native (Kotlin) tarafında** yap. Video dışa aktarma kesinlikle native Media3 ile.
- `RepaintBoundary` sadece gerçekten gereken yerde (şu an sadece kaydetme için).
- Video önizlemede yazıları ayrı katman olarak çiz, her karede tüm ekranı yeniden oluşturma. Satır sayısı onlarca olabilir: yazı listesi tembel olsun, o anki satırı bulmak için sıralı listede ikili arama / son index takibi kullan.

**Dinamik olma**
- Ekran boyutuna uyumlu: sabit piksel yerine `LayoutBuilder`/`MediaQuery`/oranlar, farklı telefon boyutlarında taşma olmasın.
- İçerik koda gömülü sabit değil, listeden üretilsin (filtre, oran, yazı satırı, proje listesi gibi).

**Mevcut kodda bu kurallara aykırı olan yerler (düzeltilecek)**
- `ElevatedButton` varsayılan gölge/animasyon: Ana Sayfa banner butonu ve Galeri alt butonu.
- Varsayılan sayfa geçiş animasyonu ve dokunma dalgası (`main.dart` temasında kapatılmalı).
- `edit_photo_screen.dart`: parlaklık/kontrast kaydırıcısı her harekette tüm ekranı yeniden çiziyor, büyük fotoğrafa renk filtresi uygulanıyor. Önizleme küçük çözünürlükte yapılmalı, kaydırıcı için `ValueNotifier` kullanılmalı. Filtre şeridinde 48 küçük resim var, `cacheWidth` küçük tutulmalı.
- `SnackBar` kısa animasyonlu. Gerekirse sabit bir uyarı yazısı ile değiştirilebilir.

## 11. Performansı etkileyen her şey (ayrıntılı liste)
Amaç: sayfa kendi kendine sürekli yenilenmesin, hiçbir ekranda boşuna iş yapılmasın.

**Sürekli yenilenme (en büyük risk)**
- Kendi kendini yenileyen sayfa/ekran **yok**. `Timer.periodic` + `setState`, sürekli çalışan `Stream`, sonsuz döngü, "polling" kullanma.
- `build()` içinde `setState` çağırma, `build()` içinde ağır hesap yapma, her `build`'de yeni liste/filtre/File/controller/Future oluşturma. Sabit veriler dosyanın üstünde (top-level) ya da `initState`'te bir kez hazırlansın.
- `FutureBuilder`/`StreamBuilder` için Future/Stream'i `build()` içinde oluşturma, state'te bir kez oluştur.
- Sık değişen değer (video süresi, kaydırıcı, ilerleme çubuğu) için **sadece o küçük parçayı** yenile (`ValueNotifier` + `ValueListenableBuilder`). Tüm ekranı `setState` ile yenileme.
- Sürükleme/kaydırma olaylarında her pikselde güncelleme yapma; gerekirse sıklığı sınırla (video süresi yazısı yaklaşık 4 kez/sn yeter).
- Büyük ekranı küçük widget'lara böl, böylece değişen kısım yenilenir, geri kalanı yenilenmez.

**Resim ve filtre**
- Aynı resmi tekrar tekrar çözme (decode) yok: `cacheWidth` sabit ve küçük olsun (önizleme ~1200, küçük resim ~150).
- Üst üste birden fazla `ColorFiltered` kullanma. Filtre ve parlaklık/kontrast matrislerini **çarpıp tek filtre** yap.
- Önizlemeyi düşük çözünürlükte yap, tam çözünürlüğü sadece kaydederken kullan.
- `toImage` sonrası `image.dispose()` çağır. Bellekte büyük bitmap listesi tutma, sadece dosya yolu (path) tut.

**Liste ve ızgara**
- Hepsi `builder` ile tembel olsun. Seçilmiş çok sayıda fotoğraf olabilir.
- Gereksiz `shrinkWrap` + `NeverScrollableScrollPhysics` ile dev listeler yapma (sadece küçük sabit ızgaralar için).

**Video**
- Tek `VideoPlayerController`, ekrandan çıkınca `dispose()`.
- Önizleme düşük kalitede olabilir, yazılar videonun üstünde ayrı katman (`Stack`) olarak çizilsin.
- Dışa aktarma native Media3 ile arka planda, arayüz donmasın. İlerleme gösterimi basit ve animasyonsuz.

**Bellek ve temizlik**
- Her `Controller`, `Timer`, listener, `ScrollController` `dispose()`'ta kapatılsın.
- Ekrandan çıkınca arka planda iş sürmesin.

**Paket ve başlangıç**
- Gereksiz paket ekleme (APK boyutu ve açılış süresi artar). Her yeni paket için gerekçe ve alternatif düşün.
- Açılışta ağır iş yapma.

**Ölçüm**
- Performans testi **release APK** ile yapılır (debug yavaş görünür). Takılma varsa önce hangi widget'ın sürekli yenilendiğine bak.
- Her yeni ekran için kendine sor: "Bu ekran kendi kendine yenileniyor mu? Sürüklerken tüm ekran mı çiziliyor? Büyük resim tekrar tekrar mı çözülüyor?"
