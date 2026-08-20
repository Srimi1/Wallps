import AppKit
import Foundation

let sourceImagePath = "/Users/srimi/.gemini/antigravity/brain/4a14eadf-c4df-4067-b015-4421a7b2cf5a/wallps_app_icon_1787246306771.jpg"
guard let sourceImage = NSImage(contentsOfFile: sourceImagePath) else {
    print("Could not load source image at \(sourceImagePath)")
    exit(1)
}

let xcassetsDir = "Wallps/Assets.xcassets/AppIcon.appiconset"
let iconsetDir = "build/AppIcon.iconset"
let docsAssetsDir = "docs/assets"

try? FileManager.default.createDirectory(atPath: xcassetsDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: "Wallps/Resources", withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: docsAssetsDir, withIntermediateDirectories: true)

func resizeImage(image: NSImage, width: CGFloat, height: CGFloat) -> NSImage {
    let newSize = NSSize(width: width, height: height)
    let newImage = NSImage(size: newSize)
    newImage.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: newSize),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy,
               fraction: 1.0)
    newImage.unlockFocus()
    return newImage
}

func savePNG(image: NSImage, path: String) {
    if let tiff = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

// 1. Save main 1024x1024 doc asset
let full1024 = resizeImage(image: sourceImage, width: 1024, height: 1024)
savePNG(image: full1024, path: "\(docsAssetsDir)/app_icon.png")

// 2. Iconset sizes for iconutil
let iconsetSizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in iconsetSizes {
    let resized = resizeImage(image: sourceImage, width: size, height: size)
    savePNG(image: resized, path: "\(iconsetDir)/\(filename)")
    savePNG(image: resized, path: "\(xcassetsDir)/\(filename)")
}

// 3. Contents.json for xcassets
let contentsJSON = """
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16",
      "filename" : "icon_16x16.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16",
      "filename" : "icon_16x16@2x.png"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32",
      "filename" : "icon_32x32.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32",
      "filename" : "icon_32x32@2x.png"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128",
      "filename" : "icon_128x128.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128",
      "filename" : "icon_128x128@2x.png"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256",
      "filename" : "icon_256x256.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256",
      "filename" : "icon_256x256@2x.png"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512",
      "filename" : "icon_512x512.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512",
      "filename" : "icon_512x512@2x.png"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

try? contentsJSON.write(to: URL(fileURLWithPath: "\(xcassetsDir)/Contents.json"), atomically: true, encoding: .utf8)
print("Saved xcassets AppIcon.appiconset!")
