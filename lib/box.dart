import 'dart:ffi';
import 'dart:typed_data';
import 'package:dart_sodium/src/ffi_helper.dart';

import 'src/bindings/box.dart' as bindings;

class _KeyPair {
  final Uint8List publicKey, secretKey;
  const _KeyPair(this.publicKey, this.secretKey);
}

class Box {
  static final secretKeyBytes = bindings.secretKeyBytes;
  static final publicKeyBytes = bindings.publicKeyBytes;
  static final nonceBytes = bindings.nonceBytes;

  static _KeyPair keyPair() {
    final Pointer<Uint8> secretKeyPtr =
        allocate(count: bindings.secretKeyBytes);
    final Pointer<Uint8> publicKeyPtr =
        allocate(count: bindings.publicKeyBytes);
    try {
      final result = bindings.keyPair(publicKeyPtr, secretKeyPtr);
      if (result != 0) {
        throw Exception("Generation of keypair failed");
      }
      final secretKey = CStringToBuffer(secretKeyPtr, bindings.secretKeyBytes);
      final publicKey = CStringToBuffer(secretKeyPtr, bindings.publicKeyBytes);
      return _KeyPair(publicKey, secretKey);
    } finally {
      secretKeyPtr.free();
      publicKeyPtr.free();
    }
  }

  final Pointer<Uint8> secretKey;
  Box(Uint8List secretKey) : this.secretKey = BufferToCString(secretKey) {
    if (secretKey.length != bindings.secretKeyBytes) {
      throw Exception("Secret Key hasn't expected length");
    }
  }

  Uint8List easy(Uint8List msg, Uint8List nonce, Uint8List publicKey) {
    final pkPtr = BufferToCString(publicKey);
    final Pointer<Uint8> msgPtr = BufferToCString(msg);
    final Pointer<Uint8> noncePtr = BufferToCString(nonce);
    final cLen = bindings.macBytes + msg.length;
    final Pointer<Uint8> cPtr = allocate(count: cLen);
    try {
      final result =
          bindings.easy(cPtr, msgPtr, msg.length, noncePtr, pkPtr, secretKey);
      if (result != 0) {
        throw Exception("Encrypting failed");
      }
      return CStringToBuffer(cPtr, cLen);
    } finally {
      msgPtr.free();
      noncePtr.free();
      cPtr.free();
      pkPtr.free();
    }
  }

  Uint8List openEasy(
      Uint8List ciphertext, Uint8List nonce, Uint8List publicKey) {
    final pkPtr = BufferToCString(publicKey);
    final msgLen = ciphertext.length - bindings.macBytes;
    final Pointer<Uint8> msgPtr = allocate(count: msgLen);
    final Pointer<Uint8> noncePtr = BufferToCString(nonce);
    final Pointer<Uint8> cPtr = BufferToCString(ciphertext);
    try {
      final result = bindings.openEasy(
          msgPtr, cPtr, ciphertext.length, noncePtr, pkPtr, secretKey);
      if (result != 0) {
        throw Exception("Decrypting failed");
      }
      return CStringToBuffer(msgPtr, msgLen);
    } finally {
      msgPtr.free();
      noncePtr.free();
      cPtr.free();
      pkPtr.free();
    }
  }

  void close() {
    secretKey.free();
  }
}

class BoxNm {
  final Pointer<Uint8> key;
  BoxNm(Uint8List publicKey, Uint8List secretKey)
      : key = allocate(count: bindings.beforeNmBytes) {
    if (secretKey.length != bindings.secretKeyBytes) {
      throw Exception("Secret Key hasn't expected length");
    }
    if (publicKey.length != bindings.publicKeyBytes) {
      throw Exception("Public Key hasn't expected length");
    }
    final skPtr = BufferToCString(secretKey);
    final pkPtr = BufferToCString(publicKey);
    try {
      final result = bindings.beforeNm(key, pkPtr, skPtr);
      if (result != 0) {
        key.free();
        throw Exception("Key generation failed");
      }
    } finally {
      skPtr.free();
      pkPtr.free();
    }
  }

  Uint8List easy(Uint8List msg, Uint8List nonce) {
    final Pointer<Uint8> msgPtr = BufferToCString(msg);
    final Pointer<Uint8> noncePtr = BufferToCString(nonce);
    final cLen = bindings.macBytes + msg.length;
    final Pointer<Uint8> cPtr = allocate(count: cLen);
    try {
      final result =
          bindings.easyAfterNm(cPtr, msgPtr, msg.length, noncePtr, key);
      if (result != 0) {
        throw Exception(r"Encrypting failed");
      }
      return CStringToBuffer(cPtr, cLen);
    } finally {
      msgPtr.free();
      noncePtr.free();
      cPtr.free();
    }
  }

  Uint8List openEasy(Uint8List ciphertext, Uint8List nonce) {
    final msgLen = ciphertext.length - bindings.macBytes;
    final Pointer<Uint8> msgPtr = allocate(count: msgLen);
    final Pointer<Uint8> noncePtr = BufferToCString(nonce);
    final Pointer<Uint8> cPtr = BufferToCString(ciphertext);
    try {
      final result = bindings.openEasyAfterNm(
          msgPtr, cPtr, ciphertext.length, noncePtr, key);
      if (result != 0) {
        throw Exception("Decrypting failed");
      }
      return CStringToBuffer(msgPtr, msgLen);
    } finally {
      msgPtr.free();
      noncePtr.free();
      cPtr.free();
    }
  }

  void close() {
    key.free();
  }
}