import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

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
      rethrow;
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
