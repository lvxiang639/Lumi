# UI Redesign: Virtual Anime Character & Navigation Restructure

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace static Live2D placeholder with Rive-animated Q-version anime character (mouth sync during TTS), consolidate navigation to single-screen chat + slide-out tools panel.

**Architecture:** Single-screen immersive chat with Rive character center stage. TTS playback progress drives Rive mouthOpen parameter via audioplayers position stream. Calendar and expense screens merge into a right-side EndDrawer panel with TabBar switching. Character settings move to AppBar popup menu. Existing backend APIs unchanged.

**Tech Stack:** Flutter 3.22+, Rive runtime (rive package), audioplayers 6.1+, provider 6.1+

---

### Task 1: Add Rive dependency and create assets directory

**Files:**
- Modify: `frontend/pubspec.yaml`
- Create: `frontend/assets/.gitkeep`

- [ ] **Step 1: Add rive package**

```bash
cd frontend && flutter pub add rive
```

Expected: `rive` added to `pubspec.yaml` dependencies and `pubspec.lock` updated.

- [ ] **Step 2: Create assets directory**

```bash
mkdir -p frontend/assets
touch frontend/assets/.gitkeep
```

- [ ] **Step 3: Register assets in pubspec.yaml**

Read `frontend/pubspec.yaml`, find the `flutter:` section, ensure it has:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/
```

Use Edit tool to add the `assets:` block if missing (only the `- assets/` line under `flutter:`).

- [ ] **Step 4: Commit**

```bash
cd frontend && git add pubspec.yaml pubspec.lock assets/
git commit -m "chore: add rive dependency and assets directory"
```

---

### Task 2: Add TTS playback position stream to TtsPlayerService

**Files:**
- Modify: `frontend/lib/services/tts_player_service.dart:1-68`

- [ ] **Step 1: Add position stream**

Replace the entire file content:

```dart
import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TtsPlayerService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  VoidCallback? onPlaybackDone;
  final List<Uint8List> _buffer = [];
  StreamSubscription<Duration>? _posSub;
  Duration _duration = Duration.zero;

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  bool get isPlaying => _isPlaying;
  Stream<double> get playbackProgress => _progressController.stream;

  TtsPlayerService() {
    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _progressController.add(0.0);
      onPlaybackDone?.call();
    });
    _player.onDurationChanged.listen((d) {
      _duration = d;
    });
  }

  void addChunk(Uint8List chunk) {
    _buffer.add(chunk);
  }

  Future<void> finishStream() async {
    if (_buffer.isEmpty) return;
    final totalSize = _buffer.fold<int>(0, (s, c) => s + c.length);
    final all = Uint8List(totalSize);
    var offset = 0;
    for (final chunk in _buffer) {
      all.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _buffer.clear();
    await _playBytes(all);
  }

  Future<void> _playBytes(Uint8List audioBytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/lingxi_tts.wav');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(audioBytes);
      await _player.stop();
      _posSub?.cancel();
      _isPlaying = true;
      onPlaybackDone?.call();
      await _player.play(DeviceFileSource(file.path));
      _posSub = _player.onPositionChanged.listen((pos) {
        if (_duration.inMilliseconds > 0) {
          _progressController.add(
              pos.inMilliseconds / _duration.inMilliseconds);
        }
      });
    } catch (e) {
      _isPlaying = false;
      _progressController.add(0.0);
      onPlaybackDone?.call();
      debugPrint('TTS play error: $e');
    }
  }

  Future<void> stop() async {
    _isPlaying = false;
    _buffer.clear();
    _posSub?.cancel();
    _progressController.add(0.0);
    onPlaybackDone?.call();
    await _player.stop();
  }

  void dispose() {
    _isPlaying = false;
    _buffer.clear();
    _posSub?.cancel();
    _progressController.close();
    _player.dispose();
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd frontend && git add lib/services/tts_player_service.dart
git commit -m "feat: add TTS playback progress stream for mouth sync"
```

---

### Task 3: Expose TTS playback progress from ChatProvider and add animation state

**Files:**
- Modify: `frontend/lib/providers/chat_provider.dart:1-132`

- [ ] **Step 1: Add playback progress stream and animation state to ChatProvider**

Replace the entire file content:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/ws_service.dart';
import '../services/tts_player_service.dart';

enum CharacterAnimState { idle, talking, dancing }

class ChatProvider extends ChangeNotifier {
  final WsService _ws = WsService();
  final TtsPlayerService _tts = TtsPlayerService();
  final List<Message> _messages = [];
  StreamSubscription<WsMessage>? _wsSubscription;
  StreamSubscription<double>? _ttsProgressSub;
  String _streamingText = "";
  bool _isProcessing = false;
  String? currentSkill;
  WsState _wsState = WsState.disconnected;
  CharacterAnimState _animState = CharacterAnimState.idle;
  double _mouthOpen = 0.0;

  List<Message> get messages => List.unmodifiable(_messages);
  String get streamingText => _streamingText;
  bool get isProcessing => _isProcessing;
  WsState get wsState => _wsState;
  bool get isTtsPlaying => _tts.isPlaying;
  CharacterAnimState get animState => _animState;
  double get mouthOpen => _mouthOpen;

  void stopTts() => _tts.stop();

  void setAnimState(CharacterAnimState state) {
    _animState = state;
    notifyListeners();
  }

  void startConversation({String? conversationId}) {
    _wsSubscription?.cancel();
    _ttsProgressSub?.cancel();
    _messages.clear();
    _streamingText = "";
    _ws.conversationId = conversationId;
    _ws.onStateChanged = (s) {
      _wsState = s;
      notifyListeners();
    };
    _tts.onPlaybackDone = () {
      _animState = CharacterAnimState.idle;
      _mouthOpen = 0.0;
      notifyListeners();
    };
    _ttsProgressSub = _tts.playbackProgress.listen((progress) {
      if (progress > 0 && progress < 1.0) {
        _animState = CharacterAnimState.talking;
        _mouthOpen = _mouthFromProgress(progress);
      } else {
        _mouthOpen = 0.0;
      }
      notifyListeners();
    });
    _wsSubscription = _ws.messages.listen(_onWsMessage);
    _ws.connect();
  }

  double _mouthFromProgress(double progress) {
    final t = progress * 10;
    final val = (t - t.floor()) < 0.4 ? 1.0 : 0.0;
    return val;
  }

  void sendText(String text) {
    _messages.add(Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user', type: 'text', content: text,
      createdAt: DateTime.now(),
    ));
    _isProcessing = true;
    _streamingText = "";
    notifyListeners();
    _ws.sendText(text);
  }

  void sendVoice(String base64Audio) {
    _messages.add(Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user', type: 'voice', content: '[语音消息]',
      createdAt: DateTime.now(),
    ));
    _isProcessing = true;
    _streamingText = "";
    notifyListeners();
    _ws.sendVoice(base64Audio);
  }

  void _onWsMessage(WsMessage msg) {
    switch (msg.type) {
      case 'asr_result':
        final text = msg.data['text'] as String;
        _messages.add(Message(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          role: 'user', type: 'text', content: text,
          createdAt: DateTime.now(),
        ));
        break;
      case 'llm_stream':
        _streamingText += msg.data['delta'] as String;
        break;
      case 'skill_call':
        currentSkill = msg.data['skill'] as String?;
        break;
      case 'tts_audio':
        final audioBase64 = msg.data['audio'] as String?;
        if (audioBase64 != null) {
          final bytes = base64Decode(audioBase64);
          _tts.addChunk(Uint8List.fromList(bytes));
          _tts.finishStream();
        }
        break;
      case 'tts_audio_chunk':
        final chunkBase64 = msg.data['chunk'] as String?;
        if (chunkBase64 != null) {
          _tts.addChunk(Uint8List.fromList(base64Decode(chunkBase64)));
        }
        break;
      case 'tts_audio_end':
        _tts.finishStream();
        break;
      case 'done':
        if (_streamingText.isNotEmpty) {
          _messages.add(Message(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            role: 'assistant', type: 'text', content: _streamingText,
            createdAt: DateTime.now(),
          ));
          _streamingText = "";
        }
        _isProcessing = false;
        currentSkill = null;
        if (msg.data['conversation_id'] != null) {
          _ws.conversationId = msg.data['conversation_id'] as String;
        }
        break;
    }
    notifyListeners();
  }

  Future<void> endConversation() async {
    _ttsProgressSub?.cancel();
    await _ws.disconnect();
    _messages.clear();
    _streamingText = "";
    _isProcessing = false;
    _animState = CharacterAnimState.idle;
    _mouthOpen = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _ttsProgressSub?.cancel();
    _tts.dispose();
    _ws.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd frontend && git add lib/providers/chat_provider.dart
git commit -m "feat: add TTS playback progress and character animation state to ChatProvider"
```

---

### Task 4: Create Rive-powered character view widget

**Files:**
- Create: `frontend/lib/widgets/character_view.dart`

- [ ] **Step 1: Search for a free Rive anime character file**

Use WebSearch to find free Rive community files for an anime chibi character. Search query: "rive community free anime chibi character .riv file". Download a suitable file and save to `frontend/assets/character.riv`.

If no free file is found, we will create a simple animated character using Flutter's built-in animation capabilities as fallback (Task 4b).

- [ ] **Step 2: Create the character view widget**

Write `frontend/lib/widgets/character_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class CharacterView extends StatefulWidget {
  final double mouthOpen;
  final String animState; // 'idle', 'talking', 'dancing'

  const CharacterView({
    super.key,
    this.mouthOpen = 0.0,
    this.animState = 'idle',
  });

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView> {
  StateMachineController? _controller;
  SMITrigger? _talkTrigger;
  SMITrigger? _danceTrigger;
  SMINumber? _mouthInput;

  void _onRiveInit(Artboard artboard) {
    _controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1',
      onStateChange: (name, state) {},
    );
    if (_controller != null) {
      artboard.addController(_controller!);
      _talkTrigger = _controller!.findInput<bool>('talk') as SMITrigger?;
      _danceTrigger = _controller!.findInput<bool>('dance') as SMITrigger?;
      _mouthInput = _controller!.findInput<double>('mouthOpen') as SMINumber?;
    }
  }

  @override
  void didUpdateWidget(covariant CharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _mouthInput?.value = widget.mouthOpen;

    if (widget.animState != oldWidget.animState) {
      switch (widget.animState) {
        case 'talking':
          _talkTrigger?.fire();
        case 'dancing':
          _danceTrigger?.fire();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RiveAnimation.asset(
      'assets/character.riv',
      fit: BoxFit.contain,
      onInit: _onRiveInit,
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
cd frontend && git add lib/widgets/character_view.dart assets/character.riv
git commit -m "feat: create Rive-powered character view widget"
```

---

### Task 5: Create tools panel widget (Calendar + Expense in slide-out drawer)

**Files:**
- Create: `frontend/lib/widgets/tools_panel.dart`

- [ ] **Step 1: Create the tools panel widget**

Write `frontend/lib/widgets/tools_panel.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/expense_provider.dart';
import '../models/calendar_event.dart';
import '../models/expense_record.dart';

class ToolsPanel extends StatefulWidget {
  const ToolsPanel({super.key});

  @override
  State<ToolsPanel> createState() => _ToolsPanelState();
}

class _ToolsPanelState extends State<ToolsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().loadEvents();
      context.read<ExpenseProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Text('助手工具',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: Colors.indigo,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: '📅 日历'),
                Tab(text: '💰 记账'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _CalendarTab(),
                  _ExpenseTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.events.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 80),
              Center(
                  child: Text('暂无提醒事件',
                      style: TextStyle(color: Colors.grey))),
            ],
          );
        }
        return ListView.builder(
          itemCount: provider.events.length,
          itemBuilder: (context, i) {
            final event = provider.events[i];
            final dt = event.time;
            return ListTile(
              leading: const Icon(Icons.event, color: Colors.indigo),
              title: Text(event.title),
              subtitle: Text(
                  '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => provider.deleteEvent(event.id),
              ),
            );
          },
        );
      },
    );
  }
}

class _ExpenseTab extends StatelessWidget {
  const _ExpenseTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        final totalExpense =
            (provider.stats?['total_expense'] as num?)?.toDouble() ?? 0.0;
        if (provider.records.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 80),
              const Center(
                  child: Text('暂无记账记录',
                      style: TextStyle(color: Colors.grey))),
              if (totalExpense > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text('本月支出: ¥${totalExpense.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.indigo)),
                  ),
                ),
            ],
          );
        }
        return ListView.builder(
          itemCount: provider.records.length,
          itemBuilder: (context, i) {
            final record = provider.records[i];
            final isExpense = record.amount > 0;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isExpense
                    ? Colors.red.shade100
                    : Colors.green.shade100,
                child: Text(record.category,
                    style: const TextStyle(fontSize: 12)),
              ),
              title: Text(
                  record.remark.isEmpty ? record.category : record.remark),
              subtitle: Text(_fmtDt(record.recordedAt)),
              trailing: Text(
                '${isExpense ? "-" : "+"}¥${record.amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  color: isExpense ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onLongPress: () => provider.delete(record.id),
            );
          },
        );
      },
    );
  }

  static String _fmtDt(DateTime dt) {
    final s = dt.toString();
    return s.length >= 16 ? s.substring(0, 16) : s;
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd frontend && git add lib/widgets/tools_panel.dart
git commit -m "feat: create tools panel with calendar and expense tabs"
```

---

### Task 6: Fix calendar service API URL

**Files:**
- Modify: `frontend/lib/services/calendar_service.dart:8`

The backend calendar list endpoint is `GET /api/calendar` but the frontend calls `/api/calendar/events`.

- [ ] **Step 1: Fix the API path**

```dart
// Change line 8 from:
final data = await _api.get('/api/calendar/events');
// To:
final data = await _api.get('/api/calendar');
```

- [ ] **Step 2: Commit**

```bash
cd frontend && git add lib/services/calendar_service.dart
git commit -m "fix: correct calendar API endpoint path"
```

---

### Task 7: Rewrite ChatScreen with new layout

**Files:**
- Modify: `frontend/lib/screens/chat_screen.dart:1-147`

- [ ] **Step 1: Replace ChatScreen with new immersive layout**

Write `frontend/lib/screens/chat_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/character_provider.dart';
import '../services/ws_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_record_button.dart';
import '../widgets/character_view.dart';
import '../widgets/tools_panel.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().startConversation();
      context.read<CharacterProvider>().loadConfig();
    });
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    context.read<ChatProvider>().sendText(text);
  }

  void _openTools() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _showCharacterMenu() {
    final provider = context.read<CharacterProvider>();
    final config = provider.config;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : config == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('尚未初始化角色',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            provider.initCharacter('小灵').then((_) {
                              Navigator.pop(ctx);
                            });
                          },
                          child: const Text('初始化默认角色'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              const CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.indigo,
                                  child:
                                      Icon(Icons.person, size: 36, color: Colors.white)),
                              const SizedBox(height: 8),
                              Text(config.name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  '服装: ${config.outfitName ?? "默认"} | 声音: ${config.voicePackName ?? "默认"}',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('服装',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        ...provider.outfits.map((o) => ListTile(
                              title: Text(o['name'] as String? ?? ''),
                              dense: true,
                              trailing: o['equipped'] == true
                                  ? const Text('使用中',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey))
                                  : TextButton(
                                      onPressed: () => provider.equip(
                                          'outfit', o['id'] as String),
                                      child: const Text('穿上',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                            )),
                        const Divider(),
                        const Text('声音',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        ...provider.voices.map((v) => ListTile(
                              title: Text(v['name'] as String? ?? ''),
                              subtitle:
                                  Text(v['type'] as String? ?? '',
                                      style: const TextStyle(fontSize: 12)),
                              dense: true,
                              trailing: v['equipped'] == true
                                  ? const Text('使用中',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey))
                                  : TextButton(
                                      onPressed: () => provider.equip(
                                          'voice_pack', v['id'] as String),
                                      child: const Text('使用',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                            )),
                      ],
                    ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: const Text('灵犀'),
            actions: [
              IconButton(
                icon: const Icon(Icons.build_outlined),
                tooltip: '工具',
                onPressed: _openTools,
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                tooltip: '角色',
                onPressed: _showCharacterMenu,
              ),
            ],
          ),
          endDrawer: const ToolsPanel(),
          body: Column(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.indigo.shade50,
                        Colors.white,
                      ],
                    ),
                  ),
                  child: CharacterView(
                    mouthOpen: chat.mouthOpen,
                    animState: chat.animState.name,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: chat.messages.length +
                            (chat.streamingText.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i < chat.messages.length) {
                            return ChatBubble(message: chat.messages[i]);
                          }
                          return ChatBubble(
                              isStreaming: true,
                              streamingText: chat.streamingText);
                        },
                      ),
                    ),
                    if (chat.wsState == WsState.connecting)
                      const LinearProgressIndicator(),
                    if (chat.isTtsPlaying)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.volume_up,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text('语音播报中…',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: chat.stopTts,
                              icon: const Icon(Icons.stop, size: 16),
                              label: const Text('取消',
                                  style: TextStyle(fontSize: 13)),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            VoiceRecordButton(
                              onAudioReady: (base64) {
                                context
                                    .read<ChatProvider>()
                                    .sendVoice(base64);
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                decoration: const InputDecoration(
                                  hintText: '输入消息...',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                onSubmitted: (_) => _sendText(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _sendText),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd frontend && git add lib/screens/chat_screen.dart
git commit -m "feat: redesign chat screen with character view, tools drawer, and character menu"
```

---

### Task 8: Simplify HomeScreen (remove bottom navigation)

**Files:**
- Modify: `frontend/lib/screens/home_screen.dart:1-42`

- [ ] **Step 1: Replace HomeScreen to just show ChatScreen**

Write `frontend/lib/screens/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatScreen();
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd frontend && git add lib/screens/home_screen.dart
git commit -m "refactor: simplify home screen to single-screen chat"
```

---

### Task 9: Remove old screen and widget files

**Files:**
- Remove: `frontend/lib/screens/calendar_screen.dart`
- Remove: `frontend/lib/screens/expense_screen.dart`
- Remove: `frontend/lib/screens/character_screen.dart`
- Remove: `frontend/lib/widgets/live2d_view.dart`
- Modify: `frontend/lib/app.dart:1-39` (remove unused provider registrations if any)

- [ ] **Step 1: Delete old files**

```bash
rm frontend/lib/screens/calendar_screen.dart
rm frontend/lib/screens/expense_screen.dart
rm frontend/lib/screens/character_screen.dart
rm frontend/lib/widgets/live2d_view.dart
```

- [ ] **Step 2: Verify no remaining imports of deleted files**

Run: `grep -rn "calendar_screen\|expense_screen\|character_screen\|live2d_view" frontend/lib/ --include="*.dart"`

Expected: no output (no remaining references).

- [ ] **Step 3: Update app.dart imports (clean up unused screen references)**

Read `frontend/lib/app.dart`. Remove unused import lines for the deleted screens. The file should become:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/character_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

class LingxiApp extends StatelessWidget {
  const LingxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => CharacterProvider()),
      ],
      child: MaterialApp(
        title: '灵犀',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isAuthenticated) return const HomeScreen();
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
```

(Note: app.dart actually already has the right content — just verify the removed screen imports are gone.)

- [ ] **Step 4: Commit**

```bash
cd frontend && git add lib/screens/ lib/widgets/ lib/app.dart
git commit -m "refactor: remove old screen files replaced by new design"
```

---

### Task 10: Verify the project builds and analyze

**Files:**
- None new

- [ ] **Step 1: Run Flutter analyze**

```bash
cd frontend && flutter analyze
```

Expected: No errors. Fix any issues if present.

- [ ] **Step 2: Run Flutter tests**

```bash
cd frontend && flutter test
```

Expected: All tests pass.

- [ ] **Step 3: Commit any fixes**

If analysis or tests required fixes, commit them.
