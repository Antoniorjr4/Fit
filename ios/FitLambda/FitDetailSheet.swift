import SwiftUI

struct FitDetailSheet: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var step = 0
    @State private var draftGoal = 10_000.0
    @State private var draftName = ""
    @State private var draftFace = 0
    let kind: FitSheet
    private var p: Palette { Palette(scheme) }
    var body: some View {
        SheetFrame(title: demo.t("sheet.\(kind.rawValue).title"), identifier: "sheet.\(kind.rawValue).title") {
            content
        }.onAppear { draftGoal = demo.goal; draftName = demo.name; draftFace = demo.face }
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .goal:
            Text(demo.t("goal.subtitle")).foregroundStyle(p.muted)
            Text(demo.number(Int(draftGoal)))
                .font(textSize.isAccessibilitySize ? .largeTitle.weight(.medium) : .system(size: 57, weight: .medium))
                .monospacedDigit().frame(maxWidth: .infinity).padding(.top, 25)
                .accessibilityIdentifier("goal.value")
            Text(demo.t("goal.perDay")).font(.caption).foregroundStyle(p.muted).frame(maxWidth: .infinity)
            Slider(value: $draftGoal, in: 5000...15000, step: 1000) { Text(demo.t("goal.label")) }
                .accessibilityValue(demo.t("steps.count", demo.number(Int(draftGoal))))
            HStack {
                Button { draftGoal = max(5000, draftGoal - 1000) } label: {
                    Image(systemName: "minus").frame(width: 48, height: 48)
                }.accessibilityLabel(demo.t("goal.decrease"))
                    .accessibilityIdentifier("goal.decrease").disabled(draftGoal <= 5000)
                Spacer()
                Button { draftGoal = min(15000, draftGoal + 1000) } label: {
                    Image(systemName: "plus").frame(width: 48, height: 48)
                }.accessibilityLabel(demo.t("goal.increase"))
                    .accessibilityIdentifier("goal.increase").disabled(draftGoal >= 15000)
            }.buttonStyle(.bordered).tint(p.accent)
            HStack { Text(demo.number(5000)); Spacer(); Text(demo.number(15000)) }.font(.caption).foregroundStyle(p.muted)
            PrimaryAction(title: demo.t("goal.save"), symbol: "checkmark") { demo.goal = draftGoal; dismiss() }
                .accessibilityIdentifier("goal.save")
            Text(demo.t("goal.demoNote")).font(.caption).foregroundStyle(p.muted)
        case .heart:
            Kicker(text: demo.t("heart.kicker"))
            Text(demo.t("heart.bpm", demo.number(68))).font(.largeTitle.weight(.medium)).padding(.vertical, 20)
            Card {
                detail(demo.t("heart.resting"), demo.t("heart.bpm", demo.number(62)))
                Divider()
                detail(demo.t("heart.range"), demo.t("heart.bpm", "58 — 126"))
            }
            Text(demo.t("heart.demoNote")).font(.subheadline).foregroundStyle(p.muted)
        case .sleep:
            if demo.hasSleep {
                Kicker(text: demo.t("sleep.kicker"))
                Text(duration(7, 32)).font(.largeTitle.weight(.medium)).padding(.vertical, 20)
                Text(demo.t("sleep.interval", demo.date("jm", day: 14, hour: 23, minute: 8), demo.date("jm", hour: 7, minute: 0), demo.number(20)))
                    .font(.caption).foregroundStyle(p.muted)
                Card {
                    detail(demo.t("sleep.deep"), duration(1, 24)); Divider()
                    detail(demo.t("sleep.light"), duration(4, 18)); Divider()
                    detail(demo.t("sleep.rem"), duration(1, 50)); Divider()
                    detail(demo.t("sleep.awake"), demo.t("duration.minutes", demo.number(20)))
                }
                Text(demo.t("sleep.demoNote")).font(.caption).foregroundStyle(p.muted)
            } else {
                Text(demo.t("empty.sleep.title")).font(.title2)
                Text(demo.t("empty.sleep.body")).foregroundStyle(p.muted)
            }
        case .welcome:
            Text("Λ").font(.system(size: 90, weight: .light)).foregroundStyle(p.accent).frame(maxWidth: .infinity).padding(.vertical, 20)
            Text(demo.t("welcome.tagline")).font(.largeTitle.weight(.medium)).frame(maxWidth: .infinity).multilineTextAlignment(.center)
            Card {
                Label(demo.t("welcome.day"), systemImage: "figure.walk")
                Label(demo.t("welcome.band"), systemImage: "applewatch")
                Label(demo.t("welcome.simple"), systemImage: "leaf")
            }
            PrimaryAction(title: demo.t("welcome.explore"), symbol: "arrow.right") { dismiss() }
                .accessibilityIdentifier("welcome.done")
            DemoNote()
        case .pairing:
            Kicker(text: demo.t("pairing.step", demo.number(step + 1)))
                .accessibilityIdentifier("pairing.step")
            Image(systemName: ["antenna.radiowaves.left.and.right", "applewatch", "checkmark.circle"][step])
                .font(.system(size: 66, weight: .light)).foregroundStyle(p.accent).frame(maxWidth: .infinity).padding(.vertical, 30)
            Text(demo.t("pairing.title.\(step)")).font(.title2.weight(.semibold))
            Text(demo.t("pairing.body.\(step)")).foregroundStyle(p.muted)
            PrimaryAction(title: demo.t(step == 2 ? "pairing.finish" : "pairing.next"), symbol: "arrow.right") {
                if step < 2 { step += 1 } else { demo.finishConnectionPreview(); dismiss() }
            }.accessibilityIdentifier("pairing.next")
            DemoNote()
        case .faces:
            BandIllustration(face: draftFace).frame(maxWidth: .infinity)
            Picker(demo.t("faces.label"), selection: $draftFace) {
                Text(demo.t("face.rhythm")).tag(0); Text(demo.t("face.essential")).tag(1); Text(demo.t("face.night")).tag(2)
            }.pickerStyle(.segmented).accessibilityIdentifier("faces.picker")
            PrimaryAction(title: demo.t("faces.save"), symbol: "checkmark") { demo.face = draftFace; dismiss() }
                .accessibilityIdentifier("faces.save")
            Text(demo.t("faces.demoNote")).font(.caption).foregroundStyle(p.muted)
        case .health:
            Label(demo.t("health.planned"), systemImage: "heart").font(.title2).foregroundStyle(p.pink)
            Text(demo.t("health.description"))
            Text(demo.t("health.demoNote")).foregroundStyle(p.muted)
        case .privacy:
            Image(systemName: "hand.raised").font(.largeTitle).foregroundStyle(p.accent)
            Text(demo.t("privacy.data"))
            Text(demo.t("privacy.storage")).foregroundStyle(p.muted)
        case .sync:
            Image(systemName: "arrow.triangle.2.circlepath").font(.largeTitle).foregroundStyle(p.accent)
            Text(demo.t("state.\(demo.scenario.rawValue).title")).font(.title2)
            Text(demo.t("state.\(demo.scenario.rawValue).body")).foregroundStyle(p.muted)
            if demo.hasMetrics {
                Text(demo.t("state.lastSample", demo.date("dMMMyjm"))).font(.caption).foregroundStyle(p.muted)
            }
            PrimaryAction(title: demo.t("state.retry"), symbol: "arrow.triangle.2.circlepath") {
                demo.retryPreview(); dismiss()
            }.accessibilityIdentifier("sync.retry")
            DemoNote()
        case .name:
            TextField(demo.t("name.placeholder"), text: $draftName).textContentType(.givenName)
                .padding().background(p.surface, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityIdentifier("name.field")
                .submitLabel(.done).onSubmit { saveName() }
            PrimaryAction(title: demo.t("name.save"), symbol: "checkmark") { saveName() }
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("name.save")
        case .language, .scenarios, .permissions, .diagnostics, .live:
            EmptyView() // These routes use dedicated sheets in FitLambdaRoot.
        }
    }
    private func duration(_ hours: Int, _ minutes: Int) -> String {
        demo.t("duration.hm", demo.number(hours), demo.number(minutes))
    }
    private func detail(_ label: String, _ value: String) -> some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())
        return layout {
            Text(label).foregroundStyle(p.muted)
            if !textSize.isAccessibilitySize { Spacer() }
            Text(value)
        }.font(.subheadline).accessibilityElement(children: .combine)
    }
    private func saveName() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        demo.name = String(name.prefix(28))
        dismiss()
    }
}
