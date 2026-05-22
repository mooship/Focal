import SwiftUI
import UIKit

struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> ConfettiUIView { ConfettiUIView() }
    func updateUIView(_ uiView: ConfettiUIView, context: Context) {}
}

final class ConfettiUIView: UIView {
    private let emitter = CAEmitterLayer()
    private var fired = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.addSublayer(emitter)
        emitter.emitterShape = .line
        emitter.birthRate = 0
        emitter.emitterCells = Self.makeCells()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !fired, bounds.size != .zero else { return }
        fired = true
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.height * 0.3)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        emitter.birthRate = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.emitter.birthRate = 0
        }
    }

    private static func makeCells() -> [CAEmitterCell] {
        let colors: [UIColor] = [
            .systemRed, .systemOrange, .systemYellow, .systemGreen,
            .systemBlue, .systemPurple, .systemPink, .white
        ]
        let image = confettiImage()
        return colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 35
            cell.lifetime = 2.0
            cell.velocity = 300
            cell.velocityRange = 150
            cell.emissionLongitude = .pi / 2
            cell.emissionRange = .pi / 4
            cell.spin = 2 * .pi
            cell.spinRange = .pi
            cell.yAcceleration = 150
            cell.scale = 0.6
            cell.scaleRange = 0.3
            cell.alphaSpeed = -0.3
            cell.color = color.cgColor
            cell.contents = image.cgImage
            return cell
        }
    }

    private static func confettiImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 5)).image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 8, height: 5)).fill()
        }
    }
}
