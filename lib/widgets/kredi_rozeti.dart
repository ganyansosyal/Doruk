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
