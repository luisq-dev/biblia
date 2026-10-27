import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/state/reading_controller.dart';
import 'package:biblia/ui/favorites/favorites_screen.dart';
import 'package:biblia/ui/reading/reading_screen.dart';
import 'package:biblia/ui/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = <int>{0};

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: <Widget>[
            const ReadingScreen(),
            if (_visitedTabs.contains(1))
              SearchScreen(onOpenReference: _openReference)
            else
              const SizedBox.shrink(),
            if (_visitedTabs.contains(2))
              FavoritesScreen(onOpenReference: _openReference)
            else
              const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            FocusManager.instance.primaryFocus?.unfocus();
            if (_selectedIndex == index) return;
            setState(() {
              _visitedTabs.add(index);
              _selectedIndex = index;
            });
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Lectura',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(Icons.manage_search_rounded),
              label: 'Buscar',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_border_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'Favoritos',
            ),
          ],
        ),
      ),
    );
  }

  void _openReference(BibleReference reference) {
    final ReadingController reading = context.read<ReadingController>();
    if (!reading.openReference(reference)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${reference.chapterLabel} no está disponible en el texto actual.',
          ),
        ),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _selectedIndex = 0);
  }
}
