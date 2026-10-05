#!/usr/bin/env swift
// Draws the app icon (a folded paper pawn in a base, in front of a brass three-ball pawnshop sign)
// and writes a 1024 px PNG. Usage: swift scripts-build/make-icon.swift <output.png>
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let cornerRadius: CGFloat = 185
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: sRGB, colors: colors as CFArray, locations: nil)!
}

func drawBackground(_ context: CGContext) {
    let shape = CGPath(roundedRect: body, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    context.addPath(shape)
    context.setFillColor(color(0x123D2E))
    context.fillPath()
    context.restoreGState()

    context.addPath(shape)
    context.clip()
    context.drawRadialGradient(gradient([color(0x2A7A5A), color(0x0E3427)]),
                               startCenter: CGPoint(x: 420, y: 640), startRadius: 0,
                               endCenter: CGPoint(x: 512, y: 512), endRadius: 640, options: [.drawsAfterEndLocation])
    let inset = body.insetBy(dx: 26, dy: 26)
    context.addPath(CGPath(roundedRect: inset, cornerWidth: cornerRadius - 26, cornerHeight: cornerRadius - 26,
                           transform: nil))
    context.setStrokeColor(color(0xC9A24A, 0.55))
    context.setLineWidth(6)
    context.strokePath()
}

func drawSign(_ context: CGContext) {
    // A bracket from the right edge holding three brass balls on chains.
    context.setFillColor(color(0x8A6A28))
    context.fill(CGRect(x: 600, y: 812, width: 300, height: 18))
    context.fill(CGRect(x: 868, y: 760, width: 18, height: 70))
    let balls = [CGPoint(x: 655, y: 690), CGPoint(x: 815, y: 690), CGPoint(x: 735, y: 565)]
    context.setStrokeColor(color(0x8A6A28))
    context.setLineWidth(6)
    for ball in balls.prefix(2) {
        context.move(to: CGPoint(x: ball.x, y: 812))
        context.addLine(to: CGPoint(x: ball.x, y: ball.y + 50))
    }
    context.move(to: CGPoint(x: 735, y: 812))
    context.addLine(to: CGPoint(x: 735, y: 600))
    context.strokePath()
    for ball in balls { drawBall(context, at: ball, radius: 62) }
}

func drawBall(_ context: CGContext, at center: CGPoint, radius: CGFloat) {
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: color(0x000000, 0.45))
    context.setFillColor(color(0xB8892E))
    context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    context.restoreGState()
    context.saveGState()
    context.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    context.clip()
    let highlight = CGPoint(x: center.x - radius * 0.35, y: center.y + radius * 0.4)
    context.drawRadialGradient(gradient([color(0xFFF1B8), color(0xE0B24E), color(0x7A5518)]),
                               startCenter: highlight, startRadius: 0, endCenter: center, endRadius: radius,
                               options: [.drawsAfterEndLocation])
    context.restoreGState()
}

let front = CGRect(x: 230, y: 250, width: 290, height: 560)

func drawPawn(_ context: CGContext) {
    // The back ply peeks out to the right, joined to the front at the fold along the top.
    let back = CGMutablePath()
    back.move(to: CGPoint(x: front.maxX, y: front.maxY))
    back.addLine(to: CGPoint(x: front.maxX + 34, y: front.maxY - 18))
    back.addLine(to: CGPoint(x: front.maxX + 34, y: front.minY + 30))
    back.addLine(to: CGPoint(x: front.maxX, y: front.minY + 40))
    back.closeSubpath()
    context.addPath(back)
    context.setFillColor(color(0xCDBF9C))
    context.fillPath()

    context.saveGState()
    context.setShadow(offset: CGSize(width: -10, height: -10), blur: 24, color: color(0x000000, 0.4))
    context.setFillColor(color(0xF4ECD8))
    context.fill(front)
    context.restoreGState()
    context.saveGState()
    context.clip(to: front)
    context.drawLinearGradient(gradient([color(0x9C8F70, 0.7), color(0x9C8F70, 0)]),
                               start: CGPoint(x: 0, y: front.maxY), end: CGPoint(x: 0, y: front.maxY - 22),
                               options: [])
    context.restoreGState()
    drawFigure(context)
    drawLabel(context)
    context.setStrokeColor(color(0x9C8F70))
    context.setLineWidth(3)
    context.stroke(front)
}

