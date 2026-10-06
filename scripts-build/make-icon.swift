#!/usr/bin/env swift
// Draws the app icon (a wizard on a Paizo-style pawn standing in its base, on green) and writes a 1024 px PNG.
// Few, bold shapes so it still reads at small sizes. Usage: swift scripts-build/make-icon.swift <output.png>
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Maps unit coordinates (0…1, origin bottom left) into a rectangle.
struct Frame {
    let rect: CGRect

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }

    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(origin: point(x, y), size: CGSize(width: width * rect.width, height: height * rect.height))
    }

    func polygon(_ points: [(CGFloat, CGFloat)]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points.map { point($0.0, $0.1) })
        path.closeSubpath()
        return path
    }
}

func fill(_ context: CGContext, _ path: CGPath, _ hex: UInt32) {
    context.addPath(path)
    context.setFillColor(color(hex))
    context.fillPath()
}

func fillEllipse(_ context: CGContext, _ rect: CGRect, _ hex: UInt32) {
    context.setFillColor(color(hex))
    context.fillEllipse(in: rect)
}

func drawBackground(_ context: CGContext) {
    let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0.35))
    fill(context, shape, 0x0E3427)
    context.restoreGState()
    context.saveGState()
    context.addPath(shape)
    context.clip()
    let gradient = CGGradient(colorsSpace: sRGB, colors: [color(0x2E8A64), color(0x0E3427)] as CFArray,
                              locations: nil)!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY),
                               options: [])
    context.restoreGState()
}

/// A pawn's cut shape: a rectangle with its two top corners rounded.
func pawnShape(_ rect: CGRect, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.midX, y: rect.maxY),
                radius: radius)
    path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY),
                radius: radius)
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.closeSubpath()
    return path
}

func drawPawn(_ context: CGContext) {
    let shape = pawnShape(CGRect(x: 292, y: 250, width: 440, height: 600), radius: 130)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0, 0.45))
    fill(context, shape, 0xF6EEDB)
    context.restoreGState()
    context.saveGState()
    context.addPath(shape)
    context.clip()
    drawWizard(context, in: Frame(rect: CGRect(x: 312, y: 280, width: 400, height: 540)))
    context.restoreGState()
    context.addPath(shape)
    context.setStrokeColor(color(0xC0392B))
    context.setLineWidth(10)
    context.strokePath()
    fill(context, CGPath(roundedRect: CGRect(x: 232, y: 160, width: 560, height: 130), cornerWidth: 50,
                         cornerHeight: 50, transform: nil), 0x17171C)
}

/// Blue robe, staff with a glowing orb, white beard and a wide-brimmed pointed hat.
func drawWizard(_ context: CGContext, in frame: Frame) {
    drawRobeAndStaff(context, in: frame)
    fillEllipse(context, frame.rect(0.43, 0.62, 0.14, 0.13), 0xE8C9A8)
    let beard = CGMutablePath()
    beard.move(to: frame.point(0.42, 0.67))
    beard.addLine(to: frame.point(0.58, 0.67))
    beard.addQuadCurve(to: frame.point(0.5, 0.42), control: frame.point(0.58, 0.5))
    beard.addQuadCurve(to: frame.point(0.42, 0.67), control: frame.point(0.42, 0.5))
    fill(context, beard, 0xF2F2F2)
    fillEllipse(context, frame.rect(0.455, 0.69, 0.025, 0.025), 0x1C1A22)
    fillEllipse(context, frame.rect(0.52, 0.69, 0.025, 0.025), 0x1C1A22)
    let hat = CGMutablePath()
    hat.move(to: frame.point(0.38, 0.75))
    hat.addLine(to: frame.point(0.62, 0.75))
    hat.addQuadCurve(to: frame.point(0.66, 1.0), control: frame.point(0.56, 0.9))
    hat.addQuadCurve(to: frame.point(0.38, 0.75), control: frame.point(0.44, 0.9))
    fill(context, hat, 0x3A2C8C)
    fillEllipse(context, frame.rect(0.26, 0.72, 0.48, 0.06), 0x3A2C8C)
    fill(context, frame.polygon([(0.39, 0.79), (0.61, 0.79), (0.61, 0.765), (0.39, 0.765)]), 0xD9A441)
}

func drawRobeAndStaff(_ context: CGContext, in frame: Frame) {
    let robe = CGMutablePath()
    robe.move(to: frame.point(0.36, 0.64))
    robe.addLine(to: frame.point(0.64, 0.64))
    robe.addQuadCurve(to: frame.point(0.84, 0.0), control: frame.point(0.7, 0.3))
    robe.addLine(to: frame.point(0.16, 0.0))
    robe.addQuadCurve(to: frame.point(0.36, 0.64), control: frame.point(0.3, 0.3))
    fill(context, robe, 0x2E4A9E)
    fill(context, frame.polygon([(0.48, 0.6), (0.52, 0.6), (0.56, 0.0), (0.44, 0.0)]), 0x223677)
    fill(context, frame.polygon([(0.8, 0.0), (0.83, 0.0), (0.84, 0.9), (0.81, 0.9)]), 0x7A5230)
    fill(context, frame.polygon([(0.6, 0.6), (0.66, 0.62), (0.82, 0.5), (0.79, 0.45)]), 0x2E4A9E)
    fillEllipse(context, frame.rect(0.77, 0.45, 0.08, 0.07), 0xE8C9A8)
    context.saveGState()
    context.setShadow(offset: .zero, blur: frame.rect.width * 0.12, color: color(0x8FE3FF))
    fillEllipse(context, frame.rect(0.76, 0.87, 0.13, 0.13), 0xBFF4FF)
    context.restoreGState()
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <output.png>\n".data(using: .utf8)!)
    exit(1)
}
let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
drawBackground(context)
drawPawn(context)

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
