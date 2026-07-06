import SwiftUI

/// Lightweight confetti burst rendered with Canvas — no dependencies.
struct ConfettiView: View {
    private struct Particle {
        let x0: Double        // normalized start x
        let vx: Double        // horizontal drift, screen-widths / s
        let vy: Double        // initial vertical velocity, screen-heights / s
        let size: Double
        let spin: Double
        let color: Color
        let delay: Double
    }

    private static let colors: [Color] = [.pink, .orange, .yellow, .mint, .blue, .purple]

    @State private var particles: [Particle] = (0..<90).map { _ in
        Particle(
            x0: .random(in: 0...1),
            vx: .random(in: -0.15...0.15),
            vy: .random(in: -1.4 ... -0.6),
            size: .random(in: 6...12),
            spin: .random(in: -6...6),
            color: Self.colors.randomElement()!,
            delay: .random(in: 0...0.25)
        )
    }
    private let startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                for p in particles {
                    let t = elapsed - p.delay
                    guard t > 0 else { continue }
                    let x = (p.x0 + p.vx * t) * size.width
                    let y = (0.55 + p.vy * t + 0.5 * 1.9 * t * t) * size.height
                    guard y < size.height + 20 else { continue }

                    let opacity = max(0, 1.0 - t / 2.2)
                    var context = ctx
                    context.translateBy(x: x, y: y)
                    context.rotate(by: .radians(p.spin * t))
                    let rect = CGRect(x: -p.size / 2, y: -p.size / 3.4, width: p.size, height: p.size * 0.6)
                    context.fill(Path(rect), with: .color(p.color.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
