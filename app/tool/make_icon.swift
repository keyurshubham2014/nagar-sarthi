// Renders the Nagar Sarthi mark (white "N", Plus Jakarta Sans 700) as PNGs.
// usage: swift make_icon.swift <font.ttf> <out.png> <px> <mode>
//   mode "square": black rounded square, white N (legacy launcher icon)
//   mode "fg": transparent 108dp canvas, white N sized for the adaptive-icon safe zone
import AppKit
import CoreText

let a = CommandLine.arguments
let fontURL = URL(fileURLWithPath: a[1]) as CFURL
let out = a[2]; let px = Int(a[3])!; let mode = a[4]
CTFontManagerRegisterFontsForURL(fontURL, .process, nil)
let descs = CTFontManagerCreateFontDescriptorsFromURL(fontURL) as! [CTFontDescriptor]
let s = CGFloat(px)
// Glyph height relative to the canvas.
let capFrac: CGFloat = mode == "fg" ? 0.30 : 0.46
var font = CTFontCreateWithFontDescriptor(descs[0], 100, nil)
// Variable font: ask for weight 700 ('wght' axis).
let wght = 0x77676874 as CFNumber
let varDesc = CTFontDescriptorCreateCopyWithAttributes(descs[0], [kCTFontVariationAttribute: [wght: 700]] as CFDictionary)
font = CTFontCreateWithFontDescriptor(varDesc, 100, nil)
let cap = CTFontGetCapHeight(font)
font = CTFontCreateCopyWithAttributes(font, 100 * (s * capFrac) / cap, nil, nil)

let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))
if mode == "square" {
  let inset = s * 0.04
  let r = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
  ctx.addPath(CGPath(roundedRect: r, cornerWidth: r.width * 0.22, cornerHeight: r.width * 0.22, transform: nil))
  ctx.setFillColor(CGColor(red: 0.039, green: 0.039, blue: 0.039, alpha: 1))
  ctx.fillPath()
}
let str = NSAttributedString(string: "N", attributes: [
  NSAttributedString.Key(kCTFontAttributeName as String): font,
  NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 1, green: 1, blue: 1, alpha: 1),
])
let line = CTLineCreateWithAttributedString(str)
let b = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
ctx.textPosition = CGPoint(x: (s - b.width) / 2 - b.minX, y: (s - b.height) / 2 - b.minY)
CTLineDraw(line, ctx)
let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
