// lib/game/battle_game.dart
//
// Savaş Arenası (Flame)
// - Üstte rakip can/mana, ortada slotlar, altta oyuncunun eli
// - Kartı parmakla tut, boş slota bırak (mana yetiyorsa yerleşir)
// - "TURU BİTİR" ile kartlar saldırır, sonra bot rakip oynar

import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

// ----------------------------------------------------------------------------
// SABİTLER
// ----------------------------------------------------------------------------
const int kKartSaldiri = 1000;
const int kKartCan = 1500;
const int kKahramanCan = 5000;
const int kOdulAltin = 50;
const int kSlotSayisi = 3;
const int kElBoyutu = 4;

/// Ses çal. Dosya yoksa oyun çökmesin diye hata yutulur.
void _ses(String dosya, {double ses = 0.8}) {
  Future(() async {
    try {
      await FlameAudio.play(dosya, volume: ses);
    } catch (_) {}
  });
}

// ----------------------------------------------------------------------------
// KART VERİSİ
// ----------------------------------------------------------------------------
class CardData {
  final String id;
  final String ad;
  final String dosya; // assets/images/ içindeki dosya
  final int mana;
  const CardData(this.id, this.ad, this.dosya, this.mana);
}

const List<CardData> tumKartlar = [
  CardData('savasci', 'Savaşçı Asker', 'savasci.jpg', 2),
  CardData('okcu', 'Elf Okçu', 'okcu.jpg', 3),
  CardData('suikastci', 'Gölge Suikastçı', 'suikastci.jpg', 3),
  CardData('buyucu', 'Büyücü Ak Sakal', 'buyucu.jpg', 4),
  CardData('ejderha', 'Ateş Ejderhası', 'ejderha.jpg', 5),
];

TextPaint _yazi(double boyut, Color renk) => TextPaint(
      style: TextStyle(
        fontSize: boyut,
        color: renk,
        fontWeight: FontWeight.bold,
        shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
      ),
    );

final TextPaint _manaYazi = _yazi(13, Colors.white);
final TextPaint _canYaziNormal = _yazi(11, Colors.greenAccent);
final TextPaint _canYaziHasarli = _yazi(11, Colors.redAccent);

// ----------------------------------------------------------------------------
// KART BİLEŞENİ (sürüklenebilir)
// ----------------------------------------------------------------------------
class CardComponent extends SpriteComponent
    with DragCallbacks, HasGameReference<BattleGame> {
  CardComponent({
    required this.data,
    required this.isPlayer,
    required Sprite sprite,
    required Vector2 size,
    required Vector2 position,
    this.handIndex = -1,
  }) : super(sprite: sprite, size: size, position: position, priority: 10);

  final CardData data;
  final bool isPlayer;
  final int handIndex;
  Vector2 handPos = Vector2.zero(); // elindeki yeri
  int hp = kKartCan;
  int atk = kKartSaldiri;
  bool placed = false; // masaya konduysa true
  bool _dragging = false;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (placed || !isPlayer) return;
    if (!game.playerTurn || game.busy || game.durdu) return;
    _dragging = true;
    priority = 100;
    scale = Vector2.all(1.1);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_dragging) return;
    position += event.canvasDelta;
    game.slotVurgula(position + size / 2);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _birak();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _birak();
  }

  void _birak() {
    if (!_dragging) return;
    _dragging = false;
    scale = Vector2.all(1);
    priority = 10;
    game.kartiBirak(this);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (placed) {
      // Masadaki kartta güncel can rozeti
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(size.x / 2, size.y - 10),
            width: size.x * 0.7,
            height: 16),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, Paint()..color = const Color(0xCC000000));
      (hp < kKartCan ? _canYaziHasarli : _canYaziNormal).render(
          canvas, 'HP $hp', Vector2(size.x / 2, size.y - 10),
          anchor: Anchor.center);
    } else {
      // Eldeki kartta mana bedeli
      final c = Offset(size.x / 2, 10);
      canvas.drawCircle(c, 11, Paint()..color = const Color(0xFF1E5BFF));
      canvas.drawCircle(
          c,
          11,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white);
      _manaYazi.render(canvas, '${data.mana}', Vector2(c.dx, c.dy),
          anchor: Anchor.center);
    }
  }
}

