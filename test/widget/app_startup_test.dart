import 'dart:async';

import 'package:biblia/ui/startup/app_startup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _reading = MaterialApp(home: Scaffold(body: Text('Lectura preparada')));

void main() {
  testWidgets('muestra la lectura inmediatamente y permite interactuar', (
    tester,
  ) async {
    final ready = Completer<Widget>();
    var taps = 0;
    await tester.pumpWidget(AppStartup(loadApplication: () => ready.future));
    expect(tester.binding.hasScheduledFrame, isFalse);

    ready.complete(
      MaterialApp(
        home: Scaffold(
          body: TextButton(
            onPressed: () => taps++,
            child: const Text('Lectura preparada'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Lectura preparada'), findsOneWidget);
    await tester.tap(find.text('Lectura preparada'));
    expect(taps, 1);
  });

  testWidgets('no vuelve a cargar al regresar del segundo plano', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      AppStartup(
        loadApplication: () async {
          loads++;
          return _reading;
        },
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(find.text('Lectura preparada'), findsOneWidget);
  });

  testWidgets('puede reintentar si falla la preparación', (tester) async {
    var loads = 0;
    await tester.pumpWidget(
      AppStartup(
        loadApplication: () async {
          if (++loads == 1) throw StateError('fallo simulado');
          return _reading;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No se pudo abrir la biblioteca.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(find.text('Lectura preparada'), findsOneWidget);
  });
}
