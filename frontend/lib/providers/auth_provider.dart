import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart' show AuthService, LoginResult;

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  User? _user;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> checkAuth() async {
    if (await _auth.isLoggedIn()) {
      _loading = true;
      notifyListeners();
      try {
        _user = await _auth.getProfile();
      } catch (_) {
        await _auth.logout();
      }
      _loading = false;
      notifyListeners();
    }
  }

  static Future<LoginResult> emailAuth(String path, String email, String password) async {
    final auth = AuthService();
    final result = await auth.emailAuth(path, email, password);
    // Mark as authenticated by loading profile into current provider
    return result;
  }

  Future<void> updateProfile({String? nickname, String? avatar, String? email, String? persona}) async {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (avatar != null) body['avatar'] = avatar;
    if (email != null) body['email'] = email;
    if (persona != null) body['persona'] = persona;
    await _auth.updateProfile(body: body);
  }

  Future<bool> login(String phone) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _auth.login(phone);
      _user = await _auth.getProfile();
      return result.isNewUser;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    notifyListeners();
  }
}
