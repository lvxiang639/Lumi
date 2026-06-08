import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api = ApiClient();

  Future<LoginResult> login(String phone) async {
    final data = await _api.post('/api/auth/login', body: {'phone': phone});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', data['access_token'] as String);
    return LoginResult(
      accessToken: data['access_token'] as String,
      isNewUser: data['is_new_user'] as bool,
    );
  }

  Future<User> getProfile() async {
    final data = await _api.get('/api/auth/profile');
    return User.fromJson(data);
  }

  Future<void> updateProfile({Map<String, dynamic>? body}) async {
    await _api.put('/api/auth/profile', body: body ?? {});
  }

  Future<LoginResult> emailAuth(String path, String email, String password) async {
    final data = await _api.post(path, body: {'email': email, 'password': password});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', data['access_token'] as String);
    return LoginResult(
      accessToken: data['access_token'] as String,
      isNewUser: data['is_new_user'] as bool,
    );
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('access_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }
}

class LoginResult {
  final String accessToken;
  final bool isNewUser;
  LoginResult({required this.accessToken, required this.isNewUser});
}
