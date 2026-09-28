import 'package:flutter/material.dart';

// Material 3. Khi Flutter stable hỗ trợ đầy đủ M3 Expressive sẽ nâng cấp tại đây.
const _seed = Color(0xFF3F6FE0);

ThemeData collectiTheme(Brightness b) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: b),
    );
