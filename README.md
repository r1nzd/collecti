# Collecti

Bộ ứng dụng văn phòng & sáng tạo All-in-One, Local-First. Flutter (UI) + Rust (Core). Giấy phép GPLv3.

## Khởi chạy lần đầu
```bash
# 1. Sinh thư mục nền tảng (windows/, linux/)
flutter create . --platforms=windows,linux --project-name collecti
# 2. Kiểm tra Rust core
cargo test
# 3. Sinh binding Dart <-> Rust
cargo install flutter_rust_bridge_codegen
flutter_rust_bridge_codegen generate
#    rồi thêm `mod frb_generated;` vào native/src/lib.rs và `await RustLib.init();` vào lib/main.dart
# 4. Chạy
flutter run -d windows   # hoặc linux
```
