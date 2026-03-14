import SwiftUI

struct FlockSheepView: View {
    let definition: SheepDefinition
    let isAwake: Bool
    var size: CGFloat = 48
    var isGhost: Bool = false
    @State private var bobOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Canvas { context, canvasSize in
                drawSheep(context: &context, canvasSize: canvasSize)
            }
            .frame(width: size, height: size)

            // ZZZ for sleeping sheep
            if !isAwake && !isGhost {
                Text("z z z")
                    .font(.system(size: size * 0.14, weight: .bold))
                    .foregroundColor(.textSecondary.opacity(0.6))
                    .offset(x: size * 0.15, y: -size * 0.38)
            }
        }
        .saturation(isGhost ? 0 : 1)
        .opacity(isGhost ? 0.4 : 1)
        .offset(y: bobOffset)
        .onAppear {
            if isAwake && !isGhost {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    bobOffset = -3
                }
            }
        }
    }

    private func drawSheep(context: inout GraphicsContext, canvasSize: CGSize) {
        let s = min(canvasSize.width, canvasSize.height)
        let cx = canvasSize.width / 2
        let cy = canvasSize.height / 2 + s * 0.04

        let woolColor = definition.woolColor
        let faceColor = Color(red: 0.99, green: 0.97, blue: 0.94)
        let strokeColor = Color(red: 0.35, green: 0.30, blue: 0.28)
        let strokeW = max(s * 0.03, 0.5)

        // Golden glow for special sheep
        if definition.isSpecial {
            let glowR = s * 0.52
            let glowRect = CGRect(x: cx - glowR, y: cy - glowR, width: glowR * 2, height: glowR * 2)
            context.fill(Path(ellipseIn: glowRect),
                with: .color(Color(red: 1.0, green: 0.92, blue: 0.5).opacity(0.35)))
        }

        drawLegs(context: &context, s: s, cx: cx, cy: cy, strokeW: strokeW)

        // Wings drawn behind wool
        if definition.accessory == .wings {
            drawWings(context: &context, s: s, cx: cx, cy: cy, strokeColor: strokeColor, strokeW: strokeW)
        }

        drawWool(context: &context, s: s, cx: cx, cy: cy, woolColor: woolColor, strokeColor: strokeColor, strokeW: strokeW)
        drawEars(context: &context, s: s, cx: cx, cy: cy, strokeColor: strokeColor, strokeW: strokeW)
        drawFace(context: &context, s: s, cx: cx, cy: cy, faceColor: faceColor, strokeColor: strokeColor, strokeW: strokeW)
        drawExpression(context: &context, s: s, cx: cx, cy: cy, strokeColor: strokeColor, strokeW: strokeW)

        // Star and crown drawn on top
        if definition.accessory == .star {
            drawStar(context: &context, s: s, cx: cx, cy: cy, strokeW: strokeW)
        } else if definition.accessory == .crown {
            drawCrown(context: &context, s: s, cx: cx, cy: cy, strokeW: strokeW)
        }
    }

    // MARK: - Body Parts

    private func drawLegs(context: inout GraphicsContext, s: CGFloat, cx: CGFloat, cy: CGFloat, strokeW: CGFloat) {
        let legW = s * 0.07
        let legH = s * 0.14
        let legY = cy + s * 0.26
        let legColor = Color(red: 0.35, green: 0.30, blue: 0.28)
        for xOff in [-0.14, -0.05, 0.05, 0.14] {
            let lx = cx + s * CGFloat(xOff)
            let lr = CGRect(x: lx - legW / 2, y: legY, width: legW, height: legH)
            context.fill(Path(roundedRect: lr, cornerSize: CGSize(width: legW * 0.3, height: legW * 0.3)), with: .color(legColor))
        }
    }

    private func drawWool(context: inout GraphicsContext, s: CGFloat, cx: CGFloat, cy: CGFloat, woolColor: Color, strokeColor: Color, strokeW: CGFloat) {
        let woolR = s * 0.42
        let bumpR = s * 0.20
        var woolPath = Path()
        for i in 0..<8 {
            let angle = Double(i) * .pi * 2 / 8 - .pi / 2
            let bx = cx + cos(angle) * woolR * 0.52
            let by = cy + sin(angle) * woolR * 0.52 - s * 0.02
            let r = CGRect(x: bx - bumpR, y: by - bumpR, width: bumpR * 2, height: bumpR * 2)
            woolPath.addEllipse(in: r)
        }
        context.fill(woolPath, with: .color(woolColor))
        context.stroke(woolPath, with: .color(strokeColor.opacity(0.2)), lineWidth: strokeW * 0.5)
    }

    private func drawEars(context: inout GraphicsContext, s: CGFloat, cx: CGFloat, cy: CGFloat, strokeColor: Color, strokeW: CGFloat) {
        let earW = s * 0.11
        let earH = s * 0.15
        let earY = cy - s * 0.02
        for side in [-1.0, 1.0] {
            let ex = side < 0 ? cx - s * 0.30 : cx + s * 0.30 - earW
            let er = CGRect(x: ex, y: earY - earH / 2, width: earW, height: earH)
            context.fill(Path(ellipseIn: er), with: .color(Color(red: 0.95, green: 0.80, blue: 0.75)))
            context.stroke(Path(ellipseIn: er), with: .color(strokeColor.opacity(0.2)), lineWidth: strokeW * 0.5)
        }
    }

    private func drawFace(context: inout GraphicsContext, s: CGFloat, cx: CGFloat, cy: CGFloat, faceColor: Color, strokeColor: Color, strokeW: CGFloat) {
        let faceW = s * 0.44
        let faceH = s * 0.38
        let faceY = cy + s * 0.04
        let faceRect = CGRect(x: cx - faceW / 2, y: faceY - faceH / 2, width: faceW, height: faceH)
        context.fill(Path(ellipseIn: faceRect), with: .color(faceColor))
        context.stroke(Path(ellipseIn: faceRect), with: .color(strokeColor.opacity(0.15)), lineWidth: strokeW * 0.5)
    }

    private func drawExpression(context: inout GraphicsContext, s: CGFloat, cx: CGFloat, cy: CGFloat, strokeColor: Color, strokeW: CGFloat) {
        let faceY = cy + s * 0.04
        let eyeY = faceY - s * 0.03
        let eyeSpacing = s * 0.09
        let mouthY = faceY + s * 0.08

        if isAwake {
            let dotR = s * 0.025
            for side in [-1.0, 1.0] {
                let ex = cx + side * eyeSpacing
                let dr = CGRect(x: ex - dotR, y: eyeY - dotR, width: dotR * 2, height: dotR * 2)
                context.fill(Path(ellipseIn: dr), with: .color(strokeColor))
            }
            var smile = Path()
            smile.move(to: CGPoint(x: cx - s * 0.05, y: mouthY))
            smile.addQuadCurve(
                to: CGPoint(x: cx + s * 0.05, y: mouthY),
                control: CGPoint(x: cx, y: mouthY + s * 0.04))
            context.stroke(smile, with: .color(strokeColor), lineWidth: strokeW * 1.2)
        } else {
            for side in [-1.0, 1.0] {
                let ex = cx + side * eyeSpacing
                var dash = Path()
                dash.move(to: CGPoint(x: ex - s * 0.03, y: eyeY))
                dash.addLine(to: CGPoint(x: ex + s * 0.03, y: eyeY))
                context.stroke(dash, with: .color(strokeColor), lineWidth: strokeW * 1.2)
            }
            var line = Path()
            line.move(to: CGPoint(x: cx - s * 0.04, y: mouthY))
            line.addLine(to: CGPoint(x: cx + s * 0.04, y: mouthY))
            context.stroke(line, with: .color(strokeColor), lineWidth: strokeW * 1.0)
        }
    }

    // MARK: - Accessories

    private func drawStar(context: inout GraphicsContext, s: CGFloat, cx: CGFloat, cy: CGFloat, strokeW: CGFloat) {
        let goldFill = Color(red: 1.0, green: 0.85, blue: 0.25)
        let goldStroke = Color(red: 0.85, green: 0.65, blue: 0.10)
        let starCY = cy - s * 0.46
        let outerR = s * 0.12
        let innerR = s * 0.05
        var star = Path()
        for i in 0..<10 {
            let angle = Double(i) * .pi / 5.0 - .pi / 2
            let r: CGFloat = i % 2 == 0 ? outerR : innerR
            let pt = CGPoint(x: cx + CGFloat(cos(angle)) * r, y: starCY + CGFloat(sin(angle)) * r)
            if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()
        context.fill(star, with: .color(goldFill))
        context.stroke(star, with: .color(goldStroke), lineWidth: strokeW * 0.8)
    }

    private func drawCrown(context: inout GraphicsContext, s: CGFloat, cx: CGFloat, cy: CGFloat, strokeW: CGFloat) {
        let goldFill = Color(red: 1.0, green: 0.85, blue: 0.25)
        let goldStroke = Color(red: 0.85, green: 0.65, blue: 0.10)
        let crownTop = cy - s * 0.50
        let crownBot = cy - s * 0.34
        let crownW = s * 0.28
        let h = crownBot - crownTop
        var crown = Path()
        crown.move(to: CGPoint(x: cx - crownW / 2, y: crownBot))
        crown.addLine(to: CGPoint(x: cx - crownW / 2, y: crownTop + h * 0.35))
        crown.addLine(to: CGPoint(x: cx - crownW / 4, y: crownTop + h * 0.55))
        crown.addLine(to: CGPoint(x: cx, y: crownTop))
        crown.addLine(to: CGPoint(x: cx + crownW / 4, y: crownTop + h * 0.55))
        crown.addLine(to: CGPoint(x: cx + crownW / 2, y: crownTop + h * 0.35))
        crown.addLine(to: CGPoint(x: cx + crownW / 2, y: crownBot))
        crown.closeSubpath()
        context.fill(crown, with: .color(goldFill))
        context.stroke(crown, with: .color(goldStroke), lineWidth: strokeW * 0.8)
    }

    private func drawWings(context: inout GraphicsContext, s: CGFloat, cx: CGFloat, cy: CGFloat, strokeColor: Color, strokeW: CGFloat) {
        let wingY = cy + s * 0.02
        let wingW = s * 0.16
        let wingH = s * 0.22
        let wingColor = Color.white.opacity(0.85)
        for side in [-1.0, 1.0] {
            let wx = side < 0 ? cx - s * 0.42 : cx + s * 0.42 - wingW
            let wr = CGRect(x: wx, y: wingY - wingH / 2, width: wingW, height: wingH)
            context.fill(Path(ellipseIn: wr), with: .color(wingColor))
            context.stroke(Path(ellipseIn: wr), with: .color(strokeColor.opacity(0.15)), lineWidth: strokeW * 0.5)
        }
    }
}
