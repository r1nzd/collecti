import 'package:flutter/material.dart';
import '../modules/collecti_module.dart';
import '../modules/home/home_page.dart';
import '../modules/module_shell.dart';
import 'theme.dart';

class CollectiApp extends StatelessWidget {
  const CollectiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Collecti',
        debugShowCheckedModeBanner: false,
        theme: collectiTheme(Brightness.light),
        darkTheme: collectiTheme(Brightness.dark),
        home: const HomeShell(),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _expanded = false;
  final Map<CollectiModule, String?> _openPaths = {};

  static const _mods = CollectiModule.values;

  void _openModule(CollectiModule module) {
    setState(() => _index = module.index + 1);
  }

  void _openDocument(CollectiModule module, String path) {
    setState(() {
      _openPaths[module] = path;
      _index = module.index + 1;
    });
  }

  void _closeDocument(CollectiModule module) {
    setState(() => _openPaths[module] = null);
  }

  void _select(int i) {
    setState(() {
      if (i == _index && i > 0) {
        _openPaths[_mods[i - 1]] = null;
      }
      _index = i;
      _expanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pages = <Widget>[
      HomePage(onOpenModule: _openModule, onOpenDocument: _openDocument),
      for (final m in _mods)
        ModuleShell(
          module: m,
          openPath: _openPaths[m],
          onOpen: (path) => _openDocument(m, path),
          onClose: () => _closeDocument(m),
        ),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: _expanded,
            minWidth: 96,
            minExtendedWidth: 220,
            backgroundColor: scheme.surfaceContainer,
            selectedIndex: _index,
            labelType: _expanded ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            onDestinationSelected: _select,
            leading: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: IconButton(
                icon: Icon(_expanded ? Icons.menu_open : Icons.menu),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ),
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Home'),
              ),
              for (final m in _mods)
                NavigationRailDestination(
                  icon: Icon(m.icon),
                  selectedIcon: Icon(m.selectedIcon),
                  label: Text(m.label),
                ),
            ],
          ),
          Expanded(child: IndexedStack(index: _index, children: pages)),
        ],
      ),
    );
  }
}