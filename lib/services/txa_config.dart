/// TxaConfig — Centralized configuration for TPhimX app
/// Quản lý thông tin cấu hình donate, chuyển khoản, v.v.
class TxaConfig {
  TxaConfig._(); // Prevent instantiation

  // ═══════════════════════════════════════════════════════════
  //  DONATE / CHUYỂN KHOẢN
  // ═══════════════════════════════════════════════════════════

  /// Chủ tài khoản
  static const String donateAccountName = 'TANG XUAN ANH';

  /// Số tài khoản
  static const String donateAccountNumber = '2923252311';

  /// Mã ngân hàng (VietQR bank code)
  static const String donateBankCode = 'TCB';

  /// Tên ngân hàng hiển thị
  static const String donateBankName = 'Techcombank';

  /// Prefix nội dung chuyển khoản (sẽ + 6 ký tự hash máy)
  static const String donateContentPrefix = 'TDONGPHIM';

  // ═══════════════════════════════════════════════════════════
  //  VIETQR API
  // ═══════════════════════════════════════════════════════════

  /// Base URL cho VietQR image API
  /// Format: {baseUrl}/{bankCode}-{accountNo}-compact.png?addInfo=...&accountName=...
  static const String vietQrBaseUrl = 'https://img.vietqr.io/image';

  /// Build full VietQR image URL
  static String buildQrUrl({required String transferContent}) {
    final encodedContent = Uri.encodeComponent(transferContent);
    final encodedName = Uri.encodeComponent(donateAccountName);
    return '$vietQrBaseUrl/$donateBankCode-$donateAccountNumber-compact.png'
        '?addInfo=$encodedContent'
        '&accountName=$encodedName';
  }
}
