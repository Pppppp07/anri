// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anri/main.dart';
import 'package:anri/pages/login_page.dart'; // Import halaman login sebagai halaman awal palsu

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // --- [PERBAIKAN DI SINI] ---
    // Sekarang kita memberikan widget LoginPage() sebagai halaman awal
    // untuk memenuhi persyaratan parameter `initialPage`.
    await tester.pumpWidget(const MyApp(
      initialPage: LoginPage(), // Anda bisa gunakan halaman apa pun di sini
    ));

    // Kode pengujian di bawah ini adalah contoh bawaan Flutter.
    // Anda bisa membiarkannya atau menghapusnya jika tidak relevan.
    
    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}