// ----------------------------------------------------------------------------
// SLOT (masadaki kart yuvası)
// ----------------------------------------------------------------------------
class SlotComponent extends PositionComponent {
  SlotComponent({
    required this.isPlayer,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size, priority: 1);

  final bool isPlayer;
  CardComponent? card;
  bool vurgulu = false;

  bool icerir(Vector2 p) =>
      Rect.fromLTWH(position.x, position.y, size.x, size.y)
          .inflate(14)
          .contains(Offset(p.x, p.y));

  @override
  void render(Canvas canvas) {
    final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(10));
    canvas.drawRRect(
        rr,
        Paint()
          ..color =
              vurgulu ? const Color(0x6600FF66) : const Color(0x33000000));
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = vurgulu
              ? Colors.greenAccent
              : (isPlayer ? const Color(0xFFFFC107) : const Color(0xFFE53935)));
  }
}

// ----------------------------------------------------------------------------
// CAN / MANA ÇUBUĞU
// ----------------------------------------------------------------------------
class BarComponent extends PositionComponent {
  BarComponent({
    required this.etiket,
    required this.renk,
    required this.deger,
    required this.maxDeger,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size, priority: 20);

  final String etiket;
  final Color renk;
  final int Function() deger;
  final int Function() maxDeger;

  @override
  void render(Canvas canvas) {
    final v = max(0, deger());
    final oran = (v / maxDeger()).clamp(0.0, 1.0).toDouble();
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y),
        Radius.circular(size.y / 2));
    canvas.drawRRect(rr, Paint()..color = const Color(0xAA000000));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x * oran, size.y), Paint()..color = renk);
    canvas.restore();
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white54);
    _yazi(size.y * 0.6, Colors.white).render(
        canvas, '$etiket $v/${maxDeger()}', Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center);
  }
}

// ----------------------------------------------------------------------------
// BUTON
// ----------------------------------------------------------------------------
class GameButton extends PositionComponent with TapCallbacks {
  GameButton({
    required this.etiket,
    required this.aktif,
    required this.onBas,
    required Vector2 position,
    required Vector2 size,
    int priority = 50,
  }) : super(position: position, size: size, priority: priority);

  final String Function() etiket;
  final bool Function() aktif;
  final VoidCallback onBas;

  @override
  void onTapDown(TapDownEvent event) {
    if (aktif()) onBas();
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(size.y / 2));
    final renkler = aktif()
        ? const [Color(0xFFFF6F00), Color(0xFFFFC107)]
        : const [Color(0xFF555555), Color(0xFF777777)];
    canvas.drawRRect(
        rr, Paint()..shader = LinearGradient(colors: renkler).createShader(rect));
    _yazi(size.y * 0.4, Colors.black87).render(
        canvas, etiket(), Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center);
  }
}

// ----------------------------------------------------------------------------
// OYUN
// ----------------------------------------------------------------------------
class BattleGame extends FlameGame {
  BattleGame({required this.onGameEnd});

  /// Oyun bitince "MENÜYE DÖN" ile çağrılır (kazandı mı?)
  final void Function(bool kazandi) onGameEnd;

  final Random _rng = Random();
  final Map<String, Sprite> _sprites = {};
  late Vector2 cardSize;

  final List<SlotComponent> oyuncuSlotlari = [];
  final List<SlotComponent> rakipSlotlari = [];
  final List<CardComponent?> el = List.filled(kElBoyutu, null);
  final List<Vector2> elPozisyonlari = [];

  int oyuncuCan = kKahramanCan;
  int rakipCan = kKahramanCan;
  int oyuncuMana = 3;
  int rakipMana = 3;
  int maxMana = 3;

  double _oyuncuBarY = 0;
  bool playerTurn = true;
  bool busy = false;
  bool ended = false;
  bool _kapandi = false;
  bool get durdu => ended || _kapandi;

  @override
  Color backgroundColor() => const Color(0xFF120A24);

  @override
  void onRemove() {
    _kapandi = true;
    super.onRemove();
  }

