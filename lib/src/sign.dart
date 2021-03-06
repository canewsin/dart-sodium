import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi_helper/ffi_helper.dart';
import 'internal_helpers.dart';
import 'box.dart' show KeyPairException;

import 'bindings/sign.dart' as bindings;

class SignError extends Error {
  @override
  String toString() {
    return 'Failed to sign message';
  }
}

class UpdateStreamException implements Exception {
  @override
  String toString() {
    return 'Failed to update sign stream';
  }
}

class InvalidSignatureError extends Error {
  @override
  String toString() {
    return 'The signature appears to be invalid';
  }
}

class InitStreamException implements Exception {
  @override
  String toString() {
    return 'Failed to initialize sign stream';
  }
}

/// Pair of public and secret key.
class KeyPair {
  final UnmodifiableUint8ListView publicKey, secretKey;
  const KeyPair._(this.publicKey, this.secretKey);

  /// Generates a pair of public and secret key.
  /// Throws [KeyPairException] when generating keys fails.
  factory KeyPair.generate() {
    final pkPtr = Uint8Array.allocate(count: bindings.publicKeyBytes);
    final skPtr = Uint8Array.allocate(count: bindings.secretKeyBytes);
    final result = bindings.keyPair(pkPtr.rawPtr, skPtr.rawPtr);
    final publicKey = UnmodifiableUint8ListView(Uint8List.fromList(pkPtr.view));
    final secretKey = UnmodifiableUint8ListView(Uint8List.fromList(skPtr.view));
    pkPtr.freeZero();
    skPtr.freeZero();
    if (result != 0) {
      throw KeyPairException();
    }
    return KeyPair._(publicKey, secretKey);
  }

  /// Derives [publicKey] and [secretKey] from [seed].
  /// Throws [KeyPairException] when generating keys fails.
  factory KeyPair.fromSeed(Uint8List seed) {
    assert(seed.length == bindings.seedBytes);
    final pkPtr = Uint8Array.allocate(count: bindings.publicKeyBytes);
    final skPtr = Uint8Array.allocate(count: bindings.secretKeyBytes);
    final seedPtr = Uint8Array.fromTypedList(seed);
    final result =
        bindings.seedKeyPair(pkPtr.rawPtr, skPtr.rawPtr, seedPtr.rawPtr);
    final publicKey = UnmodifiableUint8ListView(Uint8List.fromList(pkPtr.view));
    final secretKey = UnmodifiableUint8ListView(Uint8List.fromList(skPtr.view));

    pkPtr.freeZero();
    skPtr.freeZero();
    if (result != 0) {
      throw KeyPairException();
    }
    return KeyPair._(publicKey, secretKey);
  }
}

/// Signs [message] with [secretKey]. [secretKey] must be [secretKeyBytes] long.
Uint8List sign(Uint8List message, Uint8List secretKey) {
  assert(secretKey.length == bindings.secretKeyBytes);
  final skPtr = Uint8Array.fromTypedList(secretKey);
  final messagePtr = Uint8Array.fromTypedList(message);
  final signedMessagePtr =
      Uint8Array.allocate(count: message.length + bindings.signBytes);

  final result = bindings.sign(signedMessagePtr.rawPtr, nullptr.cast(),
      messagePtr.rawPtr, message.length, skPtr.rawPtr);

  skPtr.freeZero();
  messagePtr.free();
  signedMessagePtr.free();

  if (result != 0) {
    throw SignError();
  }
  return Uint8List.fromList(signedMessagePtr.view);
}

