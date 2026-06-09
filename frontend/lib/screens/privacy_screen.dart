import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.bg(b),
      appBar: AppBar(title: const Text('隐私政策')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('灵犀 隐私政策', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text(b))),
          const SizedBox(height: 8),
          Text('最后更新：2026年6月', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(b))),
          const SizedBox(height: 20),
          _section('1. 信息收集', '我们仅收集您主动提供的信息：手机号（用于登录）、邮箱（可选，用于邮件摘要）、对话内容（用于AI回复和记忆提取）。我们不会收集您的通讯录、位置（除非您主动查询天气）、相册（除非您主动上传文件转换）。', b),
          _section('2. 信息使用', '您的对话内容用于：AI生成回复、提取长期记忆（如偏好、习惯）、生成主动关怀消息。您的记忆数据仅存储在您的账户下，不会用于训练模型或分享给第三方。', b),
          _section('3. 数据存储与安全', '所有数据存储在加密的PostgreSQL数据库中。通信使用HTTPS/TLS加密。JWT令牌用于身份验证。我们不会将您的数据出售或分享给任何第三方。', b),
          _section('4. 您的权利', '您可以在"我的"页面查看和编辑个人信息。您可以随时删除对话记录、记忆数据和账户。删除账户将永久清除所有关联数据，不可恢复。', b),
          _section('5. 数据删除', '如需删除账户，请点击下方按钮。系统将立即删除您的所有数据（对话、记忆、日程、记账记录、倒数日等）。此操作不可撤销。', b),
          _section('6. 联系我们', '如有隐私相关问题，请联系：lvxiang639@126.com', b),
          const SizedBox(height: 30),
          _section('7. 第三方服务', '本应用使用以下第三方服务：DeepSeek API（AI对话）、ip-api.com（IP定位城市）、SearXNG（搜索服务）。这些服务可能收到您的查询文本和IP地址，但不会收到您的账户信息。', b),
        ]),
      ),
    );
  }

  Widget _section(String title, String body, Brightness b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text(b))),
        const SizedBox(height: 6),
        Text(body, style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.textSecondary(b))),
      ]),
    );
  }
}
