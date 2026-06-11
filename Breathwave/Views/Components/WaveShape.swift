import SwiftUI

/// Sine-wave water surface. `level` is the fill height (0 = empty, 1 = full),
/// `phase` scrolls the wave horizontally for a living-water feel.
struct WaveShape: Shape {
    var level: Double
    var phase: Double
    /// Crest height as a fraction of the rect height.
    var amplitude: Double = 0.04
    /// Full sine periods across the width.
    var waves: Double = 1.6

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 2
        path.move(to: CGPoint(x: rect.minX, y: surfaceY(atX: rect.minX, in: rect)))
        var x = rect.minX + step
        while x < rect.maxX {
            path.addLine(to: CGPoint(x: x, y: surfaceY(atX: x, in: rect)))
            x += step
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: surfaceY(atX: rect.maxX, in: rect)))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    private func surfaceY(atX x: CGFloat, in rect: CGRect) -> CGFloat {
        let surface = rect.minY + rect.height * (1 - level)
        let relative = (x - rect.minX) / rect.width
        let angle = relative * waves * 2 * .pi + phase
        return surface + sin(angle) * rect.height * amplitude
    }
}
