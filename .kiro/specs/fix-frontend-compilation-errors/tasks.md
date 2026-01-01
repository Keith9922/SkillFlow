# Implementation Plan

- [x] 1. Search for legacy code references
  - Search for `LegacyAPIModels` references in the codebase
  - Search for `LegacyAPIAdapter` references in the codebase
  - Search for `DataMigrationService` references in the codebase
  - Search for `convertLegacySkillData` references in the codebase
  - Document all files that reference legacy code
  - _Requirements: 1.1, 1.2, 1.3, 2.1_

- [x] 2. Remove legacy API model references
  - Update any files that import or use LegacyAPIModels
  - Remove legacy type references from ViewModels
  - Remove legacy type references from Services
  - _Requirements: 1.1, 1.4_

- [x] 3. Remove data migration references
  - Update any files that import or use DataMigrationService
  - Remove migration checks from app initialization
  - Remove legacy data conversion calls
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 4. Delete legacy API files
  - Delete `SkillFlow/SkillFlow/Models/LegacyAPIModels.swift`
  - Delete `SkillFlow/SkillFlow/Services/LegacyAPIAdapter.swift`
  - Delete old `SkillFlow/SkillFlow/Services/APIService.swift` if it exists
  - Remove file references from Xcode project
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 5. Delete data migration service
  - Delete `SkillFlow/SkillFlow/Services/DataMigrationService.swift`
  - Remove file reference from Xcode project
  - _Requirements: 2.1_

- [x] 6. Create backend-aligned enums
  - Create `SourceType` enum with video_analysis and manual cases
  - Create `ActionType` enum with click, input, drag, shortcut, menu cases
  - Create `TargetType` enum with button, tool_button, menu_item, input_field, icon cases
  - Create `LocatorMethod` enum with accessibility, text, position, visual cases
  - Add enums to Models.swift or separate enum file
  - _Requirements: 6.2, 6.3, 6.4, 6.5_

- [x] 7. Create Locator and Target structures
  - Create `Locator` struct with method, value (AnyCodable), priority
  - Create `Target` struct with targetType, name, locators
  - Implement Codable conformance with proper CodingKeys
  - _Requirements: 5.3, 5.4, 6.1_

- [x] 8. Update Skill model to match backend schema
  - Add `version` field (String)
  - Add `sourceType` field (String)
  - Add `skillId` field for backend ID
  - Update initializer to include new fields
  - Ensure all fields match backend Skill struct
  - _Requirements: 6.1, 5.1_

- [x] 9. Update SkillStep model to match backend schema
  - Add `waitAfter` field (Double)
  - Add `parametersData` field (Data?)
  - Update `actionType` to use enum string values
  - Update `targetType` to use enum string values
  - Ensure locatorsData stores array of Locator structs
  - _Requirements: 5.2, 6.1_

- [x] 10. Create SkillValidator service
  - Create new file `SkillFlow/SkillFlow/Services/SkillValidator.swift`
  - Implement ValidationError enum with clear error messages
  - Implement validate(skill:) method to check all required fields
  - Implement validate(step:) method to check step fields and enums
  - Implement validate(locator:) method to check locator structure
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 11. Update DataConverter to use validation
  - Import SkillValidator in DataConverter
  - Call validator.validate(skill:) after converting from backend data
  - Handle validation errors and provide clear error messages
  - Ensure converted skills match backend schema exactly
  - _Requirements: 5.5, 6.1_

- [x] 12. Verify TaskListViewModel uses SEEDO API only
  - Review TaskListViewModel imports
  - Confirm all API calls use SEEDOAPIService
  - Verify error handling uses SEEDOError
  - Check that no legacy types are referenced
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 13. Verify StageProgressView model alignment
  - Check that StageDetail model exists and is correct
  - Verify ParseStage enum has all 8 required stages
  - Confirm stage icons and titles match new backend workflow
  - Ensure StageStatus enum is correct
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 14. Verify supporting models match backend
  - Check TaskStatus enum matches Rust backend (created, processing, audio_done, video_done, finished, failed)
  - Check ArtifactTrack enum has audio, video, steps
  - Verify TaskSummary struct in SEEDOAPIService
  - _Requirements: 3.4, 4.4_

- [x] 15. Clean build verification
  - Run `xcodebuild clean` to clear build cache
  - Run `xcodebuild build` to compile the project
  - Verify zero compilation errors
  - Check for any warnings about missing types
  - _Requirements: 7.1, 7.2, 7.3_

- [x] 16. Runtime verification and validation testing
  - Launch the application
  - Verify app starts without crashes
  - Test task list loading from SEEDO API
  - Test stage progress display
  - Test skill validation with valid and invalid data
  - Verify validation error messages are clear
  - Verify no runtime errors related to missing legacy code
  - _Requirements: 7.4, 5.5_
