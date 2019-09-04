import 'dart:ffi';
import 'dart:typed_data';
import 'ffi_helper.dart';

import 'bindings/pwhash.dart' as bindings;

export 'bindings/pwhash.dart' show OpsLimit, MemLimit;

/// Produces strong password hashes with the Argon2 function, ready for storage.
/// It also handles salting.
/// Sensible values for [opslimit] and [memlimit] can be found in the abstract classes
/// [OpsLimit] and [MemLimit].
/// ```
/// final passwd = ascii.encode("my password");
/// final pwhash = pwHashStr(paswd, OpsLimit.moderate, MemLimit.moderate);
/// ```
Uint8List store(Uint8List passwd, int opslimit, int memlimit) {
  final out = allocate<Uint8>(count: bindings.strBytes);
  final passwdCstr = BufferToCString(passwd);
  try {
    final hashResult =
        bindings.store(out, passwdCstr, passwd.length, opslimit, memlimit);
    if (hashResult < 0) {
      throw Exception("Password hashing failed");
    }
    return CStringToBuffer(out, bindings.strBytes);
  } finally {
    out.free();
    passwdCstr.free();
  }
}

bool verify(Uint8List hash, Uint8List passwd) {
  final hashPtr = BufferToCString(hash);
  final passwdPtr = BufferToCString(passwd);
  try {
    final verifyResult =
        bindings.storeVerify(hashPtr, passwdPtr, passwd.length);
    return verifyResult == 0;
  } finally {
    hashPtr.free();
    passwdPtr.free();
  }
}
