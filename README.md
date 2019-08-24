I made this thin wrapper around the (awsome) sodium library to check out the new (still experimental) FFI,
but also because cryptography is still a weak point of Dart and I needed something more sophisticated.

The interface resembles the original as good as possible but also follows Dart's naming conventions.
To make the library as generic and performant as possible it makes extensive use of the Uint8List instead of Strings.

Please notice that this work is done to the best of my abilities. This has not been reviewed by external security professionals. If you are one and also feel that Dart needs better cryptography please feel free to 
review and test this library in any way you see fit. I would be happy about any kind of suggestion and improvement.

Please also notice that this library is work in progress. So far there are only a few functions available.
But those are also the most commonly used ones, and I don't plan to change the interface.

## How to Use

Unfortunately Dart doesn't have any solution for compiling native dependencies yet.
Therefore you have to copy the dynamic library file of libsodium into the root directory of your application.
You can download precompiled packages for your system here: https://libsodium.gitbook.io/doc/installation
There you also find further information apart from the dartdoc api-reference. 

## Examples
### Init
````dart
// always call init before any other function of sodium
init()
````
### Authenticated Encryption
````dart
final key = secretBoxKeyGen();
final plaintext = ascii.encode("my plaintext");
final nonce = randomBytesBuf(secretBoxNonceBytes);

// encrypt
final ciphertext = secretBoxEasy(plaintext, nonce, key);

// decrypt
final decrypted = secretBoxOpenEasy(ciphertext, nonce, key);
````
### Password Hashing
````dart
final password = ascii.encode("my password");

// hash password
final hash = pwHashStr(password,    OpsLimit.interactive, MemLimit.interactive);

// verify password
final isValid = pwHashStrVerify(hash, password);
````
### Authentication / Signing
````dart
final key = authKeyGen();
final msg = ascii.encode("some msg");

// generate authentication tag
final tag = auth(msg, key);

// verify integrity of message
final isValid = authVerify(tag, msg, key);
````