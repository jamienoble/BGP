import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's fonts plus Roboto and Material Icons from the Flutter
/// SDK, so tests render real text instead of the blocky test font.
Future<void> loadAppFonts() async {
  Future<void> family(String name, List<String> assets) async {
    final loader = FontLoader(name);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  await family('Inter', [
    for (final w in [400, 500, 600, 700]) 'assets/fonts/Inter-$w.ttf',
  ]);
  await family('Fraunces', [
    for (final w in [500, 600]) 'assets/fonts/Fraunces-$w.ttf',
  ]);

  // Roboto and Material Icons ship with the Flutter SDK
  final sdk = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  final fonts = '$sdk/bin/cache/artifacts/material_fonts';
  Future<ByteData> file(String name) async =>
      ByteData.sublistView(File('$fonts/$name').readAsBytesSync());
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(file('Roboto-$w.ttf'));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(file('MaterialIcons-Regular.otf'))).load();
}

