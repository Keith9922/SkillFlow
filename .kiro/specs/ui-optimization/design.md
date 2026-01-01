# UI Optimization Design Document

## Overview

This design document outlines the architecture and implementation strategy for optimizing the SkillFlow application's user interface. The optimization focuses on simplifying the codebase, improving visual consistency, and enhancing user experience by adopting modern macOS design patterns.

The design follows a component-based architecture where each UI element has a single, well-defined responsibility. We will refactor the AppDelegate to be more maintainable, modernize the floating window implementation, and create a cohesive visual design system.

## Architecture

### High-Level Structure

```
SkillFlowApp (SwiftUI App)
    └── AppDelegate (NSApplicationDelegate)
        ├── StatusBar Management
        ├── FloatingPanel (Custom NSWindow)
        │   └── FloatingWindowView (SwiftUI)
        │       ├── ChatView
        │       ├── SkillLibrarySidebar
        │       └── Visual Effects
        └── HotKey Management
```

### Key Architectural Decisions

1. **Simplified AppDelegate**: Reduce complexity by removing unnecessary features and deferring initialization
2. **Custom FloatingPanel**: Subclass NSWindow for better control over window behavior
3. **Visual Effect System**: Use native macOS materials for translucent backgrounds
4. **Lazy Initialization**: Load components only when needed to improve startup time
5. **Separation of Concerns**: Each class handles one specific aspect of the UI

## Components and Interfaces

### 1. AppDelegate

**Responsibilities:**
- Manage application lifecycle
- Create and manage status bar item
- Create and manage floating window
- Register global hotkeys
- Handle window visibility toggling

