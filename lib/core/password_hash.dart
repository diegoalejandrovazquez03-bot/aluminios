import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Cifrado de contraseñas para las cuentas guardadas en el teléfono (modo sin
/// servidor). Mismo formato que el backend:
/// `pbkdf2-sha256$<iteraciones>$<sal base64>$<hash base64>`.
/// Nunca se guarda la contraseña en texto.
class PasswordHash {
  static const int _iterations = 20000;
  static const int _saltSize = 16;
  static const int _hashSize = 32;

  static String hash(String password) {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List.generate(_saltSize, (_) => random.nextInt(256)),
    );
    final derived = _pbkdf2(utf8.encode(password), salt, _iterations);
    return 'pbkdf2-sha256\$$_iterations\$${base64Encode(salt)}\$${base64Encode(derived)}';
  }

  static bool verify(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2-sha256') return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null) return false;
    try {
      final salt = base64Decode(parts[2]);
      final expected = base64Decode(parts[3]);
      final actual = _pbkdf2(utf8.encode(password), salt, iterations);
      if (actual.length != expected.length) return false;
      var diff = 0; // Comparación en tiempo constante.
      for (var i = 0; i < actual.length; i++) {
        diff |= actual[i] ^ expected[i];
      }
      return diff == 0;
    } catch (_) {
      return false;
    }
  }

  /// PBKDF2 con HMAC-SHA256 (un solo bloque de 32 bytes).
  static Uint8List _pbkdf2(List<int> password, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(u);
    for (var i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < _hashSize; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }
}
