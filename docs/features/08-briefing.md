# 每日简报 (Briefing)

## 两种触发

### 自动推送 (8:00 AM 北京时间)
```
notification_service 轮询 → hour == 8
    │
    ▼
briefing_service.check_and_send_briefings()
    │
    ▼
对每个在线用户且 last_briefing_date ≠ today:
    ├── 获取今日日历事件
    ├── 获取昨日消费总额
    ├── IP 检测城市 → 获取天气 (wttr.in)
    ├── LLM 生成问候语 (BRIEFING_PROMPT)
    ├── 更新 last_briefing_date = today
    └── WebSocket 推送简报
```

### 手动触发
```
用户说 "早上好" / "今日简报"
    │
    ▼
LLM intent classify → "briefing"
    │
    ▼
BriefingSkill.execute() → generate_briefing()
    │
    ▼
返回格式化的简报文本
```

## 简报格式
```
☀️ 早安问候（LLM 生成，融入天气+心情）

📅 今日提醒
  · 10:00 开会
  · 15:00 看牙医

💰 昨日消费
  共 ¥57.00

💪 结尾鼓励
```

## 防重复
```
每个用户每天最多一次自动简报
last_briefing_date == today → 跳过
手动触发不受限制
```
