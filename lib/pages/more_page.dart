import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/router.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