  @override
  Future<void> onLoad() async {
    // Görselleri yükle
    for (final k in tumKartlar) {
      _sprites[k.id] = Sprite(await images.load(k.dosya));
    }

    // Arka plan (ekranı kaplayacak şekilde ölçekle)
    final bgSprite = Sprite(await images.load('arena.jpg'));
    final img = bgSprite.originalSize;
    final olcek = max(size.x / img.x, size.y / img.y);
    add(SpriteComponent(
      sprite: bgSprite,
      anchor: Anchor.center,
      position: size / 2,
      size: img * olcek,
      priority: -10,
    ));
    add(RectangleComponent(
      size: size.clone(),
      paint: Paint()..color = const Color(0x55000000),
      priority: -9,
    ));

    // Yerleşim
    final w = size.x;
    final h = size.y;
    final kw = w * 0.235;
    cardSize = Vector2(kw, kw * 1376 / 768);

    // Rakip çubukları (üst)
    add(BarComponent(
      etiket: 'RAKİP',
      renk: const Color(0xFFD32F2F),
      deger: () => rakipCan,
      maxDeger: () => kKahramanCan,
      position: Vector2(12, 8),
      size: Vector2(w - 24, 22),
    ));
    add(BarComponent(
      etiket: 'MANA',
      renk: const Color(0xFF1E5BFF),
      deger: () => rakipMana,
      maxDeger: () => 10,
      position: Vector2(12, 36),
      size: Vector2(w - 24, 18),
    ));

    // Slotlar
    final bosluk = w * 0.04;
    final baslaX = (w - (kSlotSayisi * cardSize.x + (kSlotSayisi - 1) * bosluk)) / 2;
    final rakipY = 66.0;
    final bosAlan = h - (rakipY + 3 * cardSize.y + 118);
    final aralik = bosAlan.clamp(24.0, 90.0).toDouble();
    final oyuncuY = rakipY + cardSize.y + aralik;
    for (var i = 0; i < kSlotSayisi; i++) {
      final x = baslaX + i * (cardSize.x + bosluk);
      final rs = SlotComponent(
          isPlayer: false, position: Vector2(x, rakipY), size: cardSize.clone());
      final os = SlotComponent(
          isPlayer: true, position: Vector2(x, oyuncuY), size: cardSize.clone());
      rakipSlotlari.add(rs);
      oyuncuSlotlari.add(os);
      add(rs);
      add(os);
    }

    // Turu bitir butonu
    final butonY = oyuncuY + cardSize.y + 10;
    _oyuncuBarY = butonY + 56;
    add(GameButton(
      etiket: () => (playerTurn && !busy) ? 'TURU BİTİR' : 'RAKİP OYNUYOR...',
      aktif: () => playerTurn && !busy && !ended,
      onBas: turuBitir,
      position: Vector2(w / 2 - 90, butonY),
      size: Vector2(180, 38),
    ));

    // Oyuncu çubukları
    add(BarComponent(
      etiket: 'SEN',
      renk: const Color(0xFF2E7D32),
      deger: () => oyuncuCan,
      maxDeger: () => kKahramanCan,
      position: Vector2(12, butonY + 46),
      size: Vector2(w - 24, 20),
    ));
    add(BarComponent(
      etiket: 'MANA',
      renk: const Color(0xFF1E5BFF),
      deger: () => oyuncuMana,
      maxDeger: () => 10,
      position: Vector2(12, butonY + 70),
      size: Vector2(w - 24, 18),
    ));

    // El pozisyonları
    final elBosluk = (w - kElBoyutu * cardSize.x) / (kElBoyutu + 1);
    final elY = h - cardSize.y - 12;
    for (var i = 0; i < kElBoyutu; i++) {
      elPozisyonlari.add(Vector2(elBosluk + i * (cardSize.x + elBosluk), elY));
    }

    // Başlangıç eli: 3 kart
    for (var i = 0; i < 3; i++) {
      kartCek();
    }
    _afis('SAVAŞ BAŞLIYOR!', Colors.amber);
    _ses('turn.wav', ses: 0.6);
  }

  // --------------------------------------------------------------------------
  // KART ÇEKME
  // --------------------------------------------------------------------------
  void kartCek() {
    final i = el.indexOf(null);
    if (i == -1) return;
    final veri = tumKartlar[_rng.nextInt(tumKartlar.length)];
    final hedef = elPozisyonlari[i].clone();
    final k = CardComponent(
      data: veri,
      isPlayer: true,
      sprite: _sprites[veri.id]!,
      size: cardSize.clone(),
      position: hedef + Vector2(0, 220),
      handIndex: i,
    )..handPos = hedef;
    add(k);
    el[i] = k;
    k.add(MoveToEffect(hedef, EffectController(duration: 0.3, curve: Curves.easeOut)));
    _ses('draw.wav', ses: 0.5);
  }

  // --------------------------------------------------------------------------
  // SÜRÜKLE - BIRAK
  // --------------------------------------------------------------------------
  SlotComponent? _slotBul(Vector2 nokta) {
    for (final s in oyuncuSlotlari) {
      if (s.icerir(nokta)) return s;
    }
    return null;
  }

  void slotVurgula(Vector2 nokta) {
    final hedef = _slotBul(nokta);
    for (final s in oyuncuSlotlari) {
      s.vurgulu = (s == hedef && s.card == null);
    }
  }

