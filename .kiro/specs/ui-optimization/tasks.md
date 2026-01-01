# Implementation Plan

- [x] 1. Simplify AppDelegate and improve window management
  - [x] 1.1 Refactor AppDelegate to remove unnecessary complexity
    - Remove guide overlay window initialization
    - Defer permission checks to first use
    - Simplify notification observers
    - Ensure code is under 200 lines
    - _Requirements: 5.1, 4.2_
  
  - [x] 1.2 Optimize FloatingPanel window configuration
    - Verify borderless and fullSizeContentView style masks
    - Set window level to .floating
    - Configure collection behavior for all spaces and full-screen auxiliary
    - Set isMovableByWindowBackground to true
    - _Requirements: 2.1, 2.5, 8.1, 8.3, 8.4_
  
  - [x] 1.3 Implement window visibility toggle logic
    - Create toggleFloatingWindow method
    - Ensure window state changes on each toggle
    - Preserve window position when hiding
    - _Requirements: 2.2, 2.4_
  
  - [ ]* 1.4 Write property test for window toggle consistency
    - **Property 3: Window visibility toggle consistency**
    - **Validates: Requirements 2.2, 3.2**
  
  - [ ]* 1.5 Write property test for window position preservation
    - **Property 4: Window position preservation**
    - **Validates: Requirements 2.4**

- [ ] 2. Modernize visual effects and styling
  - [ ] 2.1 Update FloatingWindowView with modern visual effects
    - Apply VisualEffectBlur with .hudWindow material
    - Set corner radius to 16 points
    - Add shadow with specified parameters (black 30% opacity, 20pt radius, 10pt Y offset)
    - Add border with gray 30% opacity, 1pt width
    - _Requirements: 1.1, 1.2, 1.3_
  
  - [ ] 2.2 Create visual design system constants
    - Define color palette constants
    - Define spacing scale (4, 8, 12, 16, 20 points)
    - Define corner radius values (8, 12, 16 points)
    - Define animation duration constant (0.3 seconds)
    - _Requirements: 6.1, 6.4, 7.4_
  
  - [ ]* 2.3 Write property test for visual effect material consistency
    - **Property 1: Visual effect material consistency**
    - **Validates: Requirements 1.1, 1.4**
  
  - [ ]* 2.4 Write property test for window corner radius
    - **Property 2: Window corner radius specification**
    - **Validates: Requirements 1.2**

- [ ] 3. Standardize UI component styling
  - [ ] 3.1 Update all buttons with consistent styling
    - Apply 8-point corner radius to all buttons
    - Use consistent padding (12 points)
    - Use system colors from palette
    - _Requirements: 6.1, 6.2_
  
  - [ ] 3.2 Standardize text styling across components
    - Ensure all text uses system fonts
    - Apply appropriate font weights (semibold for headlines, regular for body)
    - Use system label colors
    - _Requirements: 6.3_
  
  - [ ] 3.3 Audit and fix spacing throughout UI
    - Review all spacing values in ChatView
    - Review all spacing values in InputBar
    - Review all spacing values in FloatingWindowView
    - Ensure all spacing is multiple of 4 points
    - _Requirements: 6.4_
  
  - [ ]* 3.4 Write property test for color palette consistency
    - **Property 5: Color palette consistency**
    - **Validates: Requirements 6.1**
  
  - [ ]* 3.5 Write property test for button styling consistency
    - **Property 6: Button styling consistency**
    - **Validates: Requirements 6.2**
  
  - [ ]* 3.6 Write property test for system font usage
    - **Property 7: System font usage**
    - **Validates: Requirements 6.3**
  
  - [ ]* 3.7 Write property test for spacing multiples
    - **Property 8: Spacing multiple consistency**
    - **Validates: Requirements 6.4**

- [ ] 4. Improve animations and transitions
  - [ ] 4.1 Add spring animation for window appearance
    - Use .spring(response: 0.3) for window show
    - Ensure smooth transition
    - _Requirements: 7.1_
  
  - [ ] 4.2 Add fade animation for window disappearance
    - Use .opacity transition with 0.3 second duration
    - _Requirements: 7.2_
  
  - [ ] 4.3 Verify sidebar slide animation
    - Ensure sidebar uses .move(edge: .trailing) transition
    - Verify 0.3 second duration
    - _Requirements: 7.3, 7.4_
  
  - [ ]* 4.4 Write property test for animation duration consistency
    - **Property 9: Animation duration consistency**
    - **Validates: Requirements 7.4**

- [ ] 5. Optimize status bar integration
  - [ ] 5.1 Simplify status bar setup
    - Use SF Symbol for icon (star.fill or sparkles)
    - Set up click action for toggle
    - Create context menu with Show/Hide, Settings, Quit
    - _Requirements: 3.1, 3.3, 3.4_
  
  - [ ] 5.2 Implement graceful quit action
    - Wire up quit menu item to NSApplication.shared.terminate
    - _Requirements: 3.5_

- [ ] 6. Optimize initialization and performance
  - [ ] 6.1 Implement lazy initialization for ModelContainer
    - Use lazy var for sharedModelContainer
    - Defer creation until first access
    - _Requirements: 4.3_
  
  - [ ] 6.2 Remove blocking operations from launch
    - Move permission checks out of applicationDidFinishLaunching
    - Ensure window appears immediately
    - _Requirements: 4.2, 4.3_

- [ ] 7. Add code organization and documentation
  - [ ] 7.1 Add MARK comments to AppDelegate
    - Group status bar methods
    - Group floating window methods
    - Group permission methods
    - Group lifecycle methods
    - _Requirements: 5.4_
  
  - [ ] 7.2 Verify FloatingPanel class usage
    - Ensure window is instance of FloatingPanel
    - Verify canBecomeKey and canBecomeMain overrides
    - _Requirements: 5.3_
  
  - [ ]* 7.3 Write property test for window level persistence
    - **Property 10: Window level persistence**
    - **Validates: Requirements 8.1**

- [ ] 8. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
