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
- **Güncelleme (ikon):** `build.yml` içine "Uygulama ikonunu yap" adımı eklendi. `flutter create`'ten sonra `assets/logo.png` dosyasını ImageMagick `convert` ile 48/72/96/144/192 px'e küçültüp `android/app/src/main/res/mipmap-*/ic_launcher.png` olarak yazıyor. Yani telefon ikonu otomatik logo oluyor. (`android_overrides/` yöntemi hâlâ yapılmadı, Kotlin köprüsü için gerekecek.)
- **Görseller (`assets/`):** `pubspec.yaml` içinde `flutter: assets: - assets/` tanımlı. Klasörde 11 dosya olmalı: `logo.png`, `banner.jpg`, `proje1.jpg`, `proje2.jpg`, `proje3.jpg`, `ikon_foto.png`, `ikon_video.png`, `ikon_metin.png`, `ikon_sablon.png`, `ikon_kamera.png`, `ikon_galeri.png`. Hepsi Gemini ile üretildi, sonra Python ile küçültüldü (logo 512px, ikonlar 160px, banner 1000px, proje resimleri 480x596). **Bu dosyalar yüklenmeden build alınırsa hata verir** (asset bulunamadı).
- **GitHub bilgisi:** kullanıcı adı `ganyansosyal`, repo `fotoproje`. Klasör oluşturma: `https://github.com/ganyansosyal/fotoproje/new/main/assets` (dosya adı `yer.txt`). Görsel yükleme: `https://github.com/ganyansosyal/fotoproje/upload/main/assets`.

