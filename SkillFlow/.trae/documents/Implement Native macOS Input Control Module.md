# Implementation Plan: Native macOS Input Control Module with Debug View

I will implement a robust, asynchronous input control module and a companion debug view to test its capabilities.

## Directory Structure
I will create a new group `Services/InputControl`:
- `SkillFlow/Services/InputControl/InputControlService.swift`: Main actor class handling input logic.
- `SkillFlow/Services/InputControl/InputModels.swift`: Data models and KeyCode enums.
- `SkillFlow/Views/InputControlDebugView.swift`: A SwiftUI view for testing the module.

## Technical Implementation

### 1. Data Models (`InputModels.swift`)
- **`InputContext`**: Struct containing:
  - `activeWindowTitle: String?`: Title of the focused window.
  - `mousePosition: CGPoint`: Current global coordinates.
- **`KeyCode` & `MouseButton` Enums**: Mapping for easy API usage.

### 2. Input Control Service (`InputControlService.swift`)
- **Type**: `actor` (Async & Thread-safe).
- **State Tracking**: `pressedKeys` and `pressedButtons` sets.
- **API**:
  - `move_mouse(x, y)`
  - `mouse_down/up(button)`
  - `key_press/release(key)`
  - `delay(ms)`
  - `all_release()`
  - `getCurrentContext() -> InputContext`

### 3. Debug View (`InputControlDebugView.swift`)
- A SwiftUI view containing:
  - **Status Panel**: Real-time display of Mouse Position and Active Window Title.
  - **Control Panel**: Buttons to trigger:
    - Move Mouse to center.
    - Left/Right Click.
    - Type a test string.
    - Hold Shift + Click (Superimposable test).
    - Release All.
  - **Auto-Refresh**: A timer to update the context display periodically.

## Verification
- The `InputControlDebugView` itself serves as the verification tool, allowing manual testing of all implemented functions.
