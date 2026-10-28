import 'package:shared_preferences/shared_preferences.dart';

class FirstUseGuideStore {
  const FirstUseGuideStore();

  String _key(String userId) => 'pago_${userId}_first_use_v1';

  Future<bool> shouldShow(String userId) async {
    if (userId.trim().isEmpty) return false;
    final preferences = await SharedPreferences.getInstance();
    return !(preferences.getBool(_key(userId)) ?? false);
  }

  Future<void> complete(String userId) async {
    if (userId.trim().isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_key(userId), true);
    if (!saved) throw StateError('Não foi possível salvar o primeiro uso.');
  }
}
