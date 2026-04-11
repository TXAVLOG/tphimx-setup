# TPhimX - Flutter Setup App

Đây là mã nguồn (Source Code) của ứng dụng **TPhimX**, được xây dựng bằng **Flutter**. Ứng dụng này hỗ trợ quản lý và cài đặt các thành phần trong hệ sinh thái TPhimX.

## 🛠 Hướng dẫn Tự Build (IPA cho iOS)

Vì bạn đang xem mã nguồn này, bạn có thể tự build file IPA để cài đặt lên iPhone của mình mà không cần chờ bản phát hành chính thức.

### 1. Build bằng Codemagic (Khuyên dùng cho Windows)
Nếu bạn không có máy Mac, Codemagic là lựa chọn tốt nhất:
1.  Kết nối Repo này với [Codemagic.io](https://codemagic.io/).
2.  Chọn dự án **Flutter App**.
3.  Cấu hình Build platform là **iOS**.
4.  Trong phần **Distribution**, nếu bạn có Apple Developer Account, hãy dùng tính năng **Automatic Code Signing**.
5.  Nhấn **Start Build** và nhận file IPA qua email hoặc tải trực tiếp trên web.

### 2. Build bằng máy Mac cá nhân
Nếu bạn có máy Mac:
1.  Cài đặt Flutter SDK và Xcode.
2.  Mở terminal tại thư mục này và chạy:
    ```bash
    flutter pub get
    cd ios && pod install && cd ..
    flutter build ipa --release
    ```
3.  Sau khi build xong, file `.ipa` sẽ nằm trong `build/ios/ipa/`.

### 3. Cài đặt qua Link (OTA)
Sau khi có file IPA, bạn có thể dùng **Diawi** hoặc **Firebase App Distribution** để tạo link tải trực tiếp trên Safari.

---

## 📂 Cấu trúc dự án
- `lib/`: Chứa toàn bộ logic code Dart của ứng dụng.
- `android/` & `ios/`: Thư mục chứa cấu hình nền tảng tương ứng.
- `assets/`: Chứa hình ảnh, font chữ và các tài nguyên tĩnh.

---
*Ghi chú: Để ứng dụng hoạt động ổn định và có thể cài đặt rộng rãi, hãy sử dụng chứng chỉ Apple Developer hợp lệ.*