  void kartiBirak(CardComponent k) {
    final slot = _slotBul(k.position + k.size / 2);
    if (slot != null && slot.card == null && oyuncuMana >= k.data.mana) {
      oyuncuMana -= k.data.mana;
      el[k.handIndex] = null;
      _yerlestir(k, slot);
    } else {
      // Geçersiz bırakma: ele geri dön
      k.add(MoveToEffect(k.handPos, EffectController(duration: 0.2)));
    }
    for (final s in oyuncuSlotlari) {
      s.vurgulu = false;
    }
  }

  void _yerlestir(CardComponent k, SlotComponent slot) {
    slot.card = k;
    k.placed = true;
    k.priority = 5;
    k.add(MoveToEffect(
      slot.position.clone(),
      EffectController(duration: 0.18, curve: Curves.easeOut),
      onComplete: () {
        if (durdu) return;
        _parcacik(slot.position + Vector2(cardSize.x / 2, cardSize.y),
            const Color(0xFFFFC107),
            adet: 16, hiz: 220);
        k.add(ScaleEffect.to(
            Vector2.all(1.12), EffectController(duration: 0.08, alternate: true)));
        _ses('place.wav');
      },
    ));
  }

  // --------------------------------------------------------------------------
  // TUR AKIŞI
  // --------------------------------------------------------------------------
  Future<void> turuBitir() async {
    if (!playerTurn || busy || durdu) return;
    busy = true;
    playerTurn = false;

    await _saldiriFazi(oyuncuSlotlari, rakipSlotlari, true);
    if (durdu) return;
    _afis('RAKİBİN SIRASI', Colors.redAccent);
    await Future.delayed(const Duration(milliseconds: 900));

    await _rakipOyna();
    if (durdu) return;
    await _saldiriFazi(rakipSlotlari, oyuncuSlotlari, false);
    if (durdu) return;

    // Yeni tur
    maxMana = min(10, maxMana + 1);
    oyuncuMana = maxMana;
    rakipMana = maxMana;
    kartCek();
    _afis('SENİN SIRAN', Colors.amber);
    _ses('turn.wav', ses: 0.6);
    playerTurn = true;
    busy = false;
  }

  Future<void> _saldiriFazi(List<SlotComponent> saldiran,
      List<SlotComponent> savunan, bool oyuncu) async {
    for (var i = 0; i < saldiran.length; i++) {
      if (durdu) return;
      final a = saldiran[i].card;
      if (a == null) continue;

      // Saldırı: kart öne atılır, geri döner
      a.priority = 90;
      a.add(MoveByEffect(
          Vector2(0, oyuncu ? -44 : 44),
          EffectController(
              duration: 0.14, alternate: true, curve: Curves.easeIn)));
      await Future.delayed(const Duration(milliseconds: 150));
      if (durdu) return;

      final d = savunan[i].card;
      if (d != null) {
        d.hp -= a.atk;
        final merkez = d.position + d.size / 2;
        _vurusEfekti(merkez, d);
        _hasarYazisi(merkez, a.atk);
        if (d.hp <= 0) {
          savunan[i].card = null;
          _parcacik(merkez, Colors.white, adet: 26, hiz: 380);
          d.add(OpacityEffect.fadeOut(EffectController(duration: 0.25)));
          d.add(RemoveEffect(delay: 0.3));
        }
      } else {
        if (oyuncu) {
          rakipCan -= a.atk;
        } else {
          oyuncuCan -= a.atk;
        }
        final hedef = Vector2(size.x / 2, oyuncu ? 30 : _oyuncuBarY);
        _parcacik(hedef, Colors.redAccent, adet: 22, hiz: 340);
        _ses('hit.wav');
        if (!oyuncu) _kirmiziFlas();
        _hasarYazisi(hedef, a.atk);
        if (_bittiMi()) return;
      }
      await Future.delayed(const Duration(milliseconds: 350));
      a.priority = 5;
    }
  }

  // Bot rakip: mana yettiği sürece rastgele kart oynar
  Future<void> _rakipOyna() async {
    while (!durdu) {
      final bos = rakipSlotlari.where((s) => s.card == null).toList();
      final uygun = tumKartlar.where((k) => k.mana <= rakipMana).toList();
      if (bos.isEmpty || uygun.isEmpty) break;

      final veri = uygun[_rng.nextInt(uygun.length)];
      final slot = bos[_rng.nextInt(bos.length)];
      rakipMana -= veri.mana;

      final k = CardComponent(
        data: veri,
        isPlayer: false,
        sprite: _sprites[veri.id]!,
        size: cardSize.clone(),
        position: slot.position - Vector2(0, 160),
      );
      add(k);
      _yerlestir(k, slot);
      await Future.delayed(const Duration(milliseconds: 450));
    }
  }

