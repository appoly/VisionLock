//
//  LAContext+Extension.swift
//  FaceDetectionExample
//
//  Created by James Wolfe on 28/09/2023.
//

import Foundation
import LocalAuthentication

internal extension LAContext {
    func faceID(reason: String) async throws -> Bool {
        var error: NSError?
        return try await withCheckedThrowingContinuation { continuation in
            if self.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                self.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { (success, error) in
                    guard error == nil else {
                        continuation.resume(throwing: error!)
                        return
                    }
                    
                    continuation.resume(returning: success)
                }
            } else if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: false)
            }
        }
    }
}
