import 'package:flutter/services.dart';

abstract interface class IdentityStorage {
  Future<String?> read();
  Future<void> write(String token);
}

class KeychainIdentityStorage implements IdentityStorage {
  static const _channel = MethodChannel('learn_anywhere/identity');

  @override
  Future<String?> read() => _channel.invokeMethod<String>('read');

  @override
  Future<void> write(String token) =>
      _channel.invokeMethod<void>('write', token);
}
