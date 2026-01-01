# Design Document

## Overview

This design focuses on cleaning up the SkillFlow frontend codebase by removing all legacy API code and unused data migration logic. The application will exclusively use the new SEEDO API (Rust backend) for all operations. This cleanup will simplify the codebase, reduce maintenance burden, and ensure consistency with the new backend architecture.

## Architecture

The cleanup involves three main areas:

1. **Remove Legacy API Layer**: Delete old API models, adapters, and service files
2. **Remove Data Migration Service**: Delete unused migration logic for old data formats
3. **Update Existing Components**: Ensure TaskListViewModel and StageProgressView work correctly with the new API

### Current vs. New Architecture

**Before (Mixed APIs)**:
```
┌─────────────────┐
│  SkillFlowApp   │
└────────┬────────┘
         │
         ├──────────────┬──────────────┬─────────────────┐
         │              │              │                 │
    ┌────▼─────┐   ┌───▼──────┐  ┌───▼────────┐  ┌────▼────────┐
    │ SEEDO    │   │ Legacy   │  │ Migration  │  │ ViewModels  │
    │ API      │   │ API      │  │ Service    │  │             │
    └──────────┘   └──────────┘  └────────────┘  └─────────────┘
```

**After (Clean SEEDO Only)**:
```
┌─────────────────┐
│  SkillFlowApp   │
└────────┬────────┘
         │
         ├──────────────┬─────────────────┐
         │              │                 │
    ┌────▼─────┐   ┌───▼────────┐  ┌────▼────────┐
    │ SEEDO    │   │ Models     │  │ ViewModels  │
    │ API      │   │ (Clean)    │  │ (Updated)   │
    └──────────┘   └────────────┘  └─────────────┘
```

## Components and Interfaces

### 1. Files to Delete

**Legacy API Files**:
- `SkillFlow/SkillFlow/Models/LegacyAPIModels.swift` - Old API response models
- `SkillFlow/SkillFlow/Services/LegacyAPIAdapter.swift` - Old API adapter
- `SkillFlow/SkillFlow/Services/APIService.swift` - Old API service (if exists)

**Migration Files**:
- `SkillFlow/SkillFlow/Services/DataMigrationService.swift` - No longer needed

### 2. TaskListViewModel Updates

**File**: `SkillFlow/SkillFlow/ViewModels/TaskListViewModel.swift`

**Current State**: Already using SEEDOAPIService ✓

**Verification Needed**:
- Ensure no imports of legacy types
- Confirm all methods use SEEDO API
- Check error handling uses SEEDOError

**No changes needed** - This file is already correctly implemented.

### 3. StageProgressView Updates

**File**: `SkillFlow/SkillFlow/Views/Components/StageProgressView.swift`

**Current State**: Displays stage progress using StageDetail model ✓

**Verification Needed**:
- Ensure StageDetail model exists and is correct
- Confirm stages match new backend workflow
- Check that ParseStage enum has all required cases

**Expected Stages** (matching new backend):
1. `downloading` - Download video from URL
2. `extractingAudio` - Extract audio track
3. `uploading` - Upload files to S3
4. `creatingTask` - Create task via API
5. `audioProcessing` - Backend audio transcription
6. `videoProcessing` - Backend video analysis
7. `stepsGenerating` - Backend steps generation
8. `completed` - All done

### 4. Verify Supporting Models

**Files to Check**:
- `SkillFlow/SkillFlow/Models/StageDetail.swift` - Should exist
- `SkillFlow/SkillFlow/Models/ParseStage.swift` - Should have all stages
- `SkillFlow/SkillFlow/Models/TaskStatus.swift` - Should match backend
- `SkillFlow/SkillFlow/Models/ArtifactTrack.swift` - Should have audio/video/steps

### 5. Update Skill Model to Match Backend

**File**: `SkillFlow/SkillFlow/Models.swift`

**Current Issues**:
- Missing `version` field
- Missing `source_type` field
- Step structure doesn't match backend (missing `parameters`, `wait_after`)
- Missing enums: `ActionType`, `TargetType`, `LocatorMethod`, `SourceType`
- Locators stored as `Data` instead of structured array

**Required Changes**:

