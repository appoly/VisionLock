//
//  String+Error.swift
//  VisionLock
//
//  Created by James Wolfe on 28/09/2023.
//

import Foundation

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
