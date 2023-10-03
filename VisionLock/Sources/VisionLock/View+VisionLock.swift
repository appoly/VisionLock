//
//  View+VisionLock.swift
//
//
//  Created by James Wolfe on 03/10/2023.
//

import SwiftUI

public extension View {
    
    @ViewBuilder func onFaceAppeared(_ action: @escaping () -> Void) -> some View {
        self
            .onAppear {
                NotificationCenter.default.addObserver(forName: .facePresent, object: nil, queue: .main) { _ in
                    action()
                }
            }
    }
    
    @ViewBuilder func onFaceDisappeared(_ action: @escaping () -> Void) -> some View {
        self
            .onAppear {
                NotificationCenter.default.addObserver(forName: .faceNotPresent, object: nil, queue: .main) { _ in
                    action()
                }
            }
    }
    
}
