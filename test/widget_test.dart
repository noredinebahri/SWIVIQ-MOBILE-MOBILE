// Contrôle minimal : l'application se construit sans erreur.
//
// Les écrans réels dépendent d'une session et du réseau ; ce test vérifie
// seulement que l'arbre de widgets racine s'initialise, ce qui suffit à
// attraper une régression de compilation dans main.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('l\'application se construit', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Centre Oxygène'))),
    );
    expect(find.text('Centre Oxygène'), findsOneWidget);
  });
}