  // --------------------------------------------------------------------------
  // YARDIMCI
  // --------------------------------------------------------------------------
  void _hasarYazisi(Vector2 konum, int miktar) {
    final t = TextComponent(
      text: '-$miktar',
      anchor: Anchor.center,
      position: konum,
      priority: 150,
      scale: Vector2.all(0.5),
      textRenderer: _yazi(30, Colors.redAccent),
    );
    add(t);
    t.add(ScaleEffect.to(Vector2.all(1.3),
        EffectController(duration: 0.15, curve: Curves.easeOutBack)));
    t.add(MoveByEffect(Vector2(0, -50), EffectController(duration: 0.8)));
    t.add(RemoveEffect(delay: 0.8));
  }

  // Kartın vurulma efekti: kırmızı parlama, sarsılma, kıvılcım
  void _vurusEfekti(Vector2 merkez, CardComponent d) {
    _parcacik(merkez, const Color(0xFFFF9800), adet: 20, hiz: 320);
    _ses('hit.wav');
    d.add(ColorEffect(Colors.red,
        EffectController(duration: 0.1, alternate: true),
        opacityTo: 0.7));
    d.add(MoveByEffect(Vector2(7, 0),
        EffectController(duration: 0.04, alternate: true, repeatCount: 3)));
  }

  // Kıvılcım / toz parçacıkları
  void _parcacik(Vector2 konum, Color renk,
      {int adet = 18, double hiz = 260, int oncelik = 120}) {
    add(ParticleSystemComponent(
      position: konum,
      priority: oncelik,
      particle: Particle.generate(
        count: adet,
        lifespan: 0.6,
        generator: (i) => AcceleratedParticle(
          acceleration: Vector2(0, 260),
          speed: Vector2((_rng.nextDouble() - 0.5) * hiz,
              -_rng.nextDouble() * hiz),
          child: CircleParticle(
            radius: 2 + _rng.nextDouble() * 3,
            paint: Paint()..color = renk,
          ),
        ),
      ),
    ));
  }

  // Ekran kırmızıya flaşlar (oyuncu hasar alınca)
  void _kirmiziFlas() {
    final f = RectangleComponent(
      size: size.clone(),
      paint: Paint()..color = const Color(0x55FF0000),
      priority: 180,
    );
    add(f);
    f.add(OpacityEffect.fadeOut(EffectController(duration: 0.35)));
    f.add(RemoveEffect(delay: 0.4));
  }

  // Ortada büyüyerek çıkan duyuru yazısı
  void _afis(String metin, Color renk) {
    final t = TextComponent(
      text: metin,
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y * 0.45),
      priority: 190,
      scale: Vector2.all(0.3),
      textRenderer: _yazi(34, renk),
    );
    add(t);
    t.add(ScaleEffect.to(Vector2.all(1.0),
        EffectController(duration: 0.25, curve: Curves.easeOutBack)));
    t.add(RemoveEffect(delay: 1.0));
  }

  bool _bittiMi() {
    if (rakipCan <= 0) {
      rakipCan = 0;
      _bitir(true);
      return true;
    }
    if (oyuncuCan <= 0) {
      oyuncuCan = 0;
      _bitir(false);
      return true;
    }
    return false;
  }

  void _bitir(bool kazandi) {
    if (ended) return;
    ended = true;
    _ses(kazandi ? 'win.wav' : 'lose.wav');
    if (kazandi) {
      for (var j = 0; j < 5; j++) {
        _parcacik(Vector2(size.x * (0.1 + 0.2 * j), size.y * 0.3), Colors.amber,
            adet: 30, hiz: 500, oncelik: 210);
      }
    }
    add(RectangleComponent(
      size: size.clone(),
      paint: Paint()..color = const Color(0xCC000000),
      priority: 200,
    ));
    add(TextComponent(
      text: kazandi ? 'KAZANDIN!' : 'KAYBETTİN',
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y * 0.38),
      priority: 201,
      textRenderer:
          _yazi(40, kazandi ? Colors.amber : Colors.redAccent),
    ));
    if (kazandi) {
      add(TextComponent(
        text: '+$kOdulAltin altın',
        anchor: Anchor.center,
        position: Vector2(size.x / 2, size.y * 0.46),
        priority: 201,
        textRenderer: _yazi(24, Colors.white),
      ));
    }
    add(GameButton(
      etiket: () => 'MENÜYE DÖN',
      aktif: () => true,
      onBas: () => onGameEnd(kazandi),
      position: Vector2(size.x / 2 - 100, size.y * 0.55),
      size: Vector2(200, 52),
      priority: 202,
    ));
  }
}