```swift
// Add new enums
enum SourceType: String, Codable {
    case videoAnalysis = "video_analysis"
    case manual = "manual"
}

enum ActionType: String, Codable {
    case click = "click"
    case input = "input"
    case drag = "drag"
    case shortcut = "shortcut"
    case menu = "menu"
}

enum TargetType: String, Codable {
    case button = "button"
    case toolButton = "tool_button"
    case menuItem = "menu_item"
    case inputField = "input_field"
    case icon = "icon"
}

enum LocatorMethod: String, Codable {
    case accessibility = "accessibility"
    case text = "text"
    case position = "position"
    case visual = "visual"
}

// Add new structures
struct Locator: Codable {
    let method: LocatorMethod
    let value: AnyCodable  // Can be string or object
    let priority: Int
}

struct Target: Codable {
    let targetType: TargetType
    let name: String
    let locators: [Locator]
    
    enum CodingKeys: String, CodingKey {
        case targetType = "type"
        case name
        case locators
    }
}

// Update Skill model
@Model
final class Skill {
    @Attribute(.unique) var id: UUID
    var skillId: String  // Backend ID
    var name: String
    var software: String
    var version: String  // NEW
    var skillDescription: String
    var sourceType: String  // NEW: "video_analysis" or "manual"
    var sourceUrl: String?
    var thumbnailData: Data?
    var createdAt: Date
    var usageCount: Int
    var tags: [String]
    var totalSteps: Int
    var estimatedDuration: Int
    
    @Relationship(deleteRule: .cascade)
    var steps: [SkillStep]
}

// Update SkillStep model
@Model
final class SkillStep {
    var stepId: Int
    var actionType: String  // Use enum string value
    var targetName: String
    var targetType: String  // Use enum string value
    var instruction: String
    var waitAfter: Double  // NEW
    var confidence: Double
    var parametersData: Data?  // NEW: JSON encoded parameters
    var locatorsData: Data?  // JSON encoded locators array
}
```

### 6. Create Skill Validation Service

**New File**: `SkillFlow/SkillFlow/Services/SkillValidator.swift`

**Purpose**: Validate Skill data against backend schema

```swift
class SkillValidator {
    enum ValidationError: Error, LocalizedError {
        case missingRequiredField(String)
        case invalidFieldType(String, expected: String)
        case invalidEnumValue(String, field: String)
        case emptyArray(String)
        
        var errorDescription: String? {
            switch self {
            case .missingRequiredField(let field):
                return "缺少必需字段: \(field)"
            case .invalidFieldType(let field, let expected):
                return "字段类型错误: \(field)，期望类型: \(expected)"
            case .invalidEnumValue(let value, let field):
                return "无效的枚举值: \(value) 在字段 \(field)"
            case .emptyArray(let field):
                return "数组不能为空: \(field)"
            }
        }
    }
    
    func validate(skill: Skill) throws {
        // Validate required fields
        if skill.skillId.isEmpty {
            throw ValidationError.missingRequiredField("skill_id")
        }
        if skill.name.isEmpty {
            throw ValidationError.missingRequiredField("name")
        }
        if skill.software.isEmpty {
            throw ValidationError.missingRequiredField("software")
        }
        if skill.version.isEmpty {
            throw ValidationError.missingRequiredField("version")
        }
        
        // Validate source_type
        guard SourceType(rawValue: skill.sourceType) != nil else {
            throw ValidationError.invalidEnumValue(skill.sourceType, field: "source_type")
        }
        
        // Validate steps
        if skill.steps.isEmpty {
            throw ValidationError.emptyArray("steps")
        }
        
        for step in skill.steps {
            try validate(step: step)
        }
    }
    
    func validate(step: SkillStep) throws {
        // Validate action_type
        guard ActionType(rawValue: step.actionType) != nil else {
            throw ValidationError.invalidEnumValue(step.actionType, field: "action_type")
        }
        
        // Validate target_type
        guard TargetType(rawValue: step.targetType) != nil else {
            throw ValidationError.invalidEnumValue(step.targetType, field: "target_type")
        }
        
        // Validate required fields
        if step.instruction.isEmpty {
            throw ValidationError.missingRequiredField("instruction")
        }
        if step.targetName.isEmpty {
            throw ValidationError.missingRequiredField("target.name")
        }
        
        // Validate locators
        if let locatorsData = step.locatorsData {
            let locators = try JSONDecoder().decode([Locator].self, from: locatorsData)
            if locators.isEmpty {
                throw ValidationError.emptyArray("target.locators")
            }
            
            for locator in locators {
                try validate(locator: locator)
            }
        } else {
            throw ValidationError.missingRequiredField("target.locators")
        }
    }
    
    func validate(locator: Locator) throws {
        // Locator method is already validated by enum
        // Just ensure priority is reasonable
        if locator.priority < 1 {
            throw ValidationError.invalidFieldType("priority", expected: "positive integer")
        }
    }
}
```

