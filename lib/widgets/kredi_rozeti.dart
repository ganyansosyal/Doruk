import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/credit_service.dart';

/// Üst şerit: 💎 kredi sayısı + (varsa) günlük hediye butonu + misafir etiketi
class KrediSeridi extends StatelessWidget {
  const KrediSeridi({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        ValueListenableBuilder<bool>(
          valueListenable: AuthService.misafir,
          builder: (c, m, _) => m
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kTextDim.withOpacity(0.5)),
                  ),
                  child: const Text('MİSAFİR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: kTextDim)),
                )
              : const SizedBox.shrink(),
        ),
        const Spacer(),
        ValueListenableBuilder<bool>(
          valueListenable: CreditService.hediyeHazir,
          builder: (c, hazir, _) => hazir
              ? IconButton(
                  tooltip: 'Günlük hediye',
                  onPressed: () => hediyeDialogu(context),
                  icon: const Text('🎁', style: TextStyle(fontSize: 20)),
                )
              : const SizedBox.shrink(),
        ),
        ValueListenableBuilder<int>(
          valueListenable: CreditService.kredi,
          builder: (c, k, _) => Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('💎', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text('$k', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kAccent)),
          ]),
        ),
      ]),
    );
  }
}

Future<void> hediyeDialogu(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (d) {
      var busy = false;
      return StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('🎁 Günlük Hediye', textAlign: TextAlign.center),
          content: const Text('Bugünkü hediyen hazır: +10 kredi', textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(d), child: const Text('Sonra')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setS(() => busy = true);
                      final err = await CreditService.hediyeAl();
                      if (!d.mounted) return;
                      Navigator.pop(d);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(err ?? '🎁 +10 kredi hesabına eklendi!'),
                        backgroundColor: err == null ? const Color(0xFFB45309) : kDown,
                      ));
                    },
              child: const Text('🎉 HEDİYEYİ AL'),
            ),
          ],
        ),
      );
    },
  );
}

/// Ana sayfanın üst başlığı: kullanıcı adı + OTURUMU KAPAT | DORUK | 🎁 + 💎 kredi
class AnaBaslik extends StatelessWidget {
  const AnaBaslik({super.key});

  Future<void> _cikis(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Çıkış yap?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Çıkış')),
        ],
      ),
    );
    if (ok == true) AuthService.cikis();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kAccent.withOpacity(0.12)))),
      child: Row(children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ValueListenableBuilder<String?>(
              valueListenable: AuthService.user,
              builder: (c, u, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kAccent)),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _cikis(context),
                    child: const Text('OTURUMU KAPAT',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2, color: kTextDim)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Text('DORUK', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 6, color: kAccent)),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ValueListenableBuilder<bool>(
                valueListenable: CreditService.hediyeHazir,
                builder: (c, hazir, _) => hazir
                    ? GestureDetector(
                        onTap: () => hediyeDialogu(context),
                        child: const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Text('🎁', style: TextStyle(fontSize: 30)),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              ValueListenableBuilder<int>(
                valueListenable: CreditService.kredi,
                builder: (c, k, _) => Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('💎', style: TextStyle(fontSize: 22, height: 1)),
                  Text('$k', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kAccent, height: 1.2)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Sağ altta sabit "Sohbet" butonu (sohbet sayfası Faz 4'te gelecek)
class SohbetButonu extends StatelessWidget {
  const SohbetButonu({super.key});
  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('💬 Sohbet yakında (Faz 4)')),
        ),
        backgroundColor: const Color(0xFF0B5FA5),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: kAccent, width: 1),
        ),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Sohbet', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
      );
}
