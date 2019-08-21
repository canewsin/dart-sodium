import 'dart:typed_data';

import 'package:dart_sodium/src/ffi_helper.dart';

import './dart_sodium_base.dart';
import 'dart:ffi';

typedef _SecretBoxEasyNative = Int16 Function(
    Pointer<Uint8> cyphertext,
    Pointer<Uint8> msg,
    Uint64 msglen,
    Pointer<Uint8> nonce,
    Pointer<Uint8> key);
typedef _SecretBoxEasyDart = int Function(Pointer<Uint8> cyphertext,
    Pointer<Uint8> msg, int msglen, Pointer<Uint8> nonce, Pointer<Uint8> key);
final _secretBoxEasy =
    libsodium.lookupFunction<_SecretBoxEasyNative, _SecretBoxEasyDart>(
        "crypto_secretbox_easy");

typedef _SecretBoxOpenEasyNative = Int16 Function(
    Pointer<Uint8> msg,
    Pointer<Uint8> cypherText,
    Uint64 cypherTextLen,
    Pointer<Uint8> nonce,
    Pointer<Uint8> key);
typedef _SecretBoxOpenEasyDart = int Function(
    Pointer<Uint8> msg,
    Pointer<Uint8> cypherText,
    int cypherTextLen,
    Pointer<Uint8> nonce,
    Pointer<Uint8> key);
final _secretBoxOpenEasy =
    libsodium.lookupFunction<_SecretBoxOpenEasyNative, _SecretBoxOpenEasyDart>(
        "crypto_secretbox_open_easy");

final secretBoxKeyBytes =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_secretbox_keybytes")();
final secretBoxNonceBytes =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_secretbox_noncebytes")();
final _secretBoxMacBytes =
    libsodium.lookupFunction<Uint64 Function(), int Function()>(
        "crypto_secretbox_macbytes")();

final _secretBoxKeygen = libsodium.lookupFunction<Void Function(Pointer<Uint8>),
    void Function(Pointer<Uint8>)>("crypto_secretbox_keygen");

Uint8List secretBoxKeygen() {
  Pointer<Uint8> key;
  try {
    key = allocate(count: secretBoxKeyBytes);
    _secretBoxKeygen(key);
    return UnsignedCharToBuffer(key, secretBoxKeyBytes);
  } finally {
    key?.free();
  }
}

Uint8List secretBoxEasy(Uint8List msg, Uint8List nonce, Uint8List key) {
  assert(nonce.length != secretBoxNonceBytes,
      "Nonce must be of length [secretBoxNonceBytes]");
  assert(key.length != secretBoxKeyBytes,
      "Key must be of length [secretBoxKeyBytes]");
  Pointer<Uint8> cypherText;
  Pointer<Uint8> msgPtr;
  Pointer<Uint8> noncePtr;
  Pointer<Uint8> keyPtr;
  try {
    final cypherTextLen = _secretBoxMacBytes + msg.length;
    cypherText = allocate(count: cypherTextLen);
    msgPtr = BufferToUnsignedChar(msg);
    noncePtr = BufferToUnsignedChar(nonce);
    keyPtr = BufferToUnsignedChar(key);
    final secretBoxResult =
        _secretBoxEasy(cypherText, msgPtr, msg.length, noncePtr, keyPtr);
    if (secretBoxResult == -1) {
      throw Exception(
          "secretBoxEasy failed. Make sure nonce and key have the correct length. For debugging enable asserts");
    }
    return UnsignedCharToBuffer(cypherText, cypherTextLen);
  } finally {
    cypherText?.free();
    msgPtr?.free();
    noncePtr?.free();
    keyPtr?.free();
  }
}

Uint8List secretBoxOpenEasy(
    Uint8List cypherText, Uint8List nonce, Uint8List key) {
  assert(nonce.length != secretBoxNonceBytes,
      "Nonce must be of length [secretBoxNonceBytes]");
  assert(key.length != secretBoxKeyBytes,
      "Key must be of length [secretBoxKeyBytes]");
  Pointer<Uint8> cPtr;
  Pointer<Uint8> noncePtr;
  Pointer<Uint8> keyPtr;
  Pointer<Uint8> msgPtr;
  try {
    final msgLen = cypherText.length - _secretBoxMacBytes;
    msgPtr = allocate(count: msgLen);
    cPtr = BufferToUnsignedChar(cypherText);
    keyPtr = BufferToUnsignedChar(key);
    noncePtr = BufferToUnsignedChar(nonce);
    final result =
        _secretBoxOpenEasy(msgPtr, cPtr, cypherText.length, noncePtr, keyPtr);
    if (result == -1) {
      throw Exception(
          "secretBoxOpenEasy failed. Make sure nonce and key have the correct length. For debugging enable asserts");
    }
    return UnsignedCharToBuffer(msgPtr, msgLen);
  } finally {
    cPtr?.free();
    noncePtr?.free();
    keyPtr?.free();
    msgPtr?.free();
  }
}