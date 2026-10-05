import 'dart:convert';

import 'package:crypto/crypto.dart';

String hashPassword(String password, String salt) {
  List<int> bytes = utf8.encode('$salt::$password');
  for (var i = 0; i < 12000; i++) {
    bytes = sha256.convert(bytes).bytes;
  }
  return sha256.convert(bytes).toString();
}
