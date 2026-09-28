import 'package:flutter/material.dart';
import '../modules/collecti_module.dart';

class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder(this.module, {super.key});
  final CollectiModule module;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(module.selectedIcon, size: 72, color: t.colorScheme.primary),
        const SizedBox(height: 16),
        Text(module.label, style: t.textTheme.headlineMedium),
        Text('.${module.extension}', style: t.textTheme.bodyLarge),
      ]),
    );
  }
}
