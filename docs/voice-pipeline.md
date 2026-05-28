# 语音对话全链路流程

## 整体架构

```
┌── Flutter App（客户端）─────────────────────────────────────────────────────┐
│                                                                             │
│  [麦克风] → AudioRecorderService(wav) → base64 → WsService.sendVoice()     │
│                                                     │                       │
│                                                     │ WebSocket             │
│  [扬声器] ← TtsPlayerService ← bytes ← ChatProvider._onWsMessage()         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                          │                            ▲
                          ▼                            │
┌── FastAPI（服务端）─────────────────────────────────────────────────────────┐
│                                                                             │
│  ws_chat.py → process_voice() → ASRService → DashScope qwen3-asr-flash    │
│                     │                                                       │
│                     ▼                                                       │
│               process_text() → LLMRouter → deepseek-v4-flash / qwen-plus  │
│                     │                                                       │
│                     ▼                                                       │
│               查 Character.voice_pack (selectinload) → TTSService          │
│                     │                                    │                  │
│                     │                                    ├── qwen3-tts-flash│
│                     │                                    └── CosyVoice      │
│                     ▼                                                       │
│               base64 → WebSocket → 客户端                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 一、客户端：录音与发送

### Step 1: 用户按下麦克风按钮

**文件：** `frontend/lib/widgets/voice_record_button.dart`

点击切换录音状态（红/蓝），通过 `onAudioReady` 回调传递 base64 音频数据。

### Step 2: 录音采集

**文件：** `frontend/lib/services/audio_recorder_service.dart`

```dart
await _recorder.start(
  const RecordConfig(encoder: AudioEncoder.wav),
  path: _currentPath!,
);
```

- 使用 Flutter `record` 插件
- 编码格式：**WAV**（与后端 ASR 服务期望一致）
- **不支持 Web 平台**，需用 `flutter run -d macos` 或 `-d ios`

### Step 3: Base64 编码 + WebSocket 发送

```dart
final bytes = await file.readAsBytes();
final base64 = base64Encode(bytes);
widget.onAudioReady!(base64);
```

发送 JSON：
```json
{"type": "voice", "audio": "<base64 wav>", "conversation_id": "xxx"}
```

---

## 二、服务端：语音识别（ASR）

### Step 4: WebSocket 路由分发

**文件：** `backend/app/api/ws_chat.py`

`type: "voice"` → `chat_orchestrator.process_voice()`

### Step 5: DashScope ASR

**文件：** `backend/app/services/asr_service.py`

```python
response = dashscope.MultiModalConversation.call(
    model="qwen3-asr-flash",
    messages=[{
        "role": "user",
        "content": [{"audio": f"data:audio/wav;base64,{audio_base64}"}],
    }],
    result_format="message",
)
text = response.output["choices"][0]["message"]["content"][0]["text"]
```

- 使用阿里云百炼 **DashScope SDK**
- 模型：`qwen3-asr-flash`（中文错误率 3.97%）
- 音频格式：`data:audio/wav;base64,...`

### Step 6: 返回识别结果

```json
{"type": "asr_result", "text": "今天天气怎么样"}
```

---

## 三、服务端：对话处理

### Step 7: 意图分类

**文件：** `backend/app/services/llm_service.py:classify_intent()`

```python
intent = await llm_router.classify_intent(text)
# 返回: chat | search | weather | calendar | expense
```

模型：`deepseek-v4-flash`，`max_tokens=10`。

### Step 8a: 技能执行

```python
skill = skill_registry.get(intent)
result = await skill.execute(user_id, text, db)
response_text = result.text
```

四种技能均含 LLM 结构化提取（JSON prompt 使用 `{{ }}` 转义避免 `str.format()` 冲突）。

### Step 8b: LLM 流式对话

```python
async for delta in llm_router.chat_stream(llm_messages):
    full_response += delta
    await send_message({"type": "llm_stream", "delta": delta})
```

- 取最近 20 条历史消息作为上下文
- 模型：`deepseek-v4-flash`
- OpenAI 兼容流式 API，逐 token 推送

### Step 9: 持久化

```python
assistant_msg = Message(conv_id=conv.id, role=MessageRole.assistant, ...)
db.add(assistant_msg)
conv.updated_at = datetime.now(timezone.utc)
await db.commit()
```

---

## 四、服务端：语音合成（TTS）

### Step 10: 查找角色声音包

**文件：** `backend/app/services/chat_orchestrator.py:_get_character_voice()`

```python
result = await db.execute(
    select(Character)
    .where(Character.user_id == user_uuid)
    .options(selectinload(Character.voice_pack))  # 预加载，避免 MissingGreenlet
)
char = result.scalar_one_or_none()
if char and char.voice_pack:
    voice = char.voice_pack.cosyvoice_id
