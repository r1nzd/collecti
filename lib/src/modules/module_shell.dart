import 'package:flutter/material.dart';
import '../common/module_placeholder.dart';
import 'collecti_module.dart';
import 'home/home_page.dart';
import 'table/table_page.dart';

class ModuleShell extends StatelessWidget {
  const ModuleShell({
    super.key,
    required this.module,
    required this.openPath,
    required this.onOpen,
    required this.onClose,
  });

  final CollectiModule module;
  final String? openPath;
  final void Function(String path) onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final path = openPath;
    if (path == null) {
      return HomePage(
        lockedExt: module.extension,
        onOpenModule: (_) {},
        onOpenDocument: (_, p) => onOpen(p),
      );
    }

    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Quay lại',
                onPressed: onClose,
              ),
              const SizedBox(width: 4),
              Text(module.label, style: theme.textTheme.titleLarge),
            ],
          ),
        ),
        Expanded(child: _editor(path)),
      ],
    );
  }

  Widget _editor(String path) {
    if (module == CollectiModule.table) {
      return TablePage(key: ValueKey(path), filePath: path);
    }
    return ModulePlaceholder(module);
  }
}