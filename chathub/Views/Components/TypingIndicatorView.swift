import UIKit

class TypingIndicatorView: UIView {
    private let stackView = UIStackView()
    private var dotViews: [UIView] = []
    private let label = UILabel()
    private let dotCount = 3
    private let dotSize: CGFloat = 8
    private let dotSpacing: CGFloat = 6
    private let animationDuration: CFTimeInterval = 0.6

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = dotSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Add dots
        for i in 0..<dotCount {
            let dot = UIView()
            dot.backgroundColor = UIColor.systemPurple
            dot.layer.cornerRadius = dotSize / 2
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: dotSize).isActive = true
            dot.heightAnchor.constraint(equalToConstant: dotSize).isActive = true
            stackView.addArrangedSubview(dot)
            dotViews.append(dot)
            animateDot(dot, at: i)
        }

        // Add label
        label.text = "AI is typing"
        label.font = UIFont.italicSystemFont(ofSize: 15)
        label.textColor = UIColor.systemPurple
        label.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(label)
        label.leadingAnchor.constraint(equalTo: dotViews.last!.trailingAnchor, constant: 8).isActive = true
    }

    private func animateDot(_ dot: UIView, at index: Int) {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 0.3
        animation.duration = animationDuration
        animation.repeatCount = .infinity
        animation.autoreverses = true
        animation.beginTime = CACurrentMediaTime() + (Double(index) * animationDuration / Double(dotCount))
        dot.layer.add(animation, forKey: "pulsing")
    }
} 