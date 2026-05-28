import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuth();
    });
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final phoneRE = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRE.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的手机号')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final provider = context.read<AuthProvider>();
      final isNew = await provider.login(phone);
      if (!mounted) return;
      if (isNew) {
        _showNameDialog(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showNameDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('给你的AI伴侣起个名字'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: '如：小白、小灵'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              nameController.dispose();
              await context.read<CharacterProvider>().initCharacter(name);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              const Text('灵犀', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.indigo)),
              const SizedBox(height: 8),
              const Text('AI 虚拟伴侣', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const Spacer(),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: const InputDecoration(
                  labelText: '手机号',
                  hintText: '请输入手机号',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('登录 / 注册', style: TextStyle(fontSize: 16)),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