## Data Models

### Backend Skill Schema (Rust)

The frontend must match this exact schema from `rust-backend/src/domain/skill.rs`:

```rust
pub struct Skill {
    pub skill_id: String,
    pub name: String,
    pub software: String,
    pub version: String,
    pub description: String,
    pub steps: Vec<Step>,
    pub total_steps: u32,
    pub estimated_duration: u32,
    pub tags: Vec<String>,
    pub created_at: Option<DateTime<Utc>>,
    pub source_type: SourceType,
}

pub struct Step {
    pub step_id: u32,
    pub action_type: ActionType,
    pub target: Target,
    pub instruction: String,
    pub wait_after: f32,
    pub parameters: Value,
    pub confidence: f32,
}

pub struct Target {
    pub target_type: TargetType,
    pub name: String,
    pub locators: Vec<Locator>,
}

pub struct Locator {
    pub method: LocatorMethod,
    pub value: Value,
    pub priority: u32,
}
```

### Frontend Skill Model (Swift)

Must include all backend fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | UUID | Yes | Local SwiftData ID |
| skillId | String | Yes | Backend skill_id |
| name | String | Yes | Skill name |
| software | String | Yes | Target software |
| version | String | Yes | Software version |
| skillDescription | String | Yes | Description |
| sourceType | String | Yes | "video_analysis" or "manual" |
| steps | [SkillStep] | Yes | Array of steps |
| totalSteps | Int | Yes | Number of steps |
| estimatedDuration | Int | Yes | Duration in seconds |
| tags | [String] | Yes | Tags array |
| createdAt | Date | Yes | Creation timestamp |

### SkillStep Model

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| stepId | Int | Yes | Step number |
| actionType | String | Yes | Enum: click/input/drag/shortcut/menu |
| targetName | String | Yes | Target element name |
| targetType | String | Yes | Enum: button/tool_button/menu_item/input_field/icon |
| instruction | String | Yes | Human-readable instruction |
| waitAfter | Double | Yes | Wait time after action |
| confidence | Double | Yes | Confidence score 0-1 |
| parametersData | Data? | No | JSON encoded parameters |
| locatorsData | Data? | Yes | JSON encoded locators array |

### Enums

**SourceType**:
- `video_analysis` - Generated from video
- `manual` - Manually created

**ActionType**:
- `click` - Click action
- `input` - Text input
- `drag` - Drag action
- `shortcut` - Keyboard shortcut
- `menu` - Menu selection

**TargetType**:
- `button` - Regular button
- `tool_button` - Toolbar button
- `menu_item` - Menu item
- `input_field` - Text input field
- `icon` - Icon element

**LocatorMethod**:
- `accessibility` - Accessibility API
- `text` - Text matching
- `position` - Position-based
- `visual` - Visual recognition

### TaskStatus (Backend Alignment)

The frontend TaskStatus should match the Rust backend:

```swift
enum TaskStatus: String, Codable {
    case created = "created"
    case processing = "processing"
    case audioDone = "audio_done"
    case videoDone = "video_done"
    case finished = "finished"
    case failed = "failed"
}
```

### ArtifactTrack

```swift
enum ArtifactTrack: String, Codable {
    case audio = "audio"
    case video = "video"
    case steps = "steps"
}
```

### StageDetail

