# 语音对话全链路流程

本文档描述灵犀 App 中用户说一句话，到虚拟角色用语音回复的完整技术流程。

---

## 整体架构

```
┌── Flutter App（客户端）────────────────────────────────────────────────────────┐
│                                                                                │
│   [麦克风] ──▶ AudioRecorderService ──▶ base64 ──▶ WsService.sendVoice()      │
│                                                         │                      │
│                                                         │ WebSocket            │
│   [扬声器] ◀── TtsPlayerService ◀── Uint8List ◀── ChatProvider._onWsMessage() │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
                           │                              ▲
                           ▼                              │
┌── FastAPI（服务端）────────────────────────────────────────────────────────── │
│                                                                                │
│   ws_chat.py ──▶ process_voice() ──▶ ASRService ──▶ DashScope Qwen3-ASR      │
│                      │                                                         │
│                      ▼                                                         │
│                process_text() ──▶ LLMRouter ──▶ DeepSeek / Qwen               │
│                      │                                                         │
│                      ▼                                                         │
│                TTSService ──▶ DashScope Qwen3-TTS ──▶ 下载 WAV 音频           │
│                      │                                                         │
│                      ▼                                                         │
│                base64 编码 ──▶ WebSocket 返回客户端                            │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 一、App 端：录音与发送

### Step 1: 用户按下麦克风按钮

**文件：** `frontend/lib/widgets/voice_record_button.dart`

点击按钮触发 `_toggleRecording()`，状态切换（红/蓝），通过回调 `onRecordingChanged` 通知父组件录音开始/停止。

### Step 2: 录音采集

**文件：** `frontend/lib/services/audio_recorder_service.dart`

```dart
final stream = await _recorder.startStream(
  const RecordConfig(encoder: AudioEncoder.wav),
);
```

- 使用 Flutter `record` 插件调用系统麦克风
- 编码格式：**WAV**（16kHz 采样率，单声道）
- 输出：`Stream<Uint8List>` 原始音频字节流

### Step 3: Base64 编码 + WebSocket 发送

**文件：** `frontend/lib/services/ws_service.dart`

```dart
void sendVoice(String base64Audio) {
  _channel?.sink.add(jsonEncode({
    'type': 'voice',
    'audio': base64Audio,
    'conversation_id': conversationId,
  }));
}
```

录音停止后，音频字节通过 Dart 的 `base64Encode()` 转为 base64 字符串，封装为 JSON 通过 WebSocket 发送：

```json
{
  "type": "voice",
  "audio": "UklGRiRAAABXQVZFZm10...",
  "conversation_id": "c5a3ff06-..."
}
```

---

## 二、服务端：语音识别（ASR）

### Step 4: WebSocket 路由分发

**文件：** `backend/app/api/ws_chat.py`

```python
elif msg_type == "voice":
    await chat_orchestrator.process_voice(
        user_id, data["audio"], data.get("conversation_id"), db, send_message
    )
```

根据 `type: "voice"` 路由到 `process_voice()`。

### Step 5: 调用 DashScope ASR

**文件：** `backend/app/services/chat_orchestrator.py` → `backend/app/services/asr_service.py`

```python
# orchestrator 调用
text = await asr_service.transcribe(audio_base64)

# ASRService 实现
response = dashscope.MultiModalConversation.call(
    model="qwen3-asr-flash",
    api_key=settings.qwen_api_key,
    messages=[{
        "role": "user",
        "content": [{"audio": f"data:audio/wav;base64,{audio_base64}"}],
    }],
    result_format="message",
)
# 提取识别文本
text = response.output["choices"][0]["message"]["content"][0]["text"]
```

- 使用阿里云百炼 **DashScope SDK**
- 模型：`qwen3-asr-flash`（中文错误率 3.97%，支持方言和多语言）
- 音频格式：`data:audio/wav;base64,<base64>` 数据 URI

### Step 6: 返回识别结果给 App

```json
{"type": "asr_result", "text": "今天天气怎么样"}
```

`ChatProvider._onWsMessage()` 收到 `asr_result` 后，在消息列表中添加一条用户消息（内容为识别出的文本），UI 即时显示。

---

## 三、服务端：对话处理（LLM）

### Step 7: 意图分类

**文件：** `backend/app/services/llm_service.py`

```python
intent = await llm_router.classify_intent(text)
# 返回: chat | search | weather | calendar | expense
```

用 DeepSeek 分析用户输入意图，决定走技能插件还是通用对话。

### Step 8a: 技能执行（非闲聊意图）

```python
skill = skill_registry.get(intent)
result = await skill.execute(user_id, text, db)
response_text = result.text  # 如："北京当前温度20度，Partly Cloudy"
```

已实现的技能：`weather`（wttr.in）、`search`（SearXNG）、`calendar`、`expense`。

### Step 8b: LLM 流式对话（闲聊意图）

**文件：** `backend/app/services/llm_service.py`

```python
async for delta in llm_router.chat_stream(llm_messages):
    full_response += delta
    await send_message({"type": "llm_stream", "delta": delta})
