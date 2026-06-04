# 邮件系统 (Email)

## 两种触发方式

### 方式 1：对话触发
```
用户说 "发送到我的邮箱"
    │
    ▼
LLM intent classify → "email"
    │
    ▼
EmailSkill.execute()
    │
    ├── 查 users.email → 没设置？ → 提示 "请在个人资料中设置邮箱"
    │
    ├── 有邮箱 →
    │    ├── 获取最近一次对话消息
    │    ├── LLM 提炼摘要 (SUMMARY_PROMPT)
    │    ├── SMTP_SSL 发送 (126.com:465)
    │    └── 存入 sent_emails 表
    │
    └── 回复: "✅ 对话摘要已发送到 lvxiang639@126.com"
```

### 方式 2：工具面板
```
🔧 工具 → 邮件 tab
    │
    ├── [发送最新的对话摘要] → POST /api/conversations/{id}/email-summary
    ├── 发送状态提示
    └── 发送记录列表
         ├── 对话标题 + 内容预览
         ├── 收件人 + 发送时间
         └── GET /api/conversations/sent-emails
```

## 数据模型
```
sent_emails: id, user_id, conv_title, recipient, summary_preview, sent_at
```

## SMTP 配置
```env
SMTP_HOST=smtp.126.com
SMTP_PORT=465        # SSL 直连
SMTP_USERNAME=lvxiang639@126.com
SMTP_PASSWORD=<授权码>
SMTP_FROM_EMAIL=lvxiang639@126.com
```

## 摘要格式
```
对话主题: (一句话概括)
关键要点:
- 要点1
- 要点2
待办事项: (如有)
简短总结:
```