/// Verifies the signature of [signedMessage] generated by [sign] and extracts the message.
/// Throws [InvalidSignatureError] when signature is invalid. When [onError] is provided,
/// no Exception will be thrown and null will be returned.
Uint8List open(Uint8List signedMessage, Uint8List publicKey,
    {Function() onError}) {
  assert(publicKey.length == bindings.publicKeyBytes);
  final pkPtr = Uint8Array.fromTypedList(publicKey);
  final signedMessagePtr = Uint8Array.fromTypedList(signedMessage);
  final messagePtr =
      Uint8Array.allocate(count: signedMessage.length - bindings.signBytes);

  final result = bindings.signOpen(messagePtr.rawPtr, nullptr.cast(),
      signedMessagePtr.rawPtr, signedMessage.length, pkPtr.rawPtr);

  pkPtr.freeZero();
  messagePtr.free();
  signedMessagePtr.free();

  if (result != 0) {
    if (onError == null) {
      throw InvalidSignatureError();
    }
    onError();
    return null;
  }
  return Uint8List.fromList(messagePtr.view);
}

Uint8List _initStream() {
  final statePtr = Uint8Array.allocate(count: bindings.stateBytes);
  final result = bindings.signInit(statePtr.rawPtr);

  final state = Uint8List.fromList(statePtr.view);
  statePtr.freeZero();
  if (result != 0) {
    throw InitStreamException();
  }
  return state;
}

mixin Update {
  Uint8List _state;

  /// Updates stream with [message].
  /// Call [update] for every part of the message.
  /// Throws [UpdateException] when updating the state fails.
  void update(Uint8List message) {
    final statePtr = Uint8Array.fromTypedList(_state);
    final messagePtr = Uint8Array.fromTypedList(message);

    final result =
        bindings.signUpdate(statePtr.rawPtr, messagePtr.rawPtr, message.length);
    _state.setAll(0, statePtr.view);
    statePtr.freeZero();
    messagePtr.free();
    if (result != 0) {
      throw UpdateStreamException;
    }
  }
}

/// Generates signature for a multi-part message.
class SignStream with Update {
  @override
  final Uint8List _state;

  UnmodifiableUint8ListView get state => UnmodifiableUint8ListView(_state);

  /// Resume stream with a saved [state].
  SignStream.resume(this._state) : assert(_state.length == bindings.stateBytes);
  SignStream() : _state = _initStream();

  /// Generates the signature for the multi-part message.
  /// The [SignStream] shouldn't be used any more after calling [finalize].
  /// [secretKey] must be [secretKeyBytes] long.
  /// Throws [SignError] when generating signature fails.
  Uint8List finalize(Uint8List secretKey) {
    final statePtr = Uint8Array.fromTypedList(_state);
    final signPtr = Uint8Array.allocate(count: bindings.signBytes);
    final skPtr = Uint8Array.fromTypedList(secretKey);

    final result = bindings.signFinal(
        statePtr.rawPtr, signPtr.rawPtr, nullptr.cast(), skPtr.rawPtr);
    _state.setAll(0, statePtr.view);
    statePtr.freeZero();
    signPtr.free();
    skPtr.freeZero();

    if (result != 0) {
      throw SignError();
    }
    return Uint8List.fromList(signPtr.view);
  }
}

/// Stream to verify the signature of a multi-part message
class VerifyStream with Update {
  @override
  final Uint8List _state;
  UnmodifiableUint8ListView get state => _state;

  /// Resume stream with a saved [state].
  VerifyStream.resume(this._state)
      : assert(_state.length == bindings.stateBytes);
  VerifyStream() : _state = _initStream();

  /// Verifies [signature] of a multi-part message generated by [SignStream].
  /// [publicKey] must be [publicKeyBytes] long.
  bool verify(Uint8List signature, Uint8List publicKey) {
    assert(signature.length == bindings.signBytes);
    assert(publicKey.length == bindings.publicKeyBytes);
    final statePtr = Uint8Array.fromTypedList(_state);
    final signPtr = Uint8Array.fromTypedList(signature);
    final pkPtr = Uint8Array.fromTypedList(publicKey);

    final result =
        bindings.signFinalVerify(statePtr.rawPtr, signPtr.rawPtr, pkPtr.rawPtr);
    return result == 0;
  }
}
