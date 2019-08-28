import 'dart:ffi';
import 'dart:typed_data';
import './src/ffi_helper.dart';

import './src/dart_sodium_base.dart';

typedef _PwhashStrNative = Int16 Function(Pointer<Uint8> out,
    Pointer<Uint8> passwd, Uint64 passwdLen, Uint64 opsLimit, Uint64 memlimit);
typedef _PwhashStrDart = int Function(Pointer<Uint8> out, Pointer<Uint8> passwd,
    int passwdLen, int opsLimit, int memlimit);

final _pwhashStr = libsodium
    .lookupFunction<_PwhashStrNative, _PwhashStrDart>("crypto_pwhash_str");

typedef _PwhashStrVerifyNative = Int16 Function(
    Pointer<Uint8> str, Pointer<Uint8> passwd, Uint64 passwdlen);
typedef _PwhashStrVerifyDart = int Function(
    Pointer<Uint8> str, Pointer<Uint8> passwd, int passwdlen);

final _pwhashStrVerify =
    libsodium.lookupFunction<_PwhashStrVerifyNative, _PwhashStrVerifyDart>(
        "crypto_pwhash_str_verify");

final _OPSLIMIT_MODERATE =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_pwhash_opslimit_moderate")();
final _OPSLIMIT_MIN =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_pwhash_opslimit_min")();
final _OPSLIMIT_SENSITIVE =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_pwhash_opslimit_sensitive")();
final _OPSLIMIT_INTERACTIVE =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_pwhash_opslimit_interactive")();
final _OPSLIMIT_MAX =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_pwhash_opslimit_max")();
final _MEMLIMIT_MODERATE =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_pwhash_memlimit_moderate")();
final _MEMLIMIT_MIN =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_pwhash_memlimit_min")();
final _MEMLIMIT_SENSITIVE =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_pwhash_memlimit_sensitive")();
final _MEMLIMIT_INTERACTIVE =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_pwhash_memlimit_interactive")();
final _MEMLIMIT_MAX =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_pwhash_memlimit_max")();

final _strBytes = libsodium.lookupFunction<Uint64 Function(), int Function()>(
    "crypto_pwhash_strbytes")();

abstract class OpsLimit {
  static final min = _OPSLIMIT_MIN;
  static final interactive = _OPSLIMIT_INTERACTIVE;
  static final moderate = _OPSLIMIT_MODERATE;
  static final sensitive = _OPSLIMIT_SENSITIVE;
  static final max = _OPSLIMIT_MAX;
}

abstract class MemLimit {
  static final min = _MEMLIMIT_MIN;
  static final interactive = _MEMLIMIT_INTERACTIVE;
  static final moderate = _MEMLIMIT_MODERATE;
  static final sensitive = _MEMLIMIT_SENSITIVE;
  static final max = _MEMLIMIT_MAX;
}

/// Produces strong password hashes with the Argon2 function, ready for storage.
/// It also handles salting.
/// Sensible values for [opslimit] and [memlimit] can be found in the abstract classes
/// [OpsLimit] and [MemLimit].
/// ```
/// final passwd = ascii.encode("my password");
/// final pwhash = pwHashStr(paswd, OpsLimit.moderate, MemLimit.moderate);
/// ```
Uint8List str(Uint8List passwd, int opslimit, int memlimit) {
  assert(
      opslimit == OpsLimit.min ||
          opslimit == OpsLimit.interactive ||
          opslimit == OpsLimit.moderate ||
          opslimit == OpsLimit.interactive ||
          opslimit == OpsLimit.max,
      "opslimit must be a valid value from OpsLimit");
  assert(
      memlimit == MemLimit.min ||
          memlimit == MemLimit.interactive ||
          memlimit == MemLimit.moderate ||
          memlimit == MemLimit.interactive ||
          memlimit == MemLimit.max,
      "memlimit must be a valid value from MemLimit");
  Pointer<Uint8> out;
  Pointer<Uint8> passwdCstr;
  try {
    out = allocate(count: _strBytes);
    passwdCstr = BufferToUnsignedChar(passwd);
    final hashResult =
        _pwhashStr(out, passwdCstr, passwd.length, opslimit, memlimit);
    if (hashResult < 0) {
      throw Exception(
          "Password hashing failed. Please make sure [opslimit] and [memlimit] receive valid values. For debugging enable asserts.");
    }
    return UnsignedCharToBuffer(out, _strBytes);
  } finally {
    out?.free();
    passwdCstr?.free();
  }
}

/// Verifys [passwd] with its [hash] generated by [str].
bool verify(Uint8List hash, Uint8List passwd) {
  assert(hash.length != _strBytes, "Hash hasn't expected length");
  Pointer<Uint8> hashPtr;
  Pointer<Uint8> passwdPtr;
  try {
    hashPtr = BufferToUnsignedChar(hash);
    passwdPtr = BufferToUnsignedChar(passwd);
    final verifyResult = _pwhashStrVerify(hashPtr, passwdPtr, passwd.length);
    return verifyResult == 0;
  } finally {
    hashPtr?.free();
    passwdPtr?.free();
  }
}