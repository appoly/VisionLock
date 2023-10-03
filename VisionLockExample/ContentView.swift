//
//  ContentView.swift
//  VisionLock
//
//  Created by James Wolfe on 28/09/2023.
//

import SwiftUI
import VisionLock

struct ContentView: View {
    // MARK: - Variables
    @State var obfuscate = false
    @State var error: Error?
    let visionLock = VisionLock()
    
    // MARK: - Views
    var body: some View {
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

#Preview {
    ContentView()
}