## 5. Dosya yapısı
```
pubspec.yaml                     assets/ tanımlı
.github/workflows/build.yml      APK build + ikon adımı
assets/                          logo, banner, proje1-3, ikon_* (bkz. bölüm 4)
lib/
  main.dart                      MaterialApp, koyu tema, SplashScreen ile başlar
  theme.dart                     AppColors + appGradient (mavi #3B82F6 -> mor #8B5CF6, arka plan #0B1226, kart #16204A)
  filters.dart                   FilterItem + photoFilters (renk matrisi, ~48 filtre)
  screens/
    splash_screen.dart           Açılış, assets/logo.png, "Başla" -> MainShell
    main_shell.dart              Alt menü: Ana Sayfa / Projeler / Profil (Projeler ve Profil boş yer tutucu)
    home_screen.dart             Fotoğraflı banner, 6 kutu (ikon_*.png), Son Projeler (proje1-3.jpg)
    gallery_screen.dart          Tasarıma uygun Galeri (bkz. bölüm 6)
    edit_photo_screen.dart       Fotoğraf düzenleme (bkz. bölüm 6)
AGENTS.md
```
**Not:** `lib/screens/theme.dart` ile `lib/theme.dart` aynı boyutta, büyük ihtimalle kopya. `lib/screens/theme.dart` kullanılmıyorsa silinebilir (önce import'lara bak).

## 6. Neler yapıldı
- Açılış ekranı (yeni logo ile), Ana Sayfa, alt menü.
- **Ana Sayfa:** banner artık fotoğraflı (sağda foto, solda mor gradient, resim üstüne yarı saydam gradient katmanı, `ShaderMask` yok). 6 kutunun ikonları Gemini ile yapılmış renkli gradient PNG'ler (`ikon_*.png`, 48px gösterilir). Son Projeler küçük resimleri `proje1-3.jpg` + alt karartma gradient + süre yazısı. Banner butonu `elevation: 0`.
- **Galeri (tasarımdaki 9. ekrana benzetildi):** sola yaslı kalın "Galeri" başlığı, seçili sekme mavi-mor gradient, seçilmeyen koyu kart, 3 sütun fotoğraf ızgarası (`cacheWidth: 300`), boş durumda ikonlu yazı, video kutusunda oynat ikonu + dosya adı, alttaki seç butonu gradient (`GestureDetector`, gölge ve dalga yok). Fotoğrafa dokununca düzenleme açılır, videoya dokununca "Video düzenleme yakında".
- **Fotoğraf düzenleme (`edit_photo_screen.dart`, yeni sürüm):**
  - Filtre şeridi (eski ~48 renk matrisi filtresi, hâlâ geçerli).
  - **Ayarlar:** Parlaklık, Kontrast, Doygunluk, Sıcaklık, Vinyet. Hepsi -100..+100 (Vinyet 0..100). Sağda sayı görünür, ortada beyaz çizgi 0 noktasını gösterir, 0'a yaklaşınca yapışır, sayıya dokununca o ayar sıfırlanır. Tüm ayarlar `_Adj` sınıfında, `ValueNotifier<_Adj>` ile sadece canvas yenilenir. Filtre + ayarlar **tek renk matrisinde** birleşir (`_matrix`).
  - **Portre (arka plan bulanıklığı):** fotoğrafa dokun/sürükle ile odak noktası, "Bulanıklık" ve "Odak alanı" kaydırıcıları. Altta bulanık kopya (`ImageFiltered`, `cacheWidth: 600`), üstte keskin kopya (`ShaderMask` + `RadialGradient`, dstIn). **Kişiyi otomatik tanımıyor**, odak elle seçiliyor. Bu, bölüm 10'daki "blur yok" kuralının kullanıcı isteğiyle tek istisnası.
  - **Kırpma:** Orijinal, **Serbest**, 1:1, 4:3, 3:4, 16:9, 9:16. Kırp sekmesinde fotoğraf üstünde çerçeve çıkar: köşe noktalarından boyutlandırma, içinden sürükleyerek taşıma. Oranlı seçeneklerde çerçeve oranı korur. Kırpma normalize `Rect` (`_cropN`) olarak tutulur, kırp sekmesinden çıkınca fotoğraf kırpılmış hâliyle büyük gösterilir. Döndürünce kırpma sıfırlanır. Fotoğrafın en/boy oranı `initState`'te `ResizeImage` ile okunur.
  - Döndür (90°), **Sıfırla** butonu (ayarlar + filtre + kırpma + döndürme hepsini sıfırlar), ✓ ile "EditPro" albümüne PNG kaydetme (`image.dispose()` çağrılır, kırp sekmesindeyken kaydedilirse önce normal görünüme geçer).
- Build hattı: GitHub Actions ile APK üretimi çalıştı (açılış ve Ana Sayfa ekranı telefonda görüldü).

## 7. Bilinen durum ve eksikler
- **Test edilmedi:** yeni `edit_photo_screen.dart` (kaydırıcılar, Portre, Serbest kırpma, Sıfırla), yeni `gallery_screen.dart`, `home_screen.dart`, `splash_screen.dart`, `build.yml` ikon adımı. Bu ortamda Flutter/Dart yok, kodlar derlenerek denenemedi. Kullanıcıdan son görülen ekran görüntüleri hâlâ eski sürümdü (kırp şeridinde 4 buton). Sıradaki ilk iş: `assets/` dosyalarını yüklet, hepsini commit ettir, APK build al, hata varsa metni iste ve düzelt.
- Portre bulanıklığı elle odaklı. Gerçek portre modu için Google ML Kit selfie segmentation paketi (`google_mlkit_selfie_segmentation`) gerekir, istenirse sonra eklenir (yeni paket, native bağımlılık).
- Kayıt çözünürlüğü ekran boyutuna bağlı (RepaintBoundary, pixelRatio 3), kırpılmış fotoğrafta keskin katman `cacheWidth` en fazla 3000. Orijinal çözünürlük tam korunmuyor.
- Filtreler Instagram'ın gizli formüllerinin kopyası değil, renk matrisi ile yapılmış benzerleri.
- **İptal edilen iş:** "kaliteli/Instagram gibi" LUT filtre işi. Python ile 24 filtre (Clarendon, Gingham, Moon, Lark, Reyes, Juno, Slumber, Crema, Aden, Perpetua, Amaro, Mayfair, Rise, Hudson, Valencia, X-Pro II, Sierra, Willow, Lo-Fi, Earlybird, Inkwell, Nashville, 1977) önizlemesi hazırlandı ama kullanıcı "iptal" dedi, koda **hiçbiri bağlanmadı**. Eski filtreler duruyor. Tekrar istenirse yol: eğri tabanlı LUT PNG üretip Flutter fragment shader ile uygulamak (`flutter: shaders:`), kenar karartma ayrı katman.
- Yapılmayanlar: Video Düzenleme, Yazı Ekle, Dışa Aktar (720p MP4), Projeler, Şablonlar, Profil, Kamera, Metin Ekle (ana sayfa kutusu), "Yeni Proje Oluştur" butonu, Son Projeler gerçek veri (şu an sabit resim), proje kaydetme, Galeri ekranında alt menü.

## 8. Sıradaki işler (önerilen)
1. `assets/` (11 dosya) + güncel kod dosyalarını yükle, APK build al, fotoğraf akışını (filtre, ayarlar, Portre, Serbest kırpma, kaydet) telefonda test et, hataları düzelt.
2. Video ekranı: video oynatma (`video_player`), zaman çizelgesi, yazı satırları listesi (metin, başlangıç, bitiş), satıra dokununca videoyu o saniyeye atlatma.
3. Workflow'a native dosya kopyalama adımı (`android_overrides/`) ekle, sonra Kotlin + Media3 Transformer köprüsüyle yazıları videoya işle, 720p MP4 dışa aktar.
4. Yazı görünümü kararı ve stil seçenekleri (font, renk, konum).
5. Projeler listesi, Şablonlar, Profil, diğer ekranları tasarıma benzetme (Efektler ve Filtreler, Fotoğraf Düzenleme görünümü vb.), görsel cilalama.
6. İsteğe bağlı: gerçek portre (ML Kit), kaliteli LUT filtreler.

## 9. Kullanıcıyla çalışma kuralları (önemli)
- Kullanıcı **Türkçe** yazıyor, cevaplar **Türkçe**, **kısa, basit, anlaşılır** olmalı. Uzun yazı sevmiyor.
- Kurulum ve yükleme işleri **tane tane, sıra sıra adım adım** anlatılmalı.
- Telefondan çalışıyor: kodu **indirilebilir dosya olarak** ver ve dosyanın hangi klasöre (örn. `lib/screens/`) konacağını, "kalem ile hepsini sil, yapıştır, Commit changes" adımını yaz. Kullanıcı istediği için artık **doğrudan GitHub linki de verilebilir** (kullanıcı adı `ganyansosyal`, repo `fotoproje`, bkz. bölüm 4). Cevaplar çok kısa olsun, gerekirse kopyalanabilir kod bloğu kullan.
- Görsel gerekirse kullanıcı **Gemini** ile üretiyor: sen kısa İngilizce istem (prompt) yaz ("no text, no shadow" ekle), gelen görselleri sen Python ile küçültüp `assets/` için hazırla. Görsel dosyalar GitHub'a **Add file > Upload files** ile yüklenir (Create new file ile olmaz).
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
- Varsayılan sayfa geçiş animasyonu ve dokunma dalgası (`main.dart` temasında hâlâ kapatılmadı: `pageTransitionsTheme` ve `splashFactory: NoSplash.splashFactory`). Ana Sayfa kutularındaki `InkWell` dalga veriyor.
- `SnackBar` kısa animasyonlu. Gerekirse sabit bir uyarı yazısı ile değiştirilebilir.
- Düzeltilenler: Ana Sayfa ve Galeri butonları (gölgesiz), `edit_photo_screen.dart` kaydırıcıları artık `ValueNotifier` ile sadece canvas'ı yeniliyor, filtre + ayar tek matris, filtre şeridi `cacheWidth: 150`.
- Bilinçli istisna: Portre bulanıklığı (`ImageFiltered` + `ShaderMask`), kullanıcı istedi. Takılma olursa bulanık katman `cacheWidth` değerini düşür ya da sigma üst sınırını azalt.

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
