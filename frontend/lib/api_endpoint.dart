import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

String resolveSimulatorApi(
  String configured, {
  required bool simulator,
  required bool debug,
}) {
  final uri = Uri.tryParse(configured);
  if (!debug || !simulator || uri == null || uri.scheme != 'http') {
    return configured;
  }
  final octets = uri.host.split('.').map(int.tryParse).toList();
  final private =
      octets.length == 4 &&
      octets.every((n) => n != null && n >= 0 && n <= 255) &&
      (octets[0] == 10 ||
          (octets[0] == 192 && octets[1] == 168) ||
          (octets[0] == 172 && octets[1]! >= 16 && octets[1]! <= 31));
  return private ? uri.replace(host: '127.0.0.1').toString() : configured;
}

Future<String> simulatorApiEndpoint(String configured) async {
  if (!kDebugMode || !Platform.isIOS) return configured;
  try {
    final simulator =
        await const MethodChannel(
          'learn_anywhere/identity',
        ).invokeMethod<bool>('isSimulator') ??
        false;
    return resolveSimulatorApi(
      configured,
      simulator: simulator,
      debug: kDebugMode,
    );
  } on MissingPluginException {
    return configured;
  }
}
