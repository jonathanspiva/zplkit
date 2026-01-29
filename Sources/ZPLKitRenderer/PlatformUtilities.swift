import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension CGImage {
    /// Converts the CGImage to PNG data
    public func pngData() -> Data? {
        #if canImport(UIKit)
        return UIImage(cgImage: self).pngData()
        #elseif canImport(AppKit)
        let bitmap = NSBitmapImageRep(cgImage: self)
        return bitmap.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }
}
