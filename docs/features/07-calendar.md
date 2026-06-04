# 日历提醒 (Calendar)

## 数据模型
```
calendar_events: id, user_id, title, time, repeat_rule, notified, created_at, updated_at
```

## 对话触发
```
用户说 "明天上午8点提醒我看电视"
    │
    ▼
LLM intent classify → "calendar"
    │
    ▼
CalendarSkill.execute()
    │
    ▼
LLM 提取: {title: "看电视", time: "2026-06-05T08:00:00", repeat_rule: "none"}
    │
    ▼ (如果 naive → 补 Beijing TZ)
    ▼
存入 calendar_events → 同步到系统日历(iOS/Android)
    ↓
回复: "已添加日历提醒：看电视，时间06月05日 08:00"
```

## 系统日历同步
```
CalendarSyncService (device_calendar plugin)
    ├── iOS/Android: 直接写入系统日历
    └── macOS: 生成 .ics 文件 → open 命令
```

## 通知
```
notification_service (每60s轮询)
    │
    ▼
SELECT * FROM calendar_events WHERE notified=false AND time <= now
    │
    ▼
标记 notified=true → 重复事件生成下一次
    │
    ▼ (WebSocket 在线)
    推送通知给用户
```

## 重复规则
```
daily:   time + 1 day
weekly:  time + 1 week
monthly: 日历月(处理月末溢出: 1/31 → 2/28)
yearly:  time + 1 year
```
