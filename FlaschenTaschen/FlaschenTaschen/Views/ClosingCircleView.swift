// ClosingCircleView.swift

import SwiftUI

struct ClosingCircleView: View {
    let percentClosed: CGFloat
    let size: CGFloat

    @Environment(\.colorScheme) var colorScheme

    var backgroundColor: Color {
        colorScheme == .light ? Color.white.opacity(0.15) : Color.black.opacity(0.25)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)

            PieSlice(percentage: percentClosed / 100)
                .fill(.gray.opacity(0.5))

            Circle()
                .stroke(.gray.opacity(0.4), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }
}

struct PieSlice: Shape {
    let percentage: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        let startAngle = Angle(degrees: -90)
        let endAngle = Angle(degrees: -90 + (percentage * 360))

        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()

        return path
    }
}

#Preview {
    VStack(spacing: 20) {
        VStack(alignment: .leading) {
            Text("Light Mode")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                ClosingCircleView(percentClosed: 0.0, size: 40.0)
                ClosingCircleView(percentClosed: 25.0, size: 40.0)
                ClosingCircleView(percentClosed: 50.0, size: 40.0)
                ClosingCircleView(percentClosed: 75.0, size: 40.0)
                ClosingCircleView(percentClosed: 100.0, size: 40.0)
            }
        }

        VStack(alignment: .leading) {
            Text("Dark Mode")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                ClosingCircleView(percentClosed: 0.0, size: 40.0)
                ClosingCircleView(percentClosed: 25.0, size: 40.0)
                ClosingCircleView(percentClosed: 50.0, size: 40.0)
                ClosingCircleView(percentClosed: 75.0, size: 40.0)
                ClosingCircleView(percentClosed: 100.0, size: 40.0)
            }
            .preferredColorScheme(.dark)
        }
    }
    .padding()
}


#Preview {
}
