import AppKit

let output = CommandLine.arguments[1]
let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let background = NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 210, yRadius: 210)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.17)
shadow.shadowBlurRadius = 26
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSGradient(starting: NSColor(calibratedRed: 0.21, green: 0.81, blue: 0.42, alpha: 1), ending: NSColor(calibratedRed: 0.06, green: 0.52, blue: 0.29, alpha: 1))!.draw(in: background, angle: -70)
NSShadow().set()
// A battery containing four interlocking puzzle pieces, drawn as vector artwork.
let battery = NSBezierPath(roundedRect: NSRect(x: 209, y: 316, width: 568, height: 390), xRadius: 55, yRadius: 55)
NSColor.white.withAlphaComponent(0.96).setStroke()
battery.lineWidth = 24
battery.stroke()
NSColor.white.withAlphaComponent(0.96).setFill()
NSBezierPath(roundedRect: NSRect(x: 797, y: 437, width: 36, height: 148), xRadius: 13, yRadius: 13).fill()
let fill = NSBezierPath(roundedRect: NSRect(x: 242, y: 349, width: 502, height: 324), xRadius: 28, yRadius: 28)
NSColor.white.withAlphaComponent(0.95).setFill()
fill.fill()
NSColor(calibratedRed: 0.10, green: 0.61, blue: 0.33, alpha: 1).setStroke()
let seams = NSBezierPath()
seams.lineWidth = 12
seams.lineCapStyle = .round
seams.move(to: NSPoint(x: 493, y: 349))
seams.line(to: NSPoint(x: 493, y: 415))
seams.curve(to: NSPoint(x: 493, y: 481), controlPoint1: NSPoint(x: 560, y: 400), controlPoint2: NSPoint(x: 560, y: 500))
seams.line(to: NSPoint(x: 493, y: 563))
seams.curve(to: NSPoint(x: 493, y: 629), controlPoint1: NSPoint(x: 426, y: 548), controlPoint2: NSPoint(x: 426, y: 648))
seams.line(to: NSPoint(x: 493, y: 673))
seams.move(to: NSPoint(x: 242, y: 511))
seams.line(to: NSPoint(x: 327, y: 511))
seams.curve(to: NSPoint(x: 393, y: 511), controlPoint1: NSPoint(x: 312, y: 578), controlPoint2: NSPoint(x: 412, y: 578))
seams.line(to: NSPoint(x: 578, y: 511))
seams.curve(to: NSPoint(x: 644, y: 511), controlPoint1: NSPoint(x: 563, y: 444), controlPoint2: NSPoint(x: 663, y: 444))
seams.line(to: NSPoint(x: 744, y: 511))
seams.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
