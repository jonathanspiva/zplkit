import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension CGImage {
    /// Converts the CGImage to PNG data
    // Deliberately internal: a `public` retroactive extension on a system
    // type collides with the same extension in any other package in a
    // consumer's dependency graph, and could never be removed after 1.0.
    func pngData() -> Data? {
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
