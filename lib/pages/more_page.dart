import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/router.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: AuthService.user,
            builder: (c, u, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline, color: kAccent),
                title: Text(u ?? ''),
                trailing: TextButton(
                  onPressed: () async {
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
                  },
                  child: const Text('Çıkış', style: TextStyle(color: kDown)),
                ),
              ),
            ),
          ),
          for (final e in modules.entries)
            Card(
              child: ListTile(
                title: Text(e.value),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/${e.key}'),
              ),
            ),
        ],
      );
}