**Key Methods:**
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: NSWindow?
    var statusItem: NSStatusItem?
    lazy var sharedModelContainer: ModelContainer { ... }
    
    func applicationDidFinishLaunching(_ notification: Notification)
    func setupStatusBar()
    func createFloatingWindow()
    func toggleFloatingWindow()
}
```

**Simplifications:**
- Remove guide overlay window (move to separate feature)
- Defer permission checks to first use
- Remove dock icon hiding (keep as default behavior)
- Simplify notification observers

### 2. FloatingPanel (Custom NSWindow)

**Responsibilities:**
- Provide custom window behavior
- Allow window to become key and main
- Support borderless style with full-size content view

**Implementation:**
```swift
class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
```

**Window Configuration:**
- Style: `.borderless`, `.fullSizeContentView`
- Level: `.floating`
- Collection Behavior: `.canJoinAllSpaces`, `.fullScreenAuxiliary`
- Background: Transparent with visual effect blur
- Size: 500x600 points (default)

### 3. FloatingWindowView

**Responsibilities:**
- Compose main UI layout
- Manage sidebar visibility
- Apply visual effects and styling

**Visual Hierarchy:**
```
FloatingWindowView
├── Background (VisualEffectBlur)
├── ChatView (Main Content)
├── SkillLibrarySidebar (Conditional)
└── Toolbar Button (Overlay)
```

**Styling:**
- Corner Radius: 16 points
- Border: 1 point gray with 30% opacity
- Shadow: Black with 30% opacity, 20 point radius, 10 point Y offset
- Material: `.hudWindow`

### 4. Visual Design System

**Color Palette:**
- Primary: System Blue
- Secondary: System Gray
- Background: Clear with visual effect blur
- Text: System primary and secondary labels
- Borders: Gray with 30% opacity

**Typography:**
- Headlines: System font, semibold weight
- Body: System font, regular weight
- Captions: System font, regular weight, smaller size

**Spacing Scale:**
- Extra Small: 4 points
- Small: 8 points
- Medium: 12 points
- Large: 16 points
- Extra Large: 20 points

**Corner Radius:**
- Small: 8 points (buttons, input fields)
- Medium: 12 points (cards)
- Large: 16 points (windows)

## Data Models

No new data models are required for this optimization. Existing models remain unchanged:
- `Skill`
- `SkillStep`
- `Message`
- `TaskEntry`

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

Based on the prework analysis, I identified several redundant properties:
- Property 1.4 is redundant with 1.1 (both test hudWindow material)
- Property 3.2 is redundant with 2.2 (both test window toggle)

After consolidation, here are the unique correctness properties:

### Property 1: Visual effect material consistency
*For any* UI component using visual effects, the material should be `.hudWindow` throughout the application
**Validates: Requirements 1.1, 1.4**

### Property 2: Window corner radius specification
*For any* floating window instance, the corner radius should be exactly 16 points
**Validates: Requirements 1.2**

### Property 3: Window visibility toggle consistency
*For any* window state (visible or hidden), toggling the window should result in the opposite state
**Validates: Requirements 2.2, 3.2**

### Property 4: Window position preservation
*For any* window position, hiding and then showing the window should restore the same position
**Validates: Requirements 2.4**

### Property 5: Color palette consistency
*For any* UI component, all colors used should come from the defined system color palette (blue, gray, clear, system labels)
**Validates: Requirements 6.1**

### Property 6: Button styling consistency
*For any* button in the UI, the corner radius should be 8 points and padding should be consistent
**Validates: Requirements 6.2**

### Property 7: System font usage
*For any* text view in the UI, the font should be a system font with appropriate weight
**Validates: Requirements 6.3**

### Property 8: Spacing multiple consistency
*For any* spacing value in the UI, it should be a multiple of 4 points
**Validates: Requirements 6.4**

### Property 9: Animation duration consistency
*For any* animation in the UI, the duration should be 0.3 seconds unless specifically overridden
**Validates: Requirements 7.4**

### Property 10: Window level persistence
*For any* application state, when the floating window is visible, its window level should remain `.floating`
**Validates: Requirements 8.1**

## Error Handling

### Window Creation Failures

**Scenario:** FloatingPanel initialization fails
**Handling:**
- Log error with detailed information
- Show alert to user explaining the issue
- Provide option to retry or quit application

### Status Bar Item Creation Failures

**Scenario:** Status bar item cannot be created
**Handling:**
- Log error
- Continue application launch without status bar
- Show floating window directly
- Provide alternative quit method (Cmd+Q)

### Model Container Initialization Failures

**Scenario:** SwiftData ModelContainer fails to initialize
**Handling:**
- Fatal error with descriptive message (current behavior)
- This is acceptable as the app cannot function without data persistence

### Animation Performance Issues

**Scenario:** Animations drop below 60fps
**Handling:**
- Reduce animation complexity
- Use simpler transitions
- Profile and optimize rendering

## Testing Strategy

### Unit Testing

**Focus Areas:**
- AppDelegate initialization logic
- Window visibility toggle logic
- Status bar menu creation
- Window position calculations

**Example Tests:**
- Test that `toggleFloatingWindow()` changes window visibility
- Test that window position is preserved after hide/show cycle
- Test that status bar menu contains expected items

### Property-Based Testing

We will use **Swift Testing** framework (built into Xcode 15+) for property-based tests.

**Configuration:**
- Minimum iterations: 100 per property test
- Each test tagged with: `**Feature: ui-optimization, Property {number}: {property_text}**`

**Property Tests:**

1. **Window Toggle Property**
   - Generate random initial window states
   - Apply toggle operation
   - Verify state is opposite of initial state

2. **Position Preservation Property**
   - Generate random window positions
   - Hide and show window
   - Verify position matches original

3. **Visual Effect Material Property**
   - Inspect all visual effect views in hierarchy
   - Verify all use `.hudWindow` material

4. **Spacing Multiple Property**
   - Extract all spacing values from UI
   - Verify each is divisible by 4

5. **Animation Duration Property**
   - Inspect all animation declarations
   - Verify duration is 0.3 seconds (or explicitly different)

6. **Window Level Property**
   - Generate random application states
   - Verify floating window level is always `.floating` when visible

### Integration Testing

**Scenarios:**
- Launch app and verify window appears
- Click status bar icon and verify window toggles
- Drag window and verify position changes
- Open sidebar and verify animation plays
- Switch spaces and verify window follows

### Visual Regression Testing

**Approach:**
- Capture screenshots of key UI states
- Compare against baseline images
- Flag any visual differences for review

**Key States:**
- Window with empty chat
- Window with messages
- Window with sidebar open
- Window with error state
- Window with progress indicator

## Implementation Notes

### Performance Considerations

1. **Lazy Initialization**: Use `lazy var` for ModelContainer to defer creation
2. **Efficient Rendering**: Use `LazyVStack` for message lists
3. **Animation Optimization**: Use `.spring()` animations for natural feel
4. **Memory Management**: Use `weak self` in closures to prevent retain cycles

### Accessibility

1. **VoiceOver Support**: Ensure all interactive elements have accessibility labels
2. **Keyboard Navigation**: Support full keyboard control
3. **Reduced Motion**: Respect system preference for reduced motion
4. **High Contrast**: Ensure sufficient contrast ratios

### Localization

1. **String Externalization**: Move all user-facing strings to Localizable.strings
2. **Layout Flexibility**: Use flexible layouts that adapt to text length
3. **RTL Support**: Ensure UI works with right-to-left languages

### Future Enhancements

1. **Customizable Window Size**: Allow users to resize the floating window
2. **Multiple Windows**: Support multiple chat windows
3. **Themes**: Add light/dark theme customization
4. **Window Snapping**: Snap to screen edges like macOS windows
5. **Transparency Control**: Allow users to adjust window opacity
