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
            if self.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                guard self.biometryType == .faceID else {
                    continuation.resume(throwing: "Face ID Enrollment Required")
                    return
                }
                self.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { (success, error) in
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
