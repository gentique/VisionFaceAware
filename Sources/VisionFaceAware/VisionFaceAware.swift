//
//  VisionFaceAware.swift
//
//
//  Created by Gentian Barileva on 16.7.22.
//

import UIKit
import Vision

private var closureKey: UInt = 0
private var debugKey: UInt = 1

@IBDesignable
extension UIImageView: Attachable {

    @IBInspectable
    /// Adds a red bordered rectangle around any faces detected.
    public var debugFaceAware: Bool {
        set {
            set(newValue, forKey: &debugKey)
        } get {
            guard let debug = getAttach(forKey: &debugKey) as? Bool else {
                return false
            }
            return debug
        }
    }

    @IBInspectable
    /// Set this to true if you want to center the image on any detected faces.
    public var focusOnFaces: Bool {
        set {
            let image = self.image
            set(image: image, focusOnFaces: newValue)
        } get {
            return sublayer() != nil ? true : false
        }
    }

    public func set(image: UIImage?, focusOnFaces: Bool) {
        guard focusOnFaces == true else {
            self.removeImageLayer(image: image)
            return
        }
        setImageAndFocusOnFaces(image: image)
    }

    /// You can provide a closure here to receive a callback for when all face
    /// detection and image adjustments have been finished.
    public var didFocusOnFaces: (() -> Void)? {
        set {
            set(newValue, forKey: &closureKey)
        } get {
            return getAttach(forKey: &closureKey) as? (() -> Void)
        }
    }

    private func setImageAndFocusOnFaces(image: UIImage?) {
        DispatchQueue.global(qos: .default).async {
            guard let image = image else {
                return
            }
            
            guard let ciImage = CIImage(image: image) else {
                return
            }
            
            let request = VNDetectFaceRectanglesRequest { (request, error) in
                if error != nil {
                    return
                }
                
                for result in request.results ?? []{
                    guard let observation = result as? VNFaceObservation else {return}
                    
                    let imageWidth = image.size.width
                    let imageHeight = image.size.height
                    
                    let imgSize = CGSize(width: image.cgImage!.width, height: image.cgImage!.height)
                    
                    let position = CGRect(x: imageWidth * observation.boundingBox.origin.x,
                                          y: imageHeight * observation.boundingBox.origin.y,
                                          width: imageWidth * observation.boundingBox.width,
                                          height: imageHeight * observation.boundingBox.height)
                    
                    DispatchQueue.global(qos: .default).async {
                        self.applyFaceDetection(for: position, size: imgSize, image: image)
                    }
                    break
                }
            }
            
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do{
                try handler.perform([request])
            }catch{
            }
        }
    }
    
    private func applyFaceDetection(for features: CGRect, size: CGSize, image: UIImage) {
        var rect = features
        
        rect.origin.y = size.height - rect.minY - rect.height
        var rightBorder = Double(rect.minX + rect.width)
        var bottomBorder = Double(rect.minY + rect.height)
        
        var oneRect = rect
        oneRect.origin.y = size.height - oneRect.minY - oneRect.height
        rect.origin.x = min(oneRect.minX, rect.minX)
        rect.origin.y = min(oneRect.minY, rect.minY)
        
        rightBorder = max(Double(oneRect.minX + oneRect.width), Double(rightBorder))
        bottomBorder = max(Double(oneRect.minY + oneRect.height), Double(bottomBorder))
        
        rect.size.width = CGFloat(rightBorder) - rect.minX
        rect.size.height = CGFloat(bottomBorder) - rect.minY
        
        var offset = CGPoint.zero
        var finalSize = size
        
        DispatchQueue.main.async {
            if size.width / size.height > self.bounds.width / self.bounds.height {
                var centerX = rect.minX + rect.width / 2.0
                
                finalSize.height = self.bounds.height
                finalSize.width = size.width / size.height * finalSize.height
                centerX = finalSize.width / size.width * centerX
                
                offset.x = centerX - self.bounds.width * 0.5
                if offset.x < 0 {
                    offset.x = 0
                } else if offset.x + self.bounds.width > finalSize.width {
                    offset.x = finalSize.width - self.bounds.width
                }
                offset.x = -offset.x
            } else {
                var centerY = rect.minY + rect.height / 2.0
                
                finalSize.width = self.bounds.width
                finalSize.height = size.height / size.width * finalSize.width
                centerY = finalSize.width / size.width * centerY
                
                offset.y = centerY - self.bounds.height * CGFloat(1-0.618)
                if offset.y < 0 {
                    offset.y = 0
                } else if offset.y + self.bounds.height > finalSize.height {
                    finalSize.height = self.bounds.height
                    offset.y = finalSize.height
                }
                offset.y = -offset.y
            }
        }
        
        let newImage: UIImage
        if self.debugFaceAware {
            newImage = drawDebugRectangles(from: image, size: size, features: features)
        } else {
            newImage = image
        }
        
        DispatchQueue.main.async {
            self.image = newImage
            
            let layer = self.imageLayer()
            layer.contents = newImage.cgImage
            layer.frame = CGRect(origin: offset, size: finalSize)
            self.didFocusOnFaces?()
        }
    }

    private func drawDebugRectangles(from image: UIImage, size: CGSize, features: CGRect) -> UIImage {
        // Draw rectangles around detected faces
        let rawImage = UIImage(cgImage: image.cgImage!)
        UIGraphicsBeginImageContext(size)
        rawImage.draw(at: .zero)
        
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(UIColor.red.cgColor)
        context?.setLineWidth(20)
        
        var faceViewBounds = features
        faceViewBounds.origin.y = size.height - faceViewBounds.minY - faceViewBounds.height
        
        context?.addRect(faceViewBounds)
        context?.drawPath(using: .stroke)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }

    private func imageLayer() -> CALayer {
        if let layer = sublayer() {
            return layer
        }

        let subLayer = CALayer()
        subLayer.name = "AspectFillFaceAware"
        subLayer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer.addSublayer(subLayer)
        return subLayer
    }

    private func removeImageLayer(image: UIImage?) {
        DispatchQueue.main.async {
            // avoid redundant layer when focus on faces for the image of cell specified in UITableView
            self.imageLayer().removeFromSuperlayer()
            self.image = image
        }
    }

    private func sublayer() -> CALayer? {
        return layer.sublayers?.first { $0.name == "AspectFillFaceAware" }
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        if focusOnFaces {
            setImageAndFocusOnFaces(image: self.image)
        }
    }
}

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
