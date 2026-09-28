import 'package:flutter/material.dart';
import 'src/app/app.dart';
import 'src/bridge/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const CollectiApp());
}
