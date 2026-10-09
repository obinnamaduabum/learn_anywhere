import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render launcher artwork', (tester) async {
    final font = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Center(child: RepaintBoundary(
      key: key,
      child: Container(width: 108, height: 108, color: const Color(0xFFE6F4EE),
        child: const Stack(alignment: Alignment.center, children: [
          Icon(Icons.menu_book_rounded, size: 64, color: Color(0xFF087F77)),
          Positioned(right: 9, bottom: 9, child: Icon(Icons.offline_bolt_rounded,
            color: Color(0xFF075E57), size: 25)),
        ])),
    ))));
    await tester.pumpAndSettle();
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final folder = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final manifest = jsonDecode(File('$folder/Contents.json').readAsStringSync()) as Map;
    final sizes = <String,int>{};
    for (final item in manifest['images'] as List) {
      sizes['$folder/${item['filename']}'] =
        (double.parse((item['size'] as String).split('x').first) *
         double.parse((item['scale'] as String).replaceAll('x', ''))).round();
    }
    for (final item in {'mdpi':48,'hdpi':72,'xhdpi':96,'xxhdpi':144,'xxxhdpi':192}.entries) {
      sizes['android/app/src/main/res/mipmap-${item.key}/ic_launcher.png'] = item.value;
    }
    await tester.runAsync(() async {
      for (final entry in sizes.entries) {
        final image = await boundary.toImage(pixelRatio: entry.value / 108);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(entry.key).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }
    });
  });
}
