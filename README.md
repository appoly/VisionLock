# VisionLock README

## Overview

VisionLock is an advanced Swift package that takes biometric authentication to the next level. Not only does it use Face ID to authenticate the device owner, but it also begins tracking the most prevalent face in the camera's view once authenticated. If the face leaves the camera's view, the package locks again and requires re-authentication via Face ID.

## Features

- Face ID authentication
- Real-time face tracking
- Auto-locking when face is not detected

## Requirements

- iOS 15.0+
- Xcode 13.0+
- SwiftUI 3.0+

## Installation

### Swift Package Manager

Add VisionLock as a dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/appoly/VisionLock.git", from: "1.0.0"),
]
```

## Usage

Here's a simple SwiftUI example to demonstrate how to use VisionLock.

```swift
import SwiftUI
import VisionLock

@main
struct YourApp: App {
    @State private var obfuscate = true
    @State private var error: Error?
    @StateObject private var visionLock = VisionLock()

    var body: some Scene {
        WindowGroup {
            VStack {
                Text(obfuscate ? "Hide!" : "Show")
                Text(error?.localizedDescription ?? "")
                    .foregroundStyle(Color.red)
                    .font(.caption)
            }
            .padding()
            .task {
                do {
                    try await visionLock.start()
                } catch {
                    withAnimation {
                        self.error = error
                    }
                }
            }
            .onFaceAppeared {
                withAnimation {
                    obfuscate = false
                }
            }
            .onFaceDisappeared {
                withAnimation {
                    obfuscate = true
                }
            }
        }
    }
}
```

## Events

- `onFaceAppeared`: Triggered when a face is detected.
- `onFaceDisappeared`: Triggered when the face disappears from the view.

To use these events, you need to add the following code to your SwiftUI view:

```swift
.onFaceAppeared {
    // Your code here
}
.onFaceDisappeared {
    // Your code here
}
```

## License

This project is licensed under the MIT License.

---

Feel free to modify this README to better suit the specifics of your project.
