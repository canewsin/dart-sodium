/// Message authentication via secret key.
/// Maps libsodium's crypto_auth_* api.
library auth;

export 'src/auth.dart';
export 'src/bindings/auth.dart' show authBytes, keyBytes;
