# 聊天回复质量 + 搜索优化

## Phase 1: 系统提示词重构 + 意图合并

### 1.1 意图分类合并到 system prompt
- 移除独立 `classify_intent` LLM 调用
- LLM 用 `[SEARCH:关键词]` `[CALENDAR:标题:时间]` 等标记声明需要技能
- 后端流式输出时检测标记，异步执行技能，注入结果
- 节省 1 次 LLM 调用，消除串行等待

### 1.2 系统提示词分层
```
[角色层] persona
[时间层] 当前时间 + 星期
[上下文层] 对话主题 + 最近关注
[记忆层] 语义匹配的 top-3 记忆
[行为指引] 简洁自然、语气风格、技能标记协议
```

### 1.3 记忆注入改为语义匹配
- 用户消息 → BGE-M3 embedding → FAISS 从记忆库取 top-3
- 替代"最后 5 条 + 关键词匹配"

### 1.4 情绪传递内联
- 不再单独调用 emotion LLM
- 在 system prompt 加一行: `用户最近情绪: {emotion}`（基于历史数据，不额外调用）

## Phase 2: 搜索增强

### 2.1 多数据源路由
| 查询类型 | 数据源 |
|---------|-------|
| 实时价格/股票 | Yahoo Finance API |
| 天气 | wttr.in |
| 新闻 | NewsAPI / SearXNG news |
| 通用搜索 | SearXNG + DuckDuckGo |
| 学术 | Google Scholar (SearXNG engine) |

### 2.2 搜索结果重排序
- 多引擎结果 → LLM 评分相关性 → 取 top-5 → 综合回答

## 实施顺序
1. 重构 system prompt 结构 + 合并意图分类
2. 实现技能标记协议 + 后端检测
3. 语义记忆匹配
4. 搜索多源路由
