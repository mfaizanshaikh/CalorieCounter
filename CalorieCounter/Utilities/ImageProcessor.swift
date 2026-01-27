import UIKit

struct ImageProcessor {
    static func resizeForAnalysis(_ image: UIImage, targetSize: CGSize = CGSize(width: 336, height: 336)) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    static func compressForStorage(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
        var compression: CGFloat = 1.0
        let maxBytes = maxSizeKB * 1024

        guard var imageData = image.jpegData(compressionQuality: compression) else {
            return nil
        }

        while imageData.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            if let newData = image.jpegData(compressionQuality: compression) {
                imageData = newData
            }
        }

        return imageData
    }

    static func createThumbnail(_ image: UIImage, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage? {
        let aspectWidth = size.width / image.size.width
        let aspectHeight = size.height / image.size.height
        let aspectRatio = min(aspectWidth, aspectHeight)

        let newSize = CGSize(
            width: image.size.width * aspectRatio,
            height: image.size.height * aspectRatio
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    static func fixOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? image
    }
}
