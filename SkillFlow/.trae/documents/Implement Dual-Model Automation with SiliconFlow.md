# Implementation Plan: Dual-Model Automation with SiliconFlow API

I will integrate SiliconFlow's API to enable a two-stage automation workflow:
1.  **Intent Recognition (Kimi-K2-Instruct-0905)**: Analyzes user chat input to detect automation intent.
2.  **Visual Planning (GLM-4.6V)**: Analyzes screen content and intent to generate precise action sequences.

## 1. Data Models & Constants
- **Location**: `SkillFlow/Models/AutomationModels.swift` (New File)
- **Content**:
  - `VLMAction`: Enum/Struct for parsed actions (move, click, type, etc.).
  - `SiliconFlowConfig`: Struct to hold API keys and Model names.
  - Constants for model names: `moonshotai/Kimi-K2-Instruct-0905` and `zai-org/GLM-4.6V`.

## 2. Service Layer Enhancements
### APIService (`SkillFlow/Services/APIService.swift`)
- **Modify `generateAction`**: Update to use `zai-org/GLM-4.6V` with the new robust Prompt.
- **Add `chatWithKimi`**: New method to call Kimi model for intent detection.
  - **Prompt**: "You are a helpful assistant... If the user wants to operate the computer, output `[OPERATE: <intent>]`..."
- **Add `executeVLMTask`**: A wrapper to call GLM-4V with image and intent.

### ScreenCaptureService (`SkillFlow/Services/ScreenCaptureService.swift`)
- Ensure `captureMainScreen()` is accessible and working (already verified).

### InputControlService (`SkillFlow/Services/InputControl/InputControlService.swift`)
- No changes needed, will be used for execution.

## 3. Orchestration Layer (`AssistantService`)
- **Location**: `SkillFlow/Services/AssistantService.swift` (New File)
- **Role**: Coordinator.
- **Flow**:
  1.  `handleUserMessage(text)` -> Call Kimi.
  2.  If Kimi returns normal text -> Return to ChatViewModel.
  3.  If Kimi returns `[OPERATE: ...]` ->
      - Capture Screen.
      - Call GLM-4V with Image + Intent.
      - Parse JSON response.
      - Execute actions via `InputControlService`.
      - Return result summary to ChatViewModel.

## 4. UI Layer Integration (`ChatViewModel.swift`)
- **Modify `handleRegularChat`**:
  - Replace dummy response with call to `AssistantService.handleUserMessage`.
  - Handle async response and update UI with bot message (or intermediate status).

## 5. Prompt Engineering (Crucial)
- **Kimi Prompt**: Strict instruction to separate chat from automation intent.
- **GLM-4V Prompt**:
  - **Role**: macOS GUI Automation Expert.
  - **Coordinate System**: Normalized (0-1), Top-Left origin.
  - **Output**: Strict JSON Array of tasks.
  - **Safety**: Low temperature (0.1), constrained output format.

## Verification
- I will verify by running the app, typing a command like "Open Safari and search for Apple", and observing the logs/debug window for the two-stage process and final mouse execution.
