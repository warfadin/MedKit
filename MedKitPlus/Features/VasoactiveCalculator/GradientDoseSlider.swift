import SwiftUI

struct GradientDoseSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let intensity: DoseIntensity
    let lowDoseUpperBound: Double
    let mediumDoseUpperBound: Double
    let concentrationMcgPerMl: Double
    let weightKg: Int

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let progress = normalizedProgress
            let thumbSize: CGFloat = 42
            let thumbX = max(thumbSize / 2, min(width - thumbSize / 2, progress * width))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: sliderStops,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 14)
                    .opacity(0.95)

                Capsule()
                    .fill(.black.opacity(0.10))
                    .frame(height: 14)

                Circle()
                    .fill(VasoactiveAgentTheme.color(for: intensity))
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .shadow(color: .black.opacity(0.20), radius: 7, y: 3)
                    .offset(x: thumbX - thumbSize / 2)
            }
            .frame(height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let clampedX = min(max(gesture.location.x, 0), width)
                        value = VasoactiveDoseCalculator.dose(
                            forProgress: clampedX / width,
                            range: range,
                            concentrationMcgPerMl: concentrationMcgPerMl,
                            weightKg: weightKg
                        )
                    }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Doz slider")
        .accessibilityValue("\(value, specifier: "%.3f") mcg/kg/dk")
    }

    private var normalizedProgress: Double {
        VasoactiveDoseCalculator.progress(
            forDose: value,
            range: range,
            concentrationMcgPerMl: concentrationMcgPerMl,
            weightKg: weightKg
        )
    }

    private var sliderStops: [Gradient.Stop] {
        let lowStop = CGFloat(
            VasoactiveDoseCalculator.progress(
                forDose: lowDoseUpperBound,
                range: range,
                concentrationMcgPerMl: concentrationMcgPerMl,
                weightKg: weightKg
            )
        )
        let mediumStop = CGFloat(
            VasoactiveDoseCalculator.progress(
                forDose: mediumDoseUpperBound,
                range: range,
                concentrationMcgPerMl: concentrationMcgPerMl,
                weightKg: weightKg
            )
        )

        return [
            Gradient.Stop(color: .green, location: 0),
            Gradient.Stop(color: .green, location: lowStop),
            Gradient.Stop(color: .yellow, location: lowStop),
            Gradient.Stop(color: .yellow, location: mediumStop),
            Gradient.Stop(color: .red, location: mediumStop),
            Gradient.Stop(color: .red, location: 1)
        ]
    }
}