func drawFigure(_ context: CGContext) {
    // A hooded adventurer with a staff, as a dark silhouette.
    let ink = color(0x3A2340)
    context.setFillColor(ink)
    let cloak = CGMutablePath()
    cloak.move(to: CGPoint(x: 375, y: 742))
    cloak.addCurve(to: CGPoint(x: 312, y: 660), control1: CGPoint(x: 330, y: 742), control2: CGPoint(x: 312, y: 700))
    cloak.addCurve(to: CGPoint(x: 268, y: 380), control1: CGPoint(x: 300, y: 560), control2: CGPoint(x: 268, y: 450))
    cloak.addLine(to: CGPoint(x: 470, y: 380))
    cloak.addCurve(to: CGPoint(x: 438, y: 660), control1: CGPoint(x: 462, y: 470), control2: CGPoint(x: 440, y: 560))
    cloak.addCurve(to: CGPoint(x: 375, y: 742), control1: CGPoint(x: 438, y: 705), control2: CGPoint(x: 420, y: 742))
    cloak.closeSubpath()
    context.saveGState()
    context.addPath(cloak)
    context.clip()
    context.drawLinearGradient(gradient([color(0x7A3B8F), ink]), start: CGPoint(x: 300, y: 742),
                               end: CGPoint(x: 450, y: 380), options: [])
    context.restoreGState()

    // The face is lost in the hood's shadow except for the eyes.
    context.setFillColor(color(0x140A18))
    context.fillEllipse(in: CGRect(x: 344, y: 632, width: 62, height: 74))
    context.saveGState()
    context.setShadow(offset: .zero, blur: 12, color: color(0x8FE3FF))
    context.setFillColor(color(0xC8F4FF))
    context.fillEllipse(in: CGRect(x: 357, y: 668, width: 12, height: 9))
    context.fillEllipse(in: CGRect(x: 381, y: 668, width: 12, height: 9))
    context.restoreGState()

    context.setStrokeColor(color(0x6B4A2A))
    context.setLineWidth(14)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 470, y: 392))
    context.addLine(to: CGPoint(x: 478, y: 720))
    context.strokePath()
    context.saveGState()
    context.setShadow(offset: .zero, blur: 26, color: color(0x8FE3FF))
    context.setFillColor(color(0x8FE3FF))
    context.fillEllipse(in: CGRect(x: 456, y: 712, width: 46, height: 46))
    context.restoreGState()
}

func drawLabel(_ context: CGContext) {
    context.setFillColor(color(0x3A2340, 0.8))
    context.fill(CGRect(x: 280, y: 330, width: 190, height: 20))
    context.setFillColor(color(0xB0412F))
    context.fillEllipse(in: CGRect(x: 252, y: 322, width: 30, height: 30))
}

func drawBase(_ context: CGContext) {
    let base = CGMutablePath()
    base.addRoundedRect(in: CGRect(x: 190, y: 178, width: 400, height: 96), cornerWidth: 36, cornerHeight: 36)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: color(0x000000, 0.55))
    context.addPath(base)
    context.setFillColor(color(0x15151A))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(base)
    context.clip()
    context.drawLinearGradient(gradient([color(0x4A4A55), color(0x15151A)]),
                               start: CGPoint(x: 0, y: 274), end: CGPoint(x: 0, y: 220), options: [])
    context.restoreGState()
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <output.png>\n".data(using: .utf8)!)
    exit(1)
}
let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
drawBackground(context)
drawSign(context)
drawPawn(context)
drawBase(context)

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
