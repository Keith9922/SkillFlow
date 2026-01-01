# Requirements Document

## Introduction

This document outlines the requirements for adapting the SkillFlow macOS frontend to work exclusively with the new Rust backend API. The application needs to remove all legacy API code, clean up unused data migration logic, and ensure the frontend only uses the new SEEDO API service layer.

## Glossary

- **SEEDO API**: The new Rust backend API service that handles task creation, audio/video parsing, and artifact retrieval
- **Legacy API**: The old Python/WebSocket-based API that is being replaced
- **Data Migration Service**: Service that converts old data formats to new formats (no longer needed)
- **TaskEntry Model**: SwiftData model for tracking task processing status
- **Artifact**: Processing results (audio transcript, video analysis, skill steps) from the backend

## Requirements

### Requirement 1

**User Story:** As a developer, I want to remove all legacy API code, so that the codebase only contains the new SEEDO API implementation.

#### Acceptance Criteria

1. WHEN the application builds THEN the system SHALL not include LegacyAPIModels.swift
2. WHEN the application builds THEN the system SHALL not include LegacyAPIAdapter.swift
3. WHEN the application builds THEN the system SHALL not include the old APIService.swift
4. WHEN code references API services THEN the system SHALL only use SEEDOAPIService

### Requirement 2

**User Story:** As a developer, I want to remove unused data migration logic, so that the codebase is cleaner and easier to maintain.

#### Acceptance Criteria

1. WHEN the application builds THEN the system SHALL not include DataMigrationService.swift
2. WHEN the application starts THEN the system SHALL not perform legacy data migration checks
3. WHEN the application starts THEN the system SHALL not attempt to convert legacy skill data formats

### Requirement 3

**User Story:** As a developer, I want TaskListViewModel to only use the new SEEDO API, so that task management is consistent with the new backend.

#### Acceptance Criteria

1. WHEN TaskListViewModel loads tasks THEN the system SHALL call SEEDOAPIService.listTasks
2. WHEN TaskListViewModel loads task details THEN the system SHALL call SEEDOAPIService.getTaskStatus
3. WHEN TaskListViewModel retrieves artifacts THEN the system SHALL call SEEDOAPIService.getArtifact
4. WHEN TaskListViewModel compiles THEN the system SHALL not reference any legacy API types

### Requirement 4

**User Story:** As a developer, I want StageProgressView to display progress for the new backend pipeline, so that users see accurate processing stages.

#### Acceptance Criteria

1. WHEN StageProgressView renders THEN the system SHALL display stages matching the new backend workflow
2. WHEN a task is processing THEN the system SHALL show stages: downloading, extractingAudio, uploading, creatingTask, audioProcessing, videoProcessing, stepsGenerating, completed
3. WHEN StageProgressView compiles THEN the system SHALL use the correct StageDetail model
4. WHEN StageProgressView updates THEN the system SHALL reflect the current TaskStatus from the backend

### Requirement 5

**User Story:** As a developer, I want to validate Skill data format against the backend schema, so that only correctly formatted skills can be used in the application.

#### Acceptance Criteria

1. WHEN a Skill is received from the backend THEN the system SHALL validate it has all required fields (skill_id, name, software, version, description, steps, total_steps, estimated_duration, tags, source_type)
2. WHEN a Step is validated THEN the system SHALL ensure it has step_id, action_type, target, instruction, wait_after, parameters, and confidence
3. WHEN a Target is validated THEN the system SHALL ensure it has target_type, name, and locators array
4. WHEN a Locator is validated THEN the system SHALL ensure it has method, value, and priority
5. WHEN validation fails THEN the system SHALL provide clear error messages indicating which fields are missing or invalid

### Requirement 6

**User Story:** As a developer, I want the frontend Skill model to match the backend schema exactly, so that data can be serialized and deserialized without errors.

#### Acceptance Criteria

1. WHEN the frontend Skill model is defined THEN the system SHALL include all backend fields with matching types
2. WHEN ActionType enum is defined THEN the system SHALL include: click, input, drag, shortcut, menu
3. WHEN TargetType enum is defined THEN the system SHALL include: button, tool_button, menu_item, input_field, icon
4. WHEN LocatorMethod enum is defined THEN the system SHALL include: accessibility, text, position, visual
5. WHEN SourceType enum is defined THEN the system SHALL include: video_analysis, manual

### Requirement 7

**User Story:** As a developer, I want the application to compile successfully with the updated models and validation, so that I can build and run the application.

#### Acceptance Criteria

1. WHEN xcodebuild runs with the SkillFlow scheme THEN the system SHALL complete without compilation errors
2. WHEN all Swift files are compiled THEN the system SHALL produce valid object files
3. WHEN the build process completes THEN the system SHALL generate a runnable application binary
4. WHEN the application launches THEN the system SHALL not crash due to missing legacy dependencies
