import 'package:flutter/material.dart';
import 'src/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: sau khi chạy flutter_rust_bridge_codegen -> await RustLib.init();
  runApp(const CollectiApp());
}
