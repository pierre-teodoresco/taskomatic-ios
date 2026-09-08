import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Original vector artwork. Re-run with `swift scripts/generate-icon.swift`.
let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
let context = CGContext(
  data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let colors =
  [
    CGColor(red: 0.40, green: 0.39, blue: 0.91, alpha: 1),
    CGColor(red: 0.24, green: 0.23, blue: 0.66, alpha: 1),
  ] as CFArray
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
context.drawLinearGradient(
  gradient, start: CGPoint(x: 200, y: 1024), end: CGPoint(x: 824, y: 0),
  options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
context.setLineWidth(42)
context.strokeEllipse(in: CGRect(x: 186, y: 186, width: 652, height: 652))
context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.setLineWidth(80)
context.setLineCap(.round)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 298, y: 494))
context.addLine(to: CGPoint(x: 448, y: 350))
context.addLine(to: CGPoint(x: 734, y: 674))
context.strokePath()
let directory = URL(fileURLWithPath: "App/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let destination = CGImageDestinationCreateWithURL(
  directory.appending(path: "AppIcon.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination), "Unable to export app icon")
let contents = """
  {
    "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
    "info": {"author": "xcode", "version": 1}
  }
  """
try contents.write(
  to: directory.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
