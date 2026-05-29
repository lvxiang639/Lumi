# UI Redesign: Virtual Anime Character & Navigation Restructure

**Date:** 2026-05-29
**Status:** Approved

## Motivation

Current UI issues:
1. Live2D is a static placeholder image — no animation, no interactivity
2. Bottom nav has 4 tabs (对话/日历/记账/角色) — 日历 and 记账 are low-frequency tools that waste prime navigation space
3. During TTS voice playback, the character doesn't react visually
4. Overall design feels bare-bones

## Design Decisions

### 1. Navigation: Single-Screen Immersive Chat + Side Panel

Remove bottom navigation bar entirely. Chat becomes the only main screen. Calendar and Expense tools move to a slide-out side panel accessible from the AppBar.

**AppBar:**
- Left: App title "灵犀"
- Right: Tools button (🔧) → opens right-side panel; Avatar button → opens character/settings menu

**Why:** The virtual character is the soul of the app. Full-screen immersive chat gives it center stage. Calendar/expense are occasional tools — available on demand without stealing screen real estate.

### 2. Character Animation: Rive Engine

Use **Rive** (rive.app) for all character animation.

**Why Rive over alternatives:**
- Real-time parameter control: can drive `mouthOpen` (0→1) directly from TTS playback state
- State machine: Idle ↔ Talking ↔ Dancing with smooth transitions
- Pure Dart/Flutter — no native bridge, works on all platforms
- Open source, free runtime
- Small file sizes (tens of KB vs MB for Lottie/Live2D)

**Character style:** Q-version / Chibi (big head, small body, expressive features)

**Animation states:**
| State | Trigger | Description |
|-------|---------|-------------|
| Idle | Default | Gentle breathing/swaying, occasional blink |
| Talking | TTS playing | Mouth open/close synced to audio playback, subtle head tilt |
| Dancing | User command or periodic | Full body spin/dance, fun bouncy animation |

**Mouth sync approach:**
- TTS playback progress (0.0 → 1.0) drives a cyclic mouthOpen parameter
- Simple sine wave or audio-volume-based approach:
  - Divide playback into time windows (~100ms)
  - Alternate `mouthOpen` between 0 (closed) and 1 (open) at speech-like cadence
  - Rive blends smoothly between values

### 3. Tools Panel: Tab-based Side Sheet

A right-side slide-out panel (≈80% screen width) with:

- **Header:** "助手工具" title + close button
- **Tab bar:** 📅 日历 | 💰 记账
- **Overview card:** Today's event count + today's expense total (shown in both tabs)
- **List area:** Scrollable list of events or expenses
- **Add button:** FAB or inline button to create new event/expense

**Panel behavior:**
- Triggered by AppBar 🔧 button
- Slides in from right with semi-transparent backdrop
- Default shows the last-used tab, or Calendar tab on first open
- Closeable via ✕ button, backdrop tap, or swipe-right gesture

### 4. Character Settings

Moved from a dedicated bottom tab into:
- AppBar avatar button → popup menu or bottom sheet with outfit/voice pack selection
- Or accessible from the side panel's "设置" tab

## File Changes Required

### New Files
| File | Purpose |
|------|---------|
| `frontend/lib/widgets/character_view.dart` | Rive-powered character widget replacing `live2d_view.dart` |
| `frontend/lib/widgets/tools_panel.dart` | Side panel with Calendar/Expense tabs |
| `frontend/lib/models/character_animation.dart` | Animation state model (idle/talking/dancing) |
| `frontend/assets/character.riv` | Rive character file (to source/create) |

### Modified Files
| File | Change |
|------|--------|
| `frontend/lib/screens/home_screen.dart` | Remove bottom nav, single-screen layout |
| `frontend/lib/screens/chat_screen.dart` | Integrate character view + tools panel, new layout |
| `frontend/lib/providers/chat_provider.dart` | Expose TTS playback state for mouth sync |
| `frontend/lib/services/tts_player_service.dart` | Add playback progress callback |
| `frontend/lib/app.dart` | Adjust theme if needed |

### Removed
| File | Reason |
|------|--------|
| `frontend/lib/screens/calendar_screen.dart` | Merged into tools panel |
| `frontend/lib/screens/expense_screen.dart` | Merged into tools panel |
| `frontend/lib/screens/character_screen.dart` | Moved to avatar menu/sheet |
| `frontend/lib/widgets/live2d_view.dart` | Replaced by character_view.dart |

### Backend
No backend changes needed. Existing APIs for calendar, expenses, TTS, and character config remain unchanged.

## Layout Structure (ChatScreen)

```
┌──────────────────────────┐
│ AppBar: 灵犀    [🔧][👤] │
├──────────────────────────┤
│                          │
│    ┌─────────────────┐   │
│    │                 │   │
│    │  Character View │   │
│    │  (Rive Animation)│   │
│    │                 │   │
│    └─────────────────┘   │
│     speech bubble ↑      │
├──────────────────────────┤
│  Chat messages list      │
│  (flexible, scrollable)  │
├──────────────────────────┤
│  TTS status indicator    │
├──────────────────────────┤
│ [🎤] [Input field] [➤]  │
└──────────────────────────┘
```

## Implementation Order

1. **Rive character widget** — core visual feature, unblocks everything
2. **TTS mouth sync** — wire playback progress to Rive parameters
3. **Navigation restructure** — remove bottom bar, single-screen chat
4. **Tools panel** — side sheet with calendar + expense tabs
5. **Character settings** — avatar menu integration
6. **Polish** — animations, transitions, visual refinements

## Out of Scope

- Creating a custom Rive character from scratch (use existing free resource or simple built-in character first)
- Live2D SDK integration
- Backend changes
- Shop screen redesign