```swift
struct StageDetail: Identifiable {
    let id: UUID
    let stage: ParseStage
    let status: StageStatus
    let title: String
    let icon: String
}

enum StageStatus {
    case pending
    case inProgress
    case completed
    case failed
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

The requirements focus on code cleanup and removal rather than behavioral properties. The correctness is verified by:
1. Successful compilation (no legacy code references)
2. Successful build (no missing dependencies)
3. Successful runtime (no crashes from missing legacy code)

These are complementary verification steps that together ensure the cleanup is complete.

### Example 1: Legacy Code Removal
*For the specific case* where the project is built after removing legacy files, the compiler should not report any "cannot find type" or "cannot find module" errors related to LegacyAPIModels, LegacyAPIAdapter, or DataMigrationService.
**Validates: Requirements 1.1, 1.2, 1.3, 2.1**

### Example 2: SEEDO API Exclusive Usage
*For the specific case* where TaskListViewModel is compiled, all API calls should resolve to SEEDOAPIService methods without any references to legacy API types.
**Validates: Requirements 3.1, 3.2, 3.3, 3.4**

### Example 3: Stage Progress Display
*For the specific case* where StageProgressView renders with stage data, it should display all 8 stages (downloading through completed) with correct icons and status indicators.
**Validates: Requirements 4.1, 4.2, 4.3, 4.4**

### Example 4: Clean Build Success
*For the specific case* where xcodebuild runs on the cleaned project, it should complete with exit code 0 and produce a runnable .app bundle that launches without crashes.
**Validates: Requirements 5.1, 5.2, 5.3, 5.4**

## Error Handling

### Compilation Errors

Expected errors during cleanup:

1. **Missing type errors**: If any file still references deleted types, compiler will report "cannot find type 'LegacyAPIModels' in scope"
2. **Missing import errors**: If any file imports deleted modules, compiler will report "no such module"
3. **Undefined method errors**: If any code calls deleted service methods

**Resolution**: Search for all references before deleting files.

### Runtime Errors

Potential runtime issues:

1. **Nil service references**: If any code tries to access deleted services
2. **Missing data**: If app expects legacy data structures

**Mitigation**: 
- Thorough code search before deletion
- Test app launch after cleanup
- Verify all ViewModels work correctly

## Testing Strategy

### Pre-Deletion Verification

Before deleting files:

1. **Search for references**: Use Xcode "Find in Project" to search for:
   - `LegacyAPIModels`
   - `LegacyAPIAdapter`
   - `DataMigrationService`
   - `APIService` (old one)
   - `SkillData` (legacy type)
   - `convertLegacySkillData`

2. **Check imports**: Search for import statements referencing legacy code

3. **Review dependencies**: Check if any ViewModels or Views depend on legacy types

### Post-Deletion Verification

After deleting files:

1. **Clean build**: `xcodebuild clean`
2. **Full build**: `xcodebuild build`
3. **Check for errors**: Verify zero compilation errors
4. **Launch test**: Run the app and verify it launches
5. **Functional test**: Test task list loading and stage progress display

### Test Commands

```bash
# Clean build directory
xcodebuild -project SkillFlow/SkillFlow.xcodeproj -scheme SkillFlow clean

# Build and check for errors
xcodebuild -project SkillFlow/SkillFlow.xcodeproj -scheme SkillFlow -configuration Debug build

# Run the app (manual test)
open SkillFlow/build/Debug/SkillFlow.app
```

### Success Criteria

- Build completes with exit code 0
- No compilation errors or warnings about missing types
- Application launches successfully
- Task list loads from SEEDO API
- Stage progress displays correctly
- No crashes during normal operation

## Implementation Notes

### Deletion Order

1. **First**: Delete legacy API files (safe, no dependencies)
   - `LegacyAPIModels.swift`
   - `LegacyAPIAdapter.swift`
   - Old `APIService.swift` (if exists)

2. **Second**: Delete migration service (check for references first)
   - `DataMigrationService.swift`

3. **Third**: Clean up any remaining references in other files

### Search Patterns

Use these search patterns in Xcode:

```
# Find legacy API references
LegacyAPIModels
LegacyAPIAdapter
LegacyAnalysisResponse
LegacyProgressUpdate
LegacySkillData

# Find migration references
DataMigrationService
convertLegacySkillData
migrateToVersion
needsMigration

# Find old API service references
APIService.shared
analyzeVideoLegacy
connectWebSocket
```

### Files to Verify After Cleanup

Check these files to ensure they don't reference deleted code:

1. **SkillFlowApp.swift** - App initialization
2. **TaskListViewModel.swift** - Should only use SEEDOAPIService
3. **StageProgressView.swift** - Should use correct stage models
4. **Any ViewModel files** - Check for legacy imports

### Model Verification

Ensure these models exist and are correct:

1. **TaskStatus.swift** - Should match backend enum
2. **ArtifactTrack.swift** - Should have audio/video/steps
3. **StageDetail.swift** - Should have all required properties
4. **ParseStage.swift** - Should have all 8 stages

### Xcode Project Cleanup

After deleting files:

1. Remove file references from Xcode project
2. Verify no red (missing) files in project navigator
3. Clean derived data if needed: `rm -rf ~/Library/Developer/Xcode/DerivedData`
