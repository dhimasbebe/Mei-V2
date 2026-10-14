/// Hierarki exception Mei-V agar UI bisa memutuskan pesan yang tepat.
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// 401 — token expired atau credential salah.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Sesi habis. Silakan masuk kembali.'])
      : super(statusCode: 401);
}

/// 403 — role tidak diizinkan mengakses endpoint.
class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'Anda tidak memiliki izin.'])
      : super(statusCode: 403);
}

/// 404 — resource tidak ditemukan (barcode tidak terdaftar, dsb).
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Data tidak ditemukan.'])
      : super(statusCode: 404);
}

/// 409 — conflict, misalnya client_uuid sudah pernah dikirim.
class ConflictException extends ApiException {
  const ConflictException([super.message = 'Data sudah pernah dikirim.'])
      : super(statusCode: 409);
}

/// 422 — validasi gagal.
class ValidationException extends ApiException {
  const ValidationException(this.errors, {String message = 'Validasi gagal.'})
      : super(message, statusCode: 422);

  final Map<String, List<String>>? errors;
}

/// 500+ atau kesalahan jaringan/tidak terduga.
class ServerException extends ApiException {
  const ServerException([super.message = 'Terjadi kesalahan server.'])
      : super(statusCode: 500);
}

/// Tidak ada koneksi internet / timeout.
class NetworkException extends ApiException {
  const NetworkException([super.message = 'Koneksi internet terputus.']);
}
