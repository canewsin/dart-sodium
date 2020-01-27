import 'bindings/pwhash.dart' as bindings;
import 'package:ffi_helper/ffi_helper.dart';
import 'dart:typed_data';
import 'internal_helpers.dart';

class PasswordHashException extends Error {
  @override
  String toString() {
    return 'Failed to generate password hash';
  }
}

/// Generates a password hash which can be safely stored.
/// [opsLimit] must be between [OpsLimit.min] and [OpsLimit.max].
/// [memLimit] must be between [MemLimit.min] and [MemLimit.max].
/// Throws a [PasswordHashException] when generating a password hash fails.
Uint8List store(Uint8List password, int opsLimit, int memLimit) {
  assert(
      opsLimit <= bindings.OpsLimit.max && opsLimit >= bindings.OpsLimit.min);
  assert(
      memLimit <= bindings.MemLimit.max && memLimit >= bindings.MemLimit.min);
  assert(password.length <= bindings.passwdMax &&
      password.length >= bindings.passwdMin);
  final passwordPtr = Uint8Array.fromTypedList(password);
  final hashPtr = Uint8Array.allocate(count: bindings.storeBytes);
  final result = bindings.store(
      hashPtr.rawPtr, passwordPtr.rawPtr, password.length, opsLimit, memLimit);
  passwordPtr.view.fillZero();
  passwordPtr.free();
  hashPtr.free();
  if (result != 0) {
    throw PasswordHashException();
  }
  return Uint8List.fromList(hashPtr.view.takeWhile((e) => e != 0).toList());
}

/// Verifies a password with [hash] generated by [store].
bool verify(Uint8List hash, Uint8List password) {
  assert(hash.length <= bindings.bytesMax && hash.length >= bindings.bytesMin);
  assert(password.length <= bindings.passwdMax &&
      password.length >= bindings.passwdMin);
  final hashPtr = Uint8Array.allocate(count: hash.length + 1);
  hashPtr.view.setAll(0, hash);
  hashPtr.view.last = 0;
  final passwordPtr = Uint8Array.fromTypedList(password);
  final result =
      bindings.verify(hashPtr.rawPtr, passwordPtr.rawPtr, password.length);
  passwordPtr.view.fillZero();
  passwordPtr.free();
  hashPtr.free();
  return result == 0;
}

/// Verifies if a hash generated by [store] was generated with [opsLimit] and [memLimit].
/// If not a new hash must be generated.
/// Throws an [ArgumentError], if the hash is invalid.
bool needsRehash(Uint8List hash, int opsLimit, int memLimit) {
  assert(hash.length <= bindings.bytesMax && hash.length >= bindings.bytesMin);
  assert(
      opsLimit <= bindings.OpsLimit.max && opsLimit >= bindings.OpsLimit.min);
  assert(
      memLimit <= bindings.MemLimit.max && memLimit >= bindings.MemLimit.min);
  final hashPtr = Uint8Array.allocate(count: hash.length + 1);
  hashPtr.view.setAll(0, hash);
  hashPtr.view.last = 0;
  final result = bindings.needsRehash(hashPtr.rawPtr, opsLimit, memLimit);
  hashPtr.free();
  return result == 0;
}