```

- 取最近 20 条历史消息作为上下文
- 默认使用 **DeepSeek** 模型，可通过 `force_model="qwen"` 切换到 Qwen
- 使用 OpenAI 兼容的流式 API，逐 token 返回

### Step 9: 持久化消息

```python
# 保存用户消息和助手回复到 PostgreSQL
assistant_msg = Message(conv_id=conv.id, role=MessageRole.assistant, ...)
db.add(assistant_msg)
conv.updated_at = datetime.now(timezone.utc)
await db.commit()
```

### Step 10: 流式文本推送到 App

服务端逐 token 推送：

```json
{"type": "llm_stream", "delta": "今天"}
{"type": "llm_stream", "delta": "北京"}
{"type": "llm_stream", "delta": "天气"}
...
```

Flutter 端 `ChatProvider._onWsMessage()` 收到 `llm_stream` 后追加到 `_streamingText`，`ChatBubble` widget 实时渲染打字效果。

---

## 四、服务端：语音合成（TTS）

### Step 11: 调用 DashScope TTS

**文件：** `backend/app/services/tts_service.py`

```python
response = dashscope.MultiModalConversation.call(
    model="qwen3-tts-flash",
    api_key=settings.qwen_api_key,
    text=response_text,        # LLM 生成的完整回复文本
    voice="Cherry",            # 音色，可通过角色声音包切换
    language_type="Chinese",
    stream=False,
)
# 获取音频下载 URL
audio_url = response.output["audio"]["url"]
# 下载 WAV 字节
audio_bytes = await httpx_client.get(audio_url)
```

- 模型：`qwen3-tts-flash`（首包延迟 97ms，17 种预设音色）
- 声音包系统通过 `voice` 参数切换不同角色音色
- 高级场景走 CosyVoice 实现声音克隆

### Step 12: 返回音频给 App

```python
await send_message({
    "type": "tts_audio",
    "audio": base64.b64encode(audio_bytes).decode(),
    "text": response_text,
})
```

将 WAV 字节进行 base64 编码，封装为 JSON 返回：

```json
{
  "type": "tts_audio",
  "audio": "UklGRiRA...",
  "text": "今天北京天气晴朗，温度20度"
}
```

### Step 13: 对话结束信号

```json
{"type": "done", "conversation_id": "c5a3ff06-096f-4cf3-b3ab-e42528206d9a"}
```

---

## 五、App 端：播放音频

### Step 14: 接收 TTS 消息

**文件：** `frontend/lib/providers/chat_provider.dart`

```dart
case 'tts_audio':
    // 解码 base64 → Uint8List → 播放
    final audioBase64 = msg.data['audio'] as String;
    final audioBytes = base64Decode(audioBase64);
    _ttsPlayer.play(audioBytes);
    break;
```

当前代码中 `tts_audio` 分支是空的（`break;` 直接跳过）。需要集成 `TtsPlayerService`：

### Step 15: 音频播放

**文件：** `frontend/lib/services/tts_player_service.dart`

```dart
Future<void> play(Uint8List audioBytes) async {
    await _player.play(BytesSource(audioBytes));
}
```

- 使用 Flutter `audioplayers` 插件
- `BytesSource` 直接从内存播放，无需写入临时文件
- 系统自动通过扬声器/耳机输出

---

## 完整时序图

```
  Flutter App                     FastAPI Backend                DashScope / LLM
  ──────┬────                      ──────┬────                    ──────┬────
       │                                 │                              │
       │ 1. 麦克风录音 WAV                │                              │
       │                                 │                              │
       │ 2. WS: {"type":"voice",         │                              │
       │    "audio":"base64..."} ───────►│                              │
       │                                 │ 3. ASR API call              │
       │                                 │    (qwen3-asr-flash) ───────►│
       │                                 │   ◄── 识别结果文本 ──────────│
       │                                 │                              │
       │ ◄── {"type":"asr_result",       │                              │
       │     "text":"今天天气怎样"}       │                              │
       │                                 │ 4. 意图分类 (DeepSeek) ────►│
       │                                 │   ◄── "weather" ────────────│
       │                                 │                              │
       │                                 │ 5. 技能执行 (wttr.in)        │
       │                                 │                              │
       │ ◄── {"type":"skill_call",       │                              │
       │     "skill":"weather"}          │                              │
       │ ◄── {"type":"llm_stream",       │                              │
       │     "delta":"北京当前..."}       │                              │
       │                                 │ 6. TTS API call              │
       │                                 │    (qwen3-tts-flash) ───────►│
       │                                 │   ◄── 音频 URL ─────────────│
       │                                 │ 7. 下载 WAV 音频             │
       │                                 │                              │
       │ ◄── {"type":"tts_audio",        │                              │
       │     "audio":"base64..."}        │                              │
       │ ◄── {"type":"done"}             │                              │
       │                                 │                              │
       │ 8. 解码 base64 → 扬声器播放     │                              │
       │                                 │                              │
```

---

## 当前实现状态

| 步骤 | 状态 | 说明 |
|------|:--:|------|
| 1-2. 录音 + 发送 | ⚠️ 已实现但未集成 | `AudioRecorderService` 已写好，`VoiceRecordButton` 的回调未对接 |
| 3-6. ASR 识别 | ✅ 已联调 | DashScope SDK 调用正常，识别文本正确回传 |
| 7-10. LLM 对话 | ✅ 已联调 | 流式输出正常，意图分类正常 |
| 11-12. TTS 合成 | ✅ 已联调 | DashScope SDK 调用正常，169KB 音频测试通过 |
| 13-14. 音频播放 | ⚠️ 已实现但未集成 | `TtsPlayerService` 已写好，`ChatProvider` 中 `tts_audio` case 为空白 |
| 端侧 ASR 兜底 | ⏳ 预留 | `asr_local_service.dart` 占位，后续集成 whisper.cpp |

### 待补全的集成点

1. **录音按钮对接** — `VoiceRecordButton` 需要在 `onRecordingChanged` 回调中调用 `AudioRecorderService`，停止后将音频 base64 传给 `WsService.sendVoice()`
2. **TTS 播放对接** — `ChatProvider._onWsMessage()` 的 `tts_audio` 分支需要调用 `TtsPlayerService.play()` 播放收到的音频