```

关键：使用 `selectinload` 预加载关联对象，否则 SQLAlchemy async 模式下 lazy load 会报 `MissingGreenlet`。

### Step 11: TTS 调用

**文件：** `backend/app/services/tts_service.py`

```python
# 默认路径 — qwen3-tts-flash
audio_bytes = await tts_service.synthesize_flash(
    response_text, voice=voice  # 来自 VoicePack.cosyvoice_id 或默认 "Cherry"
)

# 角色定制路径 — CosyVoice（需配置 cosyvoice_endpoint）
audio_bytes = await tts_service.synthesize_cosyvoice(
    response_text, cosyvoice_id
)
```

### Step 12: 返回音频 + 结束信号

```json
{"type": "tts_audio", "audio": "<base64>", "text": "语音文本"}
{"type": "done", "conversation_id": "xxx"}
```

---

## 五、客户端：播放音频

### Step 13: 接收并播放

**文件：** `frontend/lib/providers/chat_provider.dart` + `frontend/lib/services/tts_player_service.dart`

```dart
case 'tts_audio':
    final bytes = base64Decode(msg.data['audio']);
    _tts.play(Uint8List.fromList(bytes));
```

`BytesSource` 直接从内存播放，无需临时文件。

---

## 完整时序图

```
  Flutter App               FastAPI Backend              DashScope / LLM
  ──────┬──                      ──────┬──                  ──────┬──
       │                               │                          │
       │ 1. 麦克风录音 WAV              │                          │
       │ 2. WS: {"type":"voice",       │                          │
       │    "audio":"base64..."} ─────►│                          │
       │                               │ 3. ASR (qwen3-asr-flash)►│
       │                               │   ◄── 识别文本 ──────────│
       │ ◄── {"type":"asr_result"}     │                          │
       │                               │ 4. 意图分类 (deepseek) ─►│
       │                               │   ◄── "weather" ────────│
       │                               │ 5. LLM 提取城市 ────────►│
       │                               │   ◄── "上海" ───────────│
       │                               │ 6. wttr.in 查询          │
       │ ◄── {"type":"skill_call"}     │                          │
       │ ◄── {"type":"llm_stream"}     │                          │
       │                               │ 7. 查 Character.voice    │
       │                               │    (selectinload 预加载)  │
       │                               │ 8. TTS (qwen3-tts-flash)►│
       │                               │   ◄── 音频 URL ─────────│
       │                               │ 9. 下载 WAV              │
       │ ◄── {"type":"tts_audio"}      │                          │
       │ ◄── {"type":"done"}           │                          │
       │                               │                          │
       │ 10. base64 解码 → 扬声器播放  │                          │
```

---

## 实现状态

| 步骤 | 状态 | 说明 |
|------|:--:|------|
| 1-2. 录音 + 发送 | ✅ | WAV 格式（`AudioEncoder.wav`），Web 平台不支持 |
| 3-6. ASR 识别 | ✅ | DashScope SDK，qwen3-asr-flash |
| 7. 意图分类 | ✅ | deepseek-v4-flash，五分类 |
| 8a. 技能执行 | ✅ | 四种技能含 LLM 结构化提取 + DB 写入 |
| 8b. LLM 流式对话 | ✅ | deepseek-v4-flash 流式，20 条历史上下文 |
| 10. 角色音色切换 | ✅ | selectinload 预加载 VoicePack，避免 MissingGreenlet |
| 11-12. TTS 合成 | ✅ | qwen3-tts-flash 默认 / CosyVoice 角色定制 |
| 13. 音频播放 | ✅ | base64 解码 → BytesSource → audioplayers |
| 日历提醒通知 | ✅ | 后台每 60s 轮询，标记到期事件 |
| 搜索 | ✅ | LLM 提取词 → SearXNG(Google+Bing+百度) → LLM 总结 |
| 端侧 ASR | ⏳ | `asr_local_service.dart` 占位，后续集成 whisper.cpp |
