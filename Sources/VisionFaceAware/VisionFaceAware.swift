//
//  VisionFaceAware.swift
//
//
//  Created by Gentian Barileva on 16.7.22.
//

import UIKit

// MARK: - Internal helpers
internal class ClosureWrapper<T> {
    var closure: (T) -> Void
    init(_ closure: @escaping (T) -> Void) {
        self.closure = closure
    }
}

internal protocol Attachable {
    func set(_ attachObj: Any?, forKey key: inout UInt)
    func getAttach(forKey key: inout UInt) -> Any?
}

extension Attachable {
    public func set(_ attachObj: Any?, forKey key: inout UInt) {
        objc_setAssociatedObject(self, &key, attachObj, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    public func getAttach(forKey key: inout UInt) -> Any? {
        return objc_getAssociatedObject(self, &key)
    }
}
