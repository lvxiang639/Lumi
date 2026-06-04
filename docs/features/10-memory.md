# 长期记忆 (Memory)

## 数据模型
```
user_memories: id, user_id, key, value, source_conv_id, created_at, updated_at
```

## 提取流程
```
对话结束 (done 发送后)
    │
    ▼
schedule_extraction() — fire-and-forget
    │
    ▼ async
LLM 提取: "从对话中提取用户的关键信息"
    │
    ▼
解析: 每行 "key: value" 格式
    │
    ▼
_save_memories(): upsert (相同 key → 更新 value)
    │
    ▼
_enforce_limit(): 超过 50 条 → LLM 合并压缩
```

## 注入流程
```
新对话开始
    │
    ▼
get_memory_summary(user_id)
    │
    ▼
读取 user_memories (最多 50 条)
    │
    ▼
注入 system prompt:
  "以下是关于用户的信息：
   - city: 北京
   - job: 产品经理
   - hobby: 摄影
   请在对话中自然地运用这些信息"
```

## 记忆类型
| key 示例 | value 示例 | 来源 |
|----------|-----------|------|
| city | 北京 | 对话提取 / 位置服务 |
| favorite_singer | 周杰伦 | 对话提取 |
| pet | 猫叫奶茶 | 对话提取 |
| job | 产品经理 | 对话提取 |

## 关键逻辑
- **提取时机**: 每次对话结束后异步执行，不阻塞响应
- **去重**: 相同 key → 覆盖为新 value
- **容量控制**: 50 条上限 → LLM 压缩旧记忆
- **隐私**: 数据仅本地服务器
