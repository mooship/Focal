import SwiftUI

struct ConfettiView: View {
    private struct Particle {
        let startX: Double
        let vx: Double
        let vy0: Double
        let angle0: Double
        let angularVelocity: Double
        let width: Double
        let height: Double
        let color: Color
        let spawnDelay: Double
    }

    @State private var particles: [Particle] = []
    @State private var startDate = Date.distantFuture

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                guard size.width > 0, size.height > 0 else {
                    return
                }
                let t = timeline.date.timeIntervalSince(startDate)
                for p in particles {
                    let elapsed = t - p.spawnDelay
                    guard elapsed > 0 else {
                        continue
                    }
                    let alpha = max(0, 1.0 - 0.3 * elapsed)
                    guard alpha > 0 else {
                        continue
                    }
                    let px = p.startX * size.width + p.vx * elapsed
                    let py = p.vy0 * elapsed + 75 * elapsed * elapsed
                    guard py < size.height + 20 else {
                        continue
                    }
                    let angle = p.angle0 + p.angularVelocity * elapsed
                    let hw = p.width / 2
                    let hh = p.height / 2
                    let transform = CGAffineTransform.identity
                        .rotated(by: angle)
                        .translatedBy(x: px, y: py)
                    ctx.fill(
                        Path(CGRect(x: -hw, y: -hh, width: p.width, height: p.height))
                            .applying(transform),
                        with: .color(p.color.opacity(alpha))
                    )
                }
            }
        }
        .onAppear {
            guard particles.isEmpty else {
                return
            }
            var rng = SystemRandomNumberGenerator()
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .white]
            var ps = [Particle]()
            ps.reserveCapacity(120)
            for color in colors {
                for _ in 0..<15 {
                    ps.append(Particle(
                        startX: Double.random(in: 0...1, using: &rng),
                        vx: Double.random(in: -150...150, using: &rng),
                        vy0: Double.random(in: 150 ... 450, using: &rng),
                        angle0: Double.random(in: 0 ... 2 * .pi, using: &rng),
                        angularVelocity: Double.random(in: -6...6, using: &rng),
                        width: Double.random(in: 6...10, using: &rng),
                        height: Double.random(in: 3...6, using: &rng),
                        color: color,
                        spawnDelay: Double.random(in: 0...0.4, using: &rng)
                    ))
                }
            }
            particles = ps
            startDate = .now
        }
    }
}
