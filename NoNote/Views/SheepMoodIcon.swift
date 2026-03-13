import SwiftUI

struct SheepMood {
    let id: String
    let labelKey: String
    let color: Color

    static let happy   = SheepMood(id: "happy",   labelKey: "#moodHappy",   color: Color(red: 0.95, green: 0.77, blue: 0.06))
    static let good    = SheepMood(id: "good",    labelKey: "#moodGood",    color: Color(red: 0.30, green: 0.78, blue: 0.47))
    static let neutral = SheepMood(id: "neutral", labelKey: "#moodNeutral", color: Color(red: 0.60, green: 0.60, blue: 0.60))
    static let sad     = SheepMood(id: "sad",     labelKey: "#moodSad",     color: Color(red: 0.35, green: 0.60, blue: 0.92))
    static let angry   = SheepMood(id: "angry",   labelKey: "#moodAngry",   color: Color(red: 0.90, green: 0.30, blue: 0.30))

    static let all: [SheepMood] = [happy, good, neutral, sad, angry]

    private static let idSet: Set<String> = Set(all.map(\.id))

    static func isSheepMood(_ mood: String) -> Bool {
        idSet.contains(mood)
    }

    static func color(for mood: String) -> Color? {
        all.first { $0.id == mood }?.color
    }
}

struct SheepMoodIcon: View {
    let mood: String
    var size: CGFloat = 36

    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2

            let moodColor = SheepMood.color(for: mood) ?? .gray
            let woolColor = Color(red: 0.96, green: 0.94, blue: 0.90)
            let faceColor = Color(red: 0.99, green: 0.97, blue: 0.94)
            let strokeColor = Color(red: 0.35, green: 0.30, blue: 0.28)
            let strokeW = max(s * 0.03, 0.5)

            // ── Wool (scalloped cloud) ──
            // 8 overlapping circles forming a fluffy ring
            let woolR = s * 0.46
            let bumpR = s * 0.22
            var woolPath = Path()
            for i in 0..<8 {
                let angle = Double(i) * .pi * 2 / 8 - .pi / 2
                let bx = cx + cos(angle) * woolR * 0.52
                let by = cy + sin(angle) * woolR * 0.52 - s * 0.02
                let r = CGRect(x: bx - bumpR, y: by - bumpR, width: bumpR * 2, height: bumpR * 2)
                woolPath.addEllipse(in: r)
            }
            context.fill(woolPath, with: .color(woolColor))
            context.stroke(woolPath, with: .color(strokeColor.opacity(0.25)), lineWidth: strokeW * 0.5)

            // ── Ears ──
            let earW = s * 0.13
            let earH = s * 0.18
            let earY = cy - s * 0.02
            // Left
            let le = CGRect(x: cx - s * 0.36, y: earY - earH / 2, width: earW, height: earH)
            context.fill(Path(ellipseIn: le), with: .color(moodColor.opacity(0.5)))
            context.stroke(Path(ellipseIn: le), with: .color(strokeColor.opacity(0.3)), lineWidth: strokeW * 0.5)
            // Right
            let re = CGRect(x: cx + s * 0.36 - earW, y: earY - earH / 2, width: earW, height: earH)
            context.fill(Path(ellipseIn: re), with: .color(moodColor.opacity(0.5)))
            context.stroke(Path(ellipseIn: re), with: .color(strokeColor.opacity(0.3)), lineWidth: strokeW * 0.5)

            // ── Face oval ──
            let faceW = s * 0.48
            let faceH = s * 0.42
            let faceY = cy + s * 0.04
            let faceRect = CGRect(x: cx - faceW / 2, y: faceY - faceH / 2, width: faceW, height: faceH)
            context.fill(Path(ellipseIn: faceRect), with: .color(faceColor))
            context.stroke(Path(ellipseIn: faceRect), with: .color(strokeColor.opacity(0.2)), lineWidth: strokeW * 0.5)

            // ── Expression ──
            let eyeY = faceY - s * 0.04
            let eyeSpacing = s * 0.10
            let mouthY = faceY + s * 0.10

