# Copilot Instructions for Garden Management

## Project Overview


## Project Overview

This is a garden bed management app that records the location, details and photo of plants that are planted in a garden. The garden is divided into beds (e.g. bed 1, 2, 3) and each bed is divided into rows (e.g. row A, B). Each row is divided into positions (e.g. position 1, 2, 3). The number of rows and positions is configurable per bed

### Bed management 

The user should be able to 
- add and remove beds
- add and remove rows in each bed
- set the number of positions per bed

### Recording plant details

The user should be able to
- add details of a plant in a particular position. Details to record are
	- name
	- optional colour
	- optional secondary colour
	- capture one or more photos with the camera and save to the photos app (use PhotoUI framework)
        - attach one or more existing photos
	- location (bed, row, position)

An example plant details is

- name: Dahlia "Winkie Chevron"
- colour: pink
- photo 1: (attached photo)
- location: bed 3, row A, position 10


Garden Management is a multi-platform SwiftUI application built with SwiftData for data persistence. The app targets iOS and macOS simultaneously using a unified codebase with platform-specific adaptations.

## Build and Test Commands

### Building
```bash
# Build for all platforms
xcodebuild -project "Garden Management.xcodeproj" -scheme "Garden Management" build

# Build for specific platform
xcodebuild -project "Garden Management.xcodeproj" -scheme "Garden Management" -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project "Garden Management.xcodeproj" -scheme "Garden Management" -destination 'platform=macOS' build
xcodebuild -project "Garden Management.xcodeproj" -scheme "Garden Management" -destination 'platform=visionOS Simulator' build
```

### Testing
```bash
# Run all tests
xcodebuild test -project "Garden Management.xcodeproj" -scheme "Garden Management" -destination 'platform=iOS Simulator,name=iPhone 17'

# Run specific test
xcodebuild test -project "Garden Management.xcodeproj" -scheme "Garden Management" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:Garden_ManagementTests/Garden_ManagementTests/example
```

The project uses Swift Testing framework (not XCTest). Tests are marked with `@Test` attribute.

## Architecture

### Multi-Platform Design

The app uses compile-time platform checks (`#if os(...)`) to provide platform-specific behavior:
- **iOS**: Uses standard `NavigationView` with toolbar items in `.navigationBarTrailing`
- **macOS**: Uses `NavigationSplitView` with a detail pane and custom column widths

Platform-specific UI logic is encapsulated in helper views (e.g., `NavigationViewWrapper`) to keep the main view logic clean.

### Data Layer

- **SwiftData** is used for persistence with a schema-based approach
- `ModelContainer` is configured in the app entry point and injected via `.modelContainer()` modifier
- Models use the `@Model` macro and are accessed via `@Query` in views
- `ModelContext` is available through `@Environment(\.modelContext)` for CRUD operations

The data model is defined in `Item.swift` with the schema registered in `Garden_ManagementApp.swift`.

### Photos Framework & Asset Identifiers

- **PhotosPicker** does NOT expose PHAsset identifiers directly for privacy reasons
- `PhotosPickerItem.itemIdentifier` is NOT a PHAsset localIdentifier
- To get asset identifiers for library photos: use `PhotoLibraryHelper.getOrCreateAssetIdentifier()`
- Camera photos get identifiers via `PHAssetChangeRequest.creationRequestForAsset()`
- Always check for existing assets before saving to avoid duplicates (see `findExistingAsset()`)
- Exports use asset identifiers (not embedded image data) to reference iCloud Photos

### Photo Storage Strategy

- **PlantPhoto model** stores BOTH `imageData: Data` and `assetIdentifier: String?`
- Image data is always stored in SwiftData (for offline access)
- Asset identifier is used for export/import and iCloud sync. Image data is not embedded in the export json.
- Camera photos: get identifier when saved to Photos library
- Picker photos: get identifier via `getOrCreateAssetIdentifier()` (checks for existing first)
- Import: loads from Photos library using identifier, falls back to stored data

### Image Performance Patterns

When displaying many images (grids, lists):
- Use `ThumbnailCache` for async thumbnail generation and caching
- Never load full-resolution images directly in collection views
- Use `ThumbnailImageView` instead of `Image(data:)` for photo thumbnails
- Grid views with 20+ images can cause memory pressure without thumbnails
- The cache stores last 100 thumbnails and generates them off the main thread

## Key Conventions

### File Organization
- All source files are in `Garden Management/` directory
- SwiftData models go directly in the root source directory (e.g., `Item.swift`)
- Views follow SwiftUI naming: `ContentView.swift`, `SomeFeatureView.swift`
- No explicit folder structure in Xcode project (uses `PBXFileSystemSynchronizedRootGroup`)

### Naming
- App name uses underscores in Swift identifiers: `Garden_ManagementApp`, `Garden_ManagementTests`
- File names use spaces: `Garden Management.xcodeproj`, `Garden Management/`
- Models are singular nouns: `Item`, not `Items`

### SwiftUI Patterns
- Preview providers use `#Preview` macro with in-memory model containers for testing
- Platform-specific code is isolated into small helper views rather than scattered throughout
- Animation is wrapped around data mutations: `withAnimation { modelContext.insert(...) }`

### Testing
- Uses Swift Testing framework (import Testing)
- Test methods are marked with `@Test` attribute
- Async tests use `async throws` signature
- No setup/teardown methods needed; use local variables in test functions

### Deployment Targets
- iOS 26.4+
- macOS 26.4+
- visionOS 26.4+

This project supports the latest OS versions. When adding new features, you can use APIs from these versions without availability checks.

## Common Issues & Solutions

### App crashes with many photos in grid view
- **Cause**: Loading full-resolution images synchronously on main thread
- **Solution**: Use `ThumbnailImageView` instead of `Image(data:)` in grid cells
- **Files**: BedGridView.swift, PlantListView.swift, BedDetailView.swift

### Photos duplicated in library when selected from PhotosPicker
- **Cause**: Saving without checking if photo already exists
- **Solution**: Use `PhotoLibraryHelper.getOrCreateAssetIdentifier()` which checks first
- **Files**: AddPlantView.swift, PlantDetailView.swift

### Blank asset identifiers in exports
- **Cause**: Not saving photos to library to get identifiers
- **Solution**: All photos must be saved to Photos library to get asset identifiers
- Use `getOrCreateAssetIdentifier()` for picker photos, camera photos get them automatically
- **Files**: AddPlantView.swift, PlantDetailView.swift, BackupManager.swift
