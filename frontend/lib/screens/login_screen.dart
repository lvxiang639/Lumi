import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _isEmailMode = false;
  bool _isRegister = false; // login vs register for email

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuth();
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Phone login ──

  Future<void> _phoneLogin() async {
    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      _snack('请输入正确的手机号');
      return;
    }
    setState(() => _loading = true);
    try {
      final isNew = await context.read<AuthProvider>().login(phone);
      if (!mounted) return;
      if (isNew) _showNameDialog();
    } catch (e) {
      if (mounted) _snack('登录失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Email auth ──

  Future<void> _emailAuth() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (!email.contains('@') || email.length < 5) {
      _snack('请输入正确的邮箱地址');
      return;
    }
    if (password.length < 6) {
      _snack('密码至少6位');
      return;
    }
    setState(() => _loading = true);
    try {
      final path = _isRegister ? '/api/auth/register' : '/api/auth/email-login';
      final result = await AuthProvider.emailAuth(path, email, password);
      // Reload auth state
      await context.read<AuthProvider>().checkAuth();
      if (!mounted) return;
      if (_isRegister || result.isNewUser) {
        _showNameDialog();
      }
    } catch (e) {
      if (mounted) _snack('${_isRegister ? "注册" : "登录"}失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showNameDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('给你的AI伴侣起个名字'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '如：小白、小灵'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              ctrl.dispose();
              await context.read<CharacterProvider>().initCharacter(name);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const AppLogo(size: 90),
              const SizedBox(height: 40),

              // Mode toggle
              Row(children: [
                _modeTab('手机登录', !_isEmailMode, () => setState(() => _isEmailMode = false)),
                const SizedBox(width: 12),
                _modeTab('邮箱', _isEmailMode, () => setState(() => _isEmailMode = true)),
              ]),
              const SizedBox(height: 20),

              if (!_isEmailMode) ...[
                // Phone input
                _inputBox(_phoneCtrl, '手机号', TextInputType.phone, maxLength: 11),
                const SizedBox(height: 16),
                _bigButton('登录 / 注册', _phoneLogin),
              ] else ...[
                // Email inputs
                _inputBox(_emailCtrl, '邮箱地址', TextInputType.emailAddress),
                const SizedBox(height: 12),
                _inputBox(_passwordCtrl, '密码', TextInputType.visiblePassword, obscure: true),
                const SizedBox(height: 16),
                _bigButton(_isRegister ? '注册' : '登录', _emailAuth),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _isRegister = !_isRegister),
                  child: Text(
                    _isRegister ? '已有账号？去登录' : '没有账号？去注册',
                    style: const TextStyle(color: AppColors.accent, fontSize: 13),
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? null : Border.all(color: AppColors.lightBorder),
          ),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: active ? Colors.white : AppColors.textLightSecondary,
                fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _inputBox(TextEditingController ctrl, String hint, TextInputType kb,
      {int? maxLength, bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: kb,
        maxLength: maxLength,
        obscureText: obscure,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textLightSecondary, fontSize: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          counterText: '',
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _bigButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