            switch mood {
            case "happy":
                // ^^ happy closed eyes (arcs)
                for side in [-1.0, 1.0] {
                    let ex = cx + side * eyeSpacing
                    let ew = s * 0.07
                    var arc = Path()
                    arc.move(to: CGPoint(x: ex - ew, y: eyeY + s * 0.01))
                    arc.addQuadCurve(
                        to: CGPoint(x: ex + ew, y: eyeY + s * 0.01),
                        control: CGPoint(x: ex, y: eyeY - s * 0.05))
                    context.stroke(arc, with: .color(strokeColor), lineWidth: strokeW * 1.5)
                }
                // Wide smile
                var smile = Path()
                smile.move(to: CGPoint(x: cx - s * 0.09, y: mouthY - s * 0.01))
                smile.addQuadCurve(
                    to: CGPoint(x: cx + s * 0.09, y: mouthY - s * 0.01),
                    control: CGPoint(x: cx, y: mouthY + s * 0.08))
                context.stroke(smile, with: .color(strokeColor), lineWidth: strokeW * 1.2)
                // Rosy cheeks
                let blushR = s * 0.05
                for side in [-1.0, 1.0] {
                    let bx = cx + side * s * 0.16
                    let by = mouthY - s * 0.01
                    let br = CGRect(x: bx - blushR, y: by - blushR, width: blushR * 2, height: blushR * 2)
                    context.fill(Path(ellipseIn: br), with: .color(Color(red: 1.0, green: 0.55, blue: 0.55).opacity(0.45)))
                }

            case "good":
                // Dot eyes
                let dotR = s * 0.03
                for side in [-1.0, 1.0] {
                    let ex = cx + side * eyeSpacing
                    let dr = CGRect(x: ex - dotR, y: eyeY - dotR, width: dotR * 2, height: dotR * 2)
                    context.fill(Path(ellipseIn: dr), with: .color(strokeColor))
                }
                // Gentle smile
                var smile = Path()
                smile.move(to: CGPoint(x: cx - s * 0.06, y: mouthY))
                smile.addQuadCurve(
                    to: CGPoint(x: cx + s * 0.06, y: mouthY),
                    control: CGPoint(x: cx, y: mouthY + s * 0.05))
                context.stroke(smile, with: .color(strokeColor), lineWidth: strokeW * 1.2)

            case "neutral":
                // Dot eyes
                let dotR = s * 0.03
                for side in [-1.0, 1.0] {
                    let ex = cx + side * eyeSpacing
                    let dr = CGRect(x: ex - dotR, y: eyeY - dotR, width: dotR * 2, height: dotR * 2)
                    context.fill(Path(ellipseIn: dr), with: .color(strokeColor))
                }
                // Flat mouth
                var line = Path()
                line.move(to: CGPoint(x: cx - s * 0.06, y: mouthY))
                line.addLine(to: CGPoint(x: cx + s * 0.06, y: mouthY))
                context.stroke(line, with: .color(strokeColor), lineWidth: strokeW * 1.2)

            case "sad":
                // Dot eyes
                let dotR = s * 0.03
                for side in [-1.0, 1.0] {
                    let ex = cx + side * eyeSpacing
                    let dr = CGRect(x: ex - dotR, y: eyeY - dotR, width: dotR * 2, height: dotR * 2)
                    context.fill(Path(ellipseIn: dr), with: .color(strokeColor))
                }
                // Frown
                var frown = Path()
                frown.move(to: CGPoint(x: cx - s * 0.06, y: mouthY + s * 0.03))
                frown.addQuadCurve(
                    to: CGPoint(x: cx + s * 0.06, y: mouthY + s * 0.03),
                    control: CGPoint(x: cx, y: mouthY - s * 0.04))
                context.stroke(frown, with: .color(strokeColor), lineWidth: strokeW * 1.2)
                // Teardrop
                let tearR = s * 0.025
                let tearX = cx + eyeSpacing + s * 0.01
                let tearY = eyeY + s * 0.07
                let tr = CGRect(x: tearX - tearR, y: tearY - tearR, width: tearR * 2, height: tearR * 2)
                context.fill(Path(ellipseIn: tr), with: .color(Color(red: 0.45, green: 0.70, blue: 0.95).opacity(0.7)))

            case "angry":
                // Dot eyes
                let dotR = s * 0.03
                for side in [-1.0, 1.0] {
                    let ex = cx + side * eyeSpacing
                    let dr = CGRect(x: ex - dotR, y: eyeY - dotR, width: dotR * 2, height: dotR * 2)
                    context.fill(Path(ellipseIn: dr), with: .color(strokeColor))
                }
                // V-shaped angry brows
                for side in [-1.0, 1.0] {
                    let ex = cx + side * eyeSpacing
                    let browW = s * 0.07
                    var brow = Path()
                    brow.move(to: CGPoint(x: ex - side * browW, y: eyeY - s * 0.07))
                    brow.addLine(to: CGPoint(x: ex + side * browW, y: eyeY - s * 0.11))
                    context.stroke(brow, with: .color(strokeColor), lineWidth: strokeW * 1.5)
                }
                // Frown
                var frown = Path()
                frown.move(to: CGPoint(x: cx - s * 0.06, y: mouthY + s * 0.03))
                frown.addQuadCurve(
                    to: CGPoint(x: cx + s * 0.06, y: mouthY + s * 0.03),
                    control: CGPoint(x: cx, y: mouthY - s * 0.04))
                context.stroke(frown, with: .color(strokeColor), lineWidth: strokeW * 1.2)

            default:
                break
            }
        }
        .frame(width: size, height: size)
    }
}
