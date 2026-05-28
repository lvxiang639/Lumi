# Skill 插件系统

## 整体架构

```
用户消息（文本）
      │
      ▼
┌─────────────────────────────┐
│  ChatOrchestrator            │
│  process_text()              │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  LLMRouter.classify_intent() │  ← DeepSeek 分类
│  返回: chat|search|weather   │
│        calendar|expense      │
└──────────────┬──────────────┘
               │
        ┌──────┴──────┐
        │              │
   intent != "chat"    intent == "chat"
   且 registry 有注册    或未知意图
        │              │
        ▼              ▼
┌──────────────┐  ┌──────────────┐
│  Skill 执行   │  │  LLM 对话流   │
│  (各 skill    │  │  (带历史记录  │
│   execute())  │  │   流式输出)   │
└──────┬───────┘  └──────┬───────┘
       │                 │
       └────────┬────────┘
                ▼
    ┌─────────────────────┐
    │  保存消息到 DB       │
    │  TTS 语音合成        │
    │  发送 done 信号      │
    └─────────────────────┘
```

## 意图分类

`LLMRouter.classify_intent()` 调用 DeepSeek 模型，根据以下 prompt 返回单一标签：

| 标签 | 含义 | 处理方式 |
|------|------|----------|
| `chat` | 普通闲聊 | LLM 对话（带20条历史） |
| `search` | 搜索信息 | SearchSkill |
| `weather` | 查询天气 | WeatherSkill |
| `calendar` | 日历提醒 | CalendarSkill |
| `expense` | 记账 | ExpenseSkill |

分类失败时默认回退为 `chat`。

## Skill 注册机制

所有 skill 在 `SkillRegistry` 中以字典硬编码注册：

```python
# backend/app/services/skill_registry.py
self._skills = {
    "weather": weather_skill,
    "calendar": calendar_skill,
    "expense": expense_skill,
    "search": search_skill,
}
```

每个 skill 必须实现 `BaseSkill` 抽象类：

```python
class BaseSkill(ABC):
    name: str = ""

    @abstractmethod
    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        ...
```

`SkillResult` 包含 `text: str`（回复文本）和 `data: dict`（结构化数据）。

## 各 Skill 详细流程

---

### 1. 天气查询 — WeatherSkill

**文件:** `backend/app/services/skills/weather.py`

**流程:**

```
用户输入（例："今天北京天气怎么样"）
      │
      ▼
┌─────────────────────────────┐
│  _extract_city()            │
│  调 LLM 提取城市名           │
│  → {"city": "Beijing"}      │
│  提取失败默认 "Beijing"      │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  HTTP GET                    │
│  {weather_api_url}/{city}    │
│  ?format=j1                  │
│  (wttr.in 兼容 API)          │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  解析 current_condition[0]   │
│  - temp_C（温度）            │
│  - weatherDesc（天气描述）    │
│  - humidity（湿度）          │
│  - FeelsLikeC（体感温度）    │
└──────────────┬──────────────┘
               │
               ▼
      返回 SkillResult(
        text="北京当前温度25度，晴，湿度60%，体感温度26度",
        data={city, temp, desc, humidity}
      )
```

**外部依赖:** `settings.weather_api_url`（wttr.in 兼容接口）

---

### 2. 网页搜索 — SearchSkill

**文件:** `backend/app/services/skills/search.py`

**流程:**

```
用户输入（例："帮我搜索一下Python最新版本"）
      │
      ▼
┌─────────────────────────────┐
│  _extract_query()            │
│  调 LLM 提取搜索关键词        │
│  去掉"搜索一下""帮我查"等前缀  │
│  → {"query": "Python最新版本"}│
│  提取失败用原始输入            │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  HTTP GET                    │
│  {searxng_url}/search        │
│  ?q=Python最新版本            │
│  &format=json                │
│  &engines=...                │
│  (SearXNG 搜索引擎聚合)       │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  取前5条结果                  │
│  _summarize()                │
│  调 LLM 总结为1-2句话         │
└──────────────┬──────────────┘
               │
               ▼
      返回 SkillResult(
        text="Python最新稳定版本是3.12.4...",
        data={query, results}
      )
```

**外部依赖:** `settings.searxng_url` + `settings.searxng_engines`（自部署 SearXNG 实例）

---

### 3. 日历提醒 — CalendarSkill

**文件:** `backend/app/services/skills/calendar_skill.py`

**流程:**

