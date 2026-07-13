import AppKit
import SwiftUI

struct CatKeyboardLockCelebrationMark: View {
    let tint: Color
    var title: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ForEach(0..<12, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 3) ? Color.orange : tint.opacity(0.75))
                        .frame(
                            width: index.isMultiple(of: 3) ? 7 : 5,
                            height: index.isMultiple(of: 3) ? 7 : 5
                        )
                        .offset(
                            x: animate ? cos(CGFloat(index) * .pi / 6) * 42 : 0,
                            y: animate ? sin(CGFloat(index) * .pi / 6) * 42 : 0
                        )
                        .opacity(animate ? 1 : 0)
                }

                Text("🎉")
                    .font(.system(size: 44))
                    .scaleEffect(animate || reduceMotion ? 1 : 0.82)
            }
            .frame(width: 100, height: 74)

            if let title {
                Text(title)
                    .font(.headline)
            }
        }
        .onAppear {
            guard reduceMotion == false else {
                animate = true
                return
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                animate = true
            }
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
}
