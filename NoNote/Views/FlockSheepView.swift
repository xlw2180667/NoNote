import SwiftUI

struct FlockSheepView: View {
    let definition: SheepDefinition
    let isAwake: Bool
    var size: CGFloat = 48
    @State private var bobOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Canvas { context, canvasSize in
                let s = min(canvasSize.width, canvasSize.height)
                let cx = canvasSize.width / 2
                let cy = canvasSize.height / 2 + s * 0.04

                let woolColor = definition.woolColor
                let faceColor = Color(red: 0.99, green: 0.97, blue: 0.94)
                let strokeColor = Color(red: 0.35, green: 0.30, blue: 0.28)
                let strokeW = max(s * 0.03, 0.5)

                // ── Accessory: Wings (behind body) ──
                if definition.accessory == .wings {
                    for side in [-1.0, 1.0] {
                        var wing = Path()
                        let wx = cx + side * s * 0.38
                        let wy = cy - s * 0.08
                        wing.move(to: CGPoint(x: cx + side * s * 0.18, y: wy))
                        wing.addQuadCurve(
                            to: CGPoint(x: cx + side * s * 0.18, y: wy + s * 0.22),
                            control: CGPoint(x: wx, y: wy + s * 0.05))
                        wing.addQuadCurve(
                            to: CGPoint(x: cx + side * s * 0.18, y: wy),
                            control: CGPoint(x: wx - side * s * 0.05, y: wy + s * 0.18))
                        context.fill(wing, with: .color(.white.opacity(0.8)))
                        context.stroke(wing, with: .color(strokeColor.opacity(0.2)), lineWidth: strokeW * 0.5)
                    }
                }

                // ── Legs (4 stubs) ──
                let legW = s * 0.07
                let legH = s * 0.14
                let legY = cy + s * 0.26
                let legColor = Color(red: 0.35, green: 0.30, blue: 0.28)
                for xOff in [-0.14, -0.05, 0.05, 0.14] {
                    let lx = cx + s * CGFloat(xOff)
                    let lr = CGRect(x: lx - legW / 2, y: legY, width: legW, height: legH)
                    context.fill(Path(roundedRect: lr, cornerSize: CGSize(width: legW * 0.3, height: legW * 0.3)), with: .color(legColor))
                }

                // ── Wool (scalloped cloud) ──
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

                // ── Ears ──
                let earW = s * 0.11
                let earH = s * 0.15
                let earY = cy - s * 0.02
                for side in [-1.0, 1.0] {
                    let ex = side < 0 ? cx - s * 0.30 : cx + s * 0.30 - earW
                    let er = CGRect(x: ex, y: earY - earH / 2, width: earW, height: earH)
                    context.fill(Path(ellipseIn: er), with: .color(Color(red: 0.95, green: 0.80, blue: 0.75)))
                    context.stroke(Path(ellipseIn: er), with: .color(strokeColor.opacity(0.2)), lineWidth: strokeW * 0.5)
                }

                // ── Face oval ──
                let faceW = s * 0.44
                let faceH = s * 0.38
                let faceY = cy + s * 0.04
                let faceRect = CGRect(x: cx - faceW / 2, y: faceY - faceH / 2, width: faceW, height: faceH)
                context.fill(Path(ellipseIn: faceRect), with: .color(faceColor))
                context.stroke(Path(ellipseIn: faceRect), with: .color(strokeColor.opacity(0.15)), lineWidth: strokeW * 0.5)

                // ── Expression ──
                let eyeY = faceY - s * 0.03
                let eyeSpacing = s * 0.09
                let mouthY = faceY + s * 0.08

                if isAwake {
                    // Dot eyes
                    let dotR = s * 0.025
                    for side in [-1.0, 1.0] {
                        let ex = cx + side * eyeSpacing
                        let dr = CGRect(x: ex - dotR, y: eyeY - dotR, width: dotR * 2, height: dotR * 2)
                        context.fill(Path(ellipseIn: dr), with: .color(strokeColor))
                    }
                    // Gentle smile
                    var smile = Path()
                    smile.move(to: CGPoint(x: cx - s * 0.05, y: mouthY))
                    smile.addQuadCurve(
                        to: CGPoint(x: cx + s * 0.05, y: mouthY),
                        control: CGPoint(x: cx, y: mouthY + s * 0.04))
                    context.stroke(smile, with: .color(strokeColor), lineWidth: strokeW * 1.2)
                } else {
                    // Closed eyes (dashes)
                    for side in [-1.0, 1.0] {
                        let ex = cx + side * eyeSpacing
                        var dash = Path()
                        dash.move(to: CGPoint(x: ex - s * 0.03, y: eyeY))
                        dash.addLine(to: CGPoint(x: ex + s * 0.03, y: eyeY))
                        context.stroke(dash, with: .color(strokeColor), lineWidth: strokeW * 1.2)
                    }
                    // Flat mouth
                    var line = Path()
                    line.move(to: CGPoint(x: cx - s * 0.04, y: mouthY))
                    line.addLine(to: CGPoint(x: cx + s * 0.04, y: mouthY))
                    context.stroke(line, with: .color(strokeColor), lineWidth: strokeW * 1.0)
                }

                // ── Accessory: Star (above head) ──
                if definition.accessory == .star {
                    let starCx = cx
                    let starCy = cy - s * 0.38
                    let outerR = s * 0.08
                    let innerR = s * 0.035
                    var starPath = Path()
                    for i in 0..<10 {
                        let r = i % 2 == 0 ? outerR : innerR
                        let angle = Double(i) * .pi / 5 - .pi / 2
                        let px = starCx + cos(angle) * r
                        let py = starCy + sin(angle) * r
                        if i == 0 {
                            starPath.move(to: CGPoint(x: px, y: py))
                        } else {
                            starPath.addLine(to: CGPoint(x: px, y: py))
                        }
                    }
                    starPath.closeSubpath()
                    context.fill(starPath, with: .color(Color(red: 1.0, green: 0.85, blue: 0.2)))
                    context.stroke(starPath, with: .color(Color(red: 0.85, green: 0.70, blue: 0.1)), lineWidth: strokeW * 0.7)
                }

                // ── Accessory: Crown (above head) ──
                if definition.accessory == .crown {
                    let crownY = cy - s * 0.35
                    let crownW = s * 0.22
                    let crownH = s * 0.12
                    var crownPath = Path()
                    crownPath.move(to: CGPoint(x: cx - crownW / 2, y: crownY + crownH))
                    crownPath.addLine(to: CGPoint(x: cx - crownW / 2, y: crownY + crownH * 0.3))
                    crownPath.addLine(to: CGPoint(x: cx - crownW * 0.2, y: crownY + crownH * 0.6))
                    crownPath.addLine(to: CGPoint(x: cx, y: crownY))
                    crownPath.addLine(to: CGPoint(x: cx + crownW * 0.2, y: crownY + crownH * 0.6))
                    crownPath.addLine(to: CGPoint(x: cx + crownW / 2, y: crownY + crownH * 0.3))
                    crownPath.addLine(to: CGPoint(x: cx + crownW / 2, y: crownY + crownH))
                    crownPath.closeSubpath()
                    context.fill(crownPath, with: .color(Color(red: 1.0, green: 0.85, blue: 0.2)))
                    context.stroke(crownPath, with: .color(Color(red: 0.85, green: 0.70, blue: 0.1)), lineWidth: strokeW * 0.7)
                }
            }
            .frame(width: size, height: size)

            // ZZZ for sleeping sheep
            if !isAwake {
                Text("z z z")
                    .font(.system(size: size * 0.14, weight: .bold))
                    .foregroundColor(.textSecondary.opacity(0.6))
                    .offset(x: size * 0.15, y: -size * 0.38)
            }
        }
        .offset(y: bobOffset)
        .onAppear {
            if isAwake {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    bobOffset = -3
                }
            }
        }
    }
}
