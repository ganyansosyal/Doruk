import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/credit_service.dart';

/// Korumalı bir sayfa açılırken 1 kredi düşer; kredi yoksa uyarı gösterir.
/// Web'deki goToPage → _misafirKorunanlar mantığının karşılığı.
class KrediKapisi extends StatefulWidget {
  final String sayfa;
  final Widget Function() builder;
  const KrediKapisi({super.key, required this.sayfa, required this.builder});

  @override
  State<KrediKapisi> createState() => _KrediKapisiState();
}

class _KrediKapisiState extends State<KrediKapisi> {
  // null = kontrol ediliyor, true = geçti, false = kredi yok
  bool? _izin;

  @override
  void initState() {
    super.initState();
    if (!CreditService.korunanlar.contains(widget.sayfa)) {
      _izin = true;
    } else {
      CreditService.harca().then((ok) {
        if (mounted) setState(() => _izin = ok);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_izin == null) return const Center(child: CircularProgressIndicator());
    if (_izin == true) return widget.builder();

    final misafir = AuthService.misafir.value;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('💎', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            misafir
                ? '25 misafir krediniz doldu.\n\nKayıt olun, 200 kredi kazanın ve tüm modüllere erişmeye devam edin.'
                : 'Krediniz doldu.\n\nHer gün giriş yaparak 10 kredi kazanabilirsin.\nYarın tekrar bekleriz! 🎁',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kText, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (misafir)
            FilledButton(onPressed: AuthService.misafirdenKayda, child: const Text('KAYIT OL')),
        ]),
      ),
    );
  }
}
