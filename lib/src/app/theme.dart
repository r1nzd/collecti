import 'package:flutter/material.dart';

const _seed = Color(0xFF3F6FE0);

ThemeData collectiTheme(Brightness b) => ThemeData(
      useMaterial3: true,
      fontFamily: 'GoogleSansFlex',
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: b),
    );