import 'package:flutter/material.dart';
import '../modules/collecti_module.dart';
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
  static const _mods = CollectiModule.values;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final body = IndexedStack(index: _index, children: [for (final m in _mods) m.page]);
    return Scaffold(
      body: wide
          ? Row(children: [
              NavigationRail(
                selectedIndex: _index,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final m in _mods)
                    NavigationRailDestination(
                        icon: Icon(m.icon), selectedIcon: Icon(m.selectedIcon), label: Text(m.label)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final m in _mods)
                  NavigationDestination(icon: Icon(m.icon), selectedIcon: Icon(m.selectedIcon), label: m.label),
              ],
            ),
    );
  }
}
