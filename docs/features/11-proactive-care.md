# 主动关怀 V2 (Proactive Care)

## 架构

```
proactive_service.py
├── _poll()         每 ~3 小时循环，22-8 时跳过
├── _check_all()    遍历在线用户
├── _check_user()   单用户 8 项检查 + LLM 生成
├── _can_push()     DB 节流：2h 冷却 + 3条/天
├── _do_push()      发送 WS + 写 proactive_pushes 表
│
├── _check_holiday()    节日检测（7个内置节日）
├── _check_weather()    天气提醒（2h 缓存）
├── _check_calendar()   未来 1h 日程
├── _check_expense()    昨日消费
├── _check_idle()       4h+ 未上线
├── _check_water()      白天补水提醒
├── _check_emotion()    情绪关怀
├── _check_memory()     记忆话题
├── _check_countdown()  倒数日 3/1/0 天提醒
├── _check_news()       新闻推送（独立）
│
├── _generate_push_text() LLM 自然文案生成
└── send_connect_greeting() WS连接问候（共享节流）
```

## 推送流程

1. 定时循环每 ~3 小时触发，22:00-8:00 安静时段跳过
2. 节假日优先：命中则覆盖其他检查
3. 8 项检查返回结构化 dict
4. 所有 HIT 汇总 → LLM 一次生成自然文案（80 字内）
5. `proactive_pushes` 表持久化记录
6. 新闻独立推送，不合并

## 节流设计

- 数据库表 `proactive_pushes`：user_id + push_type + created_at
- 2 小时冷却：`SELECT COUNT() WHERE created_at >= NOW() - 2h`
- 每日上限 3 条：`SELECT COUNT() WHERE created_at >= today`
- 服务器重启安全：记录在 DB，不依赖内存

## 晨间简报

- 8 点后首次上线触发
- 查询 `proactive_pushes` 表当日是否已发
- 内容：天气 + 日程 + 昨日消费 + LLM 鼓励语

## 配置

- 检查间隔：`notification_check_interval * 180` 秒（~3h）
- 安静时段：22:00 - 8:00
- 日推送上限：3 条
- 冷却时间：2 小时