```
用户输入（例："每周一早上9点开站会"）
      │
      ▼
┌─────────────────────────────┐
│  调 LLM 提取结构化信息        │
│  提供当前北京时间（含星期）    │
│  → {                         │
│      "title": "站会",        │
│      "time": "2026-06-01T09:00:00+08:00",│
│      "repeat_rule": "weekly" │
│    }                         │
└──────────────┬──────────────┘
               │
        ┌──────┴──────┐
        │ 缺少字段？    │
        │ 是 → 返回提示  │  "没能理解提醒时间，请再说一遍"
        │ 否 → 继续     │
        └──────┬──────┘
               │
               ▼
┌─────────────────────────────┐
│  验证 repeat_rule            │
│  none|daily|weekly|         │
│  monthly|yearly             │
│  无效默认 "none"              │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  写入 CalendarEvent 表       │
│  - user_id（当前用户）        │
│  - title（事件标题）          │
│  - time（提醒时间）           │
│  - repeat_rule（重复规则）    │
└──────────────┬──────────────┘
               │
               ▼
      返回 SkillResult(
        text="已添加日历提醒：站会，时间06月01日 09:00，每周重复",
        data={event_id}
      )
```

**外部依赖:** 无，纯本地数据库操作

---

### 4. 记账 — ExpenseSkill

**文件:** `backend/app/services/skills/expense_skill.py`

**流程:**

```
用户输入（例："午饭花了50块"）
      │
      ▼
┌─────────────────────────────┐
│  调 LLM 提取结构化信息        │
│  提供当前北京时间             │
│  → {                         │
│      "amount": 50.0,        │
│      "category": "餐饮",     │
│      "remark": "午饭",       │
│      "recorded_at": null    │
│    }                         │
└──────────────┬──────────────┘
               │
        ┌──────┴──────┐
        │ 金额有效？    │
        │ 否 → 返回提示  │
        │ 是 → 继续     │
        └──────┬──────┘
               │
               ▼
┌─────────────────────────────┐
│  金额规则:                    │
│  - 正数 = 支出               │
│  - 负数 = 收入               │
│  分类预设:                    │
│  餐饮|交通|购物|娱乐|         │
│  住房|医疗|教育|其他          │
│  无效分类 → "其他"             │
│  无时间 → 当前北京时间         │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  写入 ExpenseRecord 表       │
│  - user_id（当前用户）        │
│  - amount（金额，正=支出）    │
│  - category（分类）          │
│  - remark（备注）            │
│  - recorded_at（记账时间）    │
└──────────────┬──────────────┘
               │
               ▼
      返回 SkillResult(
        text="已记录：支出 餐饮 50.00元，备注：午饭",
        data={id, amount, category}
      )
```

**外部依赖:** 无，纯本地数据库操作

---

### 5. 普通对话 — Chat（非 Skill）

**文件:** `backend/app/services/chat_orchestrator.py` 内联处理

**流程:**

```
用户输入
      │
      ▼
┌─────────────────────────────┐
│  加载最近 20 条对话历史       │
│  (Message 表，按时间排序)     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  LLM 流式对话                │
│  默认 DeepSeek              │
│  可通过 force_model 切 Qwen  │
└──────────────┬──────────────┘
               │
               ▼
      逐 token 推送 llm_stream
      收集完整回复文本
      保存到 Message 表
```

**外部依赖:** DeepSeek API / Qwen API

---

## 通用工具

### parse_json() — JSON 提取

**文件:** `backend/app/services/skills/utils.py`

所有 skill 共用，从 LLM 输出中提取 JSON，依次尝试三种策略：

1. 直接 `json.loads()` — 输出已是干净 JSON
2. 提取 markdown 代码块 — ` ```json{...}``` `
3. 正则匹配第一个 `{...}` 块

三种都失败返回空 `{}`。

---

## 消息流转总结

```
WebSocket 消息                                    WebSocket 消息
（客户端 → 服务端）                                （服务端 → 客户端）
                                                  
{type: "text",         ──────────────────→        {type: "skill_call",
 content: "今天天气"}                                skill: "weather",
                                                    status: "done"}
                                                  
                                                   {type: "llm_stream",
                                                    delta: "北京当前温度..."}
                                                  
                                                   {type: "tts_audio",
                                                    audio: "<base64>"}
                                                  
                                                   {type: "done",
                                                    conversation_id: "..."}
```

## 扩展新 Skill

1. 创建 `backend/app/services/skills/xxx_skill.py`
2. 实现 `BaseSkill`，定义 `name` 和 `execute()` 方法
3. 在 `skill_registry.py` 中导入并注册
4. 在 `llm_service.py` 的 `classify_intent()` prompt 中添加新标签
