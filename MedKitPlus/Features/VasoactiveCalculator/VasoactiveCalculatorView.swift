import SwiftUI

struct VasoactiveCalculatorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedAgent: VasoactiveAgent = .norepinephrine
    @State private var selectedPresetID: String = VasoactiveAgent.norepinephrine.presets[0].id
    @State private var weightKg = 70
    @State private var dose: Double = 0.08
    @State private var showsManualMix = false
    @State private var manualDrugMg = "8"
    @State private var manualVolumeMl = "100"

    private var activePreset: InfusionPreset {
        if showsManualMix, let manualPreset {
            return manualPreset
        }

        return selectedAgent.presets.first { $0.id == selectedPresetID } ?? selectedAgent.presets[0]
    }

    private var agentColor: Color {
        VasoactiveAgentTheme.color(for: selectedAgent)
    }

    private var doseIntensity: DoseIntensity {
        VasoactiveDoseCalculator.intensity(for: selectedAgent, dose: dose)
    }

    private var doseIntensityColor: Color {
        VasoactiveAgentTheme.color(for: doseIntensity)
    }

    private var manualPreset: InfusionPreset? {
        VasoactiveDoseCalculator.manualPreset(drugMgText: manualDrugMg, volumeMlText: manualVolumeMl)
    }

    private var infusionRate: Double {
        VasoactiveDoseCalculator.infusionRate(
            dose: dose,
            weightKg: weightKg,
            concentrationMcgPerMl: activePreset.concentrationMcgPerMl
        )
    }

    private var maxInfusionRate: Double {
        VasoactiveDoseCalculator.infusionRate(
            dose: doseRange.upperBound,
            weightKg: weightKg,
            concentrationMcgPerMl: activePreset.concentrationMcgPerMl
        )
    }

    private var doseRange: ClosedRange<Double> {
        0...VasoactiveDoseCalculator.maxSliderDose(for: selectedAgent, preset: activePreset, weightKg: weightKg)
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        ZStack {
            AppColors.background(isDarkMode).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header
                    agentPicker
                    patientAndPresetPanel
                    dosePanel
                    clinicalNotePanel
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { dismissKeyboard() }
        )
        .onChange(of: selectedAgent) { _, newAgent in
            resetForSelectedAgent(newAgent)
        }
        .onChange(of: weightKg) { _, _ in
            clampDoseToCurrentRange()
        }
        .onChange(of: activePreset.id) { _, _ in
            clampDoseToCurrentRange()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedAgent.displayName)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(agentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Vazoaktif ajan")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.primaryText(isDarkMode))
            }

            Spacer()

            AppThemeControl()
        }
    }

    private var agentPicker: some View {
        VasoactiveAgentPicker(
            selectedAgent: $selectedAgent,
            isDarkMode: isDarkMode
        )
    }

    private var patientAndPresetPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(Array(stride(from: 30, through: 180, by: 5)), id: \.self) { kg in
                        Button("\(kg) kg") { weightKg = kg }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kilo")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 5) {
                            Text("\(weightKg) kg")
                                .font(.subheadline.weight(.heavy))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .frame(width: 72, height: 54, alignment: .leading)
                    .padding(.horizontal, 10)
                    .background(AppColors.controlBackground(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
                }
                .foregroundStyle(AppColors.primaryText(isDarkMode))

                Menu {
                    ForEach(selectedAgent.presets) { preset in
                        Button(preset.name) { selectedPresetID = preset.id }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(showsManualMix ? "Manuel karışım" : activePreset.name)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Spacer(minLength: 2)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .opacity(showsManualMix ? 0.25 : 1)
                    }
                    .foregroundStyle(showsManualMix ? .secondary : AppColors.primaryText(isDarkMode))
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    .background(AppColors.controlBackground(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
                }
                .disabled(showsManualMix)
                .opacity(showsManualMix ? 0.72 : 1)

                Button {
                    showsManualMix.toggle()
                } label: {
                    Image(systemName: showsManualMix ? "slider.horizontal.3" : "pencil.line")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 54, height: 54)
                }
                .buttonStyle(.plain)
                .foregroundStyle(showsManualMix ? .white : agentColor)
                .background(showsManualMix ? agentColor : AppColors.controlBackground(isDarkMode))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityLabel("Manuel ayarla")
            }

            if showsManualMix {
                manualMixEditor
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(AppColors.panel(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
    }

    private var manualMixEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Manuel karışım")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                numericField(title: "İlaç", value: $manualDrugMg, suffix: "mg")
                numericField(title: "Sıvı", value: $manualVolumeMl, suffix: "mL")
            }

            Text("Konsantrasyon: \(activePreset.concentrationMcgPerMl, specifier: "%.1f") mcg/mL")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(AppColors.controlBackground(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
    }

    private func numericField(title: String, value: Binding<String>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField("0", text: value)
                    .font(.body.weight(.bold))
                    .decimalKeyboard()
                Text(suffix)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(AppColors.fieldBackground(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var dosePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hız")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("\(infusionRate, specifier: "%.0f") cc/h")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(doseIntensityColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(doseIntensity.label)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(doseIntensityColor)
                    Text("\(dose, specifier: "%.3f") mcg/kg/dk")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            GradientDoseSlider(
                value: $dose,
                range: doseRange,
                intensity: doseIntensity,
                lowDoseUpperBound: selectedAgent.lowDoseUpperBound,
                mediumDoseUpperBound: selectedAgent.mediumDoseUpperBound,
                concentrationMcgPerMl: activePreset.concentrationMcgPerMl,
                weightKg: weightKg
            )
            .frame(height: 58)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Text("0 cc/h")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if maxInfusionRate > 30 {
                        Text("30 cc/h")
                            .offset(x: proxy.size.width * 0.72 - 24)
                    }
                    Text("\(maxInfusionRate, specifier: "%.0f") cc/h")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(height: 14)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(VasoactiveDoseCalculator.effectText(for: selectedAgent, dose: dose))
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppColors.primaryText(isDarkMode))

                Text(VasoactiveDoseCalculator.recommendation(for: selectedAgent, dose: dose, rate: infusionRate))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.controlBackground(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .background(AppColors.panel(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
    }

    private var clinicalNotePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: selectedAgent == .dopamine ? "exclamationmark.triangle.fill" : "info.circle.fill")
                    .foregroundStyle(selectedAgent == .dopamine ? .orange : agentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedAgent == .dopamine ? "Dopamin uyarısı" : "Klinik not")
                        .font(.caption.weight(.heavy))

                    Text(selectedAgent.clinicalNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.panel(isDarkMode), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            if selectedAgent == .dopamine {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.red.opacity(isDarkMode ? 0.72 : 0.55), lineWidth: 1.5)
            }
        }
    }

    private func resetForSelectedAgent(_ agent: VasoactiveAgent) {
        selectedPresetID = agent.presets[0].id
        dose = min(
            agent.startingDose,
            VasoactiveDoseCalculator.maxSliderDose(for: agent, preset: agent.presets[0], weightKg: weightKg)
        )
        showsManualMix = false
        manualDrugMg = VasoactiveCalculatorFormatting.cleanNumber(agent.presets[0].drugMg)
        manualVolumeMl = VasoactiveCalculatorFormatting.cleanNumber(agent.presets[0].volumeMl)
    }

    private func clampDoseToCurrentRange() {
        dose = min(dose, doseRange.upperBound)
    }
}

struct VasoactiveCalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            VasoactiveCalculatorView()
        }
    }
}
