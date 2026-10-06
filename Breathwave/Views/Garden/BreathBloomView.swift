import SwiftUI

/// Draws one bloom from its parameters: translucent petal layers around
/// a bright core. Pure Canvas, no assets.
struct BreathBloomView: View {
    let parameters: BloomParameters

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            var random = BloomParameters.SplitMix64(seed: parameters.seed)
            for layer in 0..<parameters.layerCount {
                let petalLength = radius * (1 - Double(layer) * 0.28)
                let hue = (parameters.baseHue + Double(layer) * 0.03).truncatingRemainder(dividingBy: 1)
                // Alternate layers sit between the petals below them.
                let twist = parameters.rotationOffset + Double(layer) * .pi / Double(parameters.petalCount)
                for petal in 0..<parameters.petalCount {
                    let angle = twist + Double(petal) / Double(parameters.petalCount) * 2 * .pi
                    let wobble = 1 - parameters.petalWobble / 2 + random.unit() * parameters.petalWobble
                    var petalContext = context
                    petalContext.translateBy(x: center.x, y: center.y)
                    petalContext.rotate(by: .radians(angle))
                    let length = petalLength * wobble
                    let width = length * parameters.petalAspect
                    petalContext.fill(
                        Ellipse().path(in: CGRect(x: -width / 2, y: -length, width: width, height: length)),
                        with: .color(Color(hue: hue, saturation: 0.45, brightness: 0.92, opacity: 0.35))
                    )
                }
            }
            let coreRadius = radius * 0.13
            context.fill(
                Circle().path(in: CGRect(
                    x: center.x - coreRadius, y: center.y - coreRadius,
                    width: coreRadius * 2, height: coreRadius * 2
                )),
                with: .color(Color(hue: parameters.baseHue, saturation: 0.28, brightness: 1, opacity: 0.9))
            )
        }
    }
}

#Preview {
    BreathBloomView(parameters: .from(Session(
        completedAt: .now,
        duration: 600,
        kind: .breathing(protocolID: "box")
    )))
    .frame(width: 260, height: 260)
}
