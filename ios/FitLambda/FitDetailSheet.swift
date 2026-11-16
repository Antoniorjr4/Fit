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
    private var title: String {
        switch kind {
        case .goal: "Um passo além."
        case .heart: "Seu coração."
        case .sleep: "Uma pausa que conta."
        case .welcome: "Bem-vindo ao FitΛ."
        case .pairing: "Conectar sua Fit."
        case .faces: "Um toque seu."
        case .health: "Tudo em sintonia."
        case .privacy: "Seu espaço, respeitado."
        case .sync: "Seu dia, atualizado."
        case .name: "Como prefere ser chamado?"
        }
    }
    var body: some View {
        NavigationStack {
            Page {
                Text(title).font(.largeTitle.weight(.semibold)).tracking(-1)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("sheet.\(kind.rawValue).title")
                content
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
                    }.accessibilityLabel("Fechar")
                        .accessibilityIdentifier("sheet.close")
                }
            }
        }
        .tint(p.accent)
        .onAppear { draftGoal = demo.goal; draftName = demo.name; draftFace = demo.face }
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .goal:
            Text("Escolha uma meta que combine com o seu dia.").foregroundStyle(p.muted)
            Text(DemoStore.number(Int(draftGoal)))
                .font(textSize.isAccessibilitySize ? .largeTitle.weight(.medium) : .system(size: 57, weight: .medium))
                .monospacedDigit().frame(maxWidth: .infinity).padding(.top, 25)
                .accessibilityIdentifier("goal.value")
            Text("passos por dia").font(.caption).foregroundStyle(p.muted).frame(maxWidth: .infinity)
            Slider(value: $draftGoal, in: 5000...15000, step: 1000) { Text("Meta de passos") }
                .accessibilityValue("\(Int(draftGoal)) passos")
            HStack {
                Button { draftGoal = max(5000, draftGoal - 1000) } label: {
                    Image(systemName: "minus").frame(width: 48, height: 48)
                }.accessibilityLabel("Diminuir meta em mil passos")
                    .accessibilityIdentifier("goal.decrease").disabled(draftGoal <= 5000)
                Spacer()
                Button { draftGoal = min(15000, draftGoal + 1000) } label: {
                    Image(systemName: "plus").frame(width: 48, height: 48)
                }.accessibilityLabel("Aumentar meta em mil passos")
                    .accessibilityIdentifier("goal.increase").disabled(draftGoal >= 15000)
            }.buttonStyle(.bordered).tint(p.accent)
            HStack { Text("5.000"); Spacer(); Text("15.000") }.font(.caption).foregroundStyle(p.muted)
            PrimaryAction(title: "Salvar minha meta", symbol: "checkmark") { demo.goal = draftGoal; dismiss() }
                .accessibilityIdentifier("goal.save")
            Text("Ajuste visual. Não altera a meta na pulseira.").font(.caption).foregroundStyle(p.muted)
        case .heart:
            Kicker(text: "FREQUÊNCIA CARDÍACA · EXEMPLO")
            Text("68 bpm").font(.largeTitle.weight(.medium)).padding(.vertical, 20)
            Card { detail("Em repouso", "62 bpm"); Divider(); detail("Faixa do dia", "58 — 126 bpm") }
            Text("Valores fictícios. Esta prévia não mede sinais e não faz avaliações de saúde.").font(.subheadline).foregroundStyle(p.muted)
        case .sleep:
            Kicker(text: "SEU SONO · EXEMPLO")
            Text("7h 32min").font(.largeTitle.weight(.medium)).padding(.vertical, 20)
            Text("23:08 — 07:00 · 20 min acordado").font(.caption).foregroundStyle(p.muted)
            Card {
                detail("Profundo", "1h 24min"); Divider()
                detail("Leve", "4h 18min"); Divider()
                detail("REM", "1h 50min"); Divider()
                detail("Acordado", "20min")
            }
            Text("Dados ilustrativos. A disponibilidade das fases do sono depende da integração real com a Fit3.").font(.caption).foregroundStyle(p.muted)
        case .welcome:
            Text("Λ").font(.system(size: 90, weight: .light)).foregroundStyle(p.accent).frame(maxWidth: .infinity).padding(.vertical, 20)
            Text("Sua Fit.\nNovas possibilidades.").font(.largeTitle.weight(.medium)).frame(maxWidth: .infinity).multilineTextAlignment(.center)
            Card {
                Label("Seu dia, com clareza", systemImage: "figure.walk")
                Label("Um espaço para sua Fit3", systemImage: "applewatch")
                Label("Simples, desde o primeiro toque", systemImage: "leaf")
            }
            PrimaryAction(title: "Explorar o FitΛ", symbol: "arrow.right") { dismiss() }
                .accessibilityIdentifier("welcome.done")
            DemoNote()
        case .pairing:
            Kicker(text: "DEMONSTRAÇÃO DO FLUXO · ETAPA \(step + 1) DE 3")
                .accessibilityIdentifier("pairing.step")
            Image(systemName: ["antenna.radiowaves.left.and.right", "applewatch", "checkmark.circle"][step])
                .font(.system(size: 66, weight: .light)).foregroundStyle(p.accent).frame(maxWidth: .infinity).padding(.vertical, 30)
            Text(["Vamos aproximar.", "Tudo no seu lugar.", "Um novo começo."][step]).font(.title2.weight(.semibold))
            Text(["Na experiência final, você aproximará a Fit3 do iPhone e permitirá o uso do Bluetooth.", "A próxima etapa mostrará a pulseira encontrada e pedirá a confirmação. Galaxy Fit3: dispositivo de exemplo.", "Esta é a aparência da confirmação. Nenhum dispositivo foi conectado."][step]).foregroundStyle(p.muted)
            PrimaryAction(title: step == 2 ? "Concluir demonstração" : "Continuar simulação", symbol: "arrow.right") {
                if step < 2 { step += 1 } else { demo.connectionPreview = true; dismiss() }
            }.accessibilityIdentifier("pairing.next")
            DemoNote()
        case .faces:
            BandIllustration(face: draftFace).frame(maxWidth: .infinity)
            Picker("Conceito de mostrador", selection: $draftFace) {
                Text("Ritmo").tag(0); Text("Essencial").tag(1); Text("Noturno").tag(2)
            }.pickerStyle(.segmented)
                .accessibilityIdentifier("faces.picker")
            PrimaryAction(title: "Usar nesta prévia", symbol: "checkmark") { demo.face = draftFace; dismiss() }
                .accessibilityIdentifier("faces.save")
            Text("Muda apenas a ilustração. O envio de mostradores para a Fit3 ainda não foi validado.").font(.caption).foregroundStyle(p.muted)
        case .health:
            Label("Apple Saúde · planejado", systemImage: "heart").font(.title2).foregroundStyle(p.pink)
            Text("A proposta é reunir seus registros no Apple Saúde, com sua permissão e controle sobre cada categoria.")
            Text("A integração depende da leitura real da Fit3 e da implementação do HealthKit. Esta prévia não lê nem grava dados no Apple Saúde.").foregroundStyle(p.muted)
        case .privacy:
            Image(systemName: "hand.raised").font(.largeTitle).foregroundStyle(p.accent)
            Text("Esta demonstração usa dados fictícios. Não acessa Bluetooth, sensores, localização ou informações de saúde.")
            Text("As preferências desta base nativa ficam apenas em memória e são restauradas ao reiniciar o app. Não há serviço de análise ou backend integrado.").foregroundStyle(p.muted)
        case .sync:
            Image(systemName: "arrow.triangle.2.circlepath").font(.largeTitle).foregroundStyle(p.accent)
            Text("A experiência planejada reunirá os dados disponíveis da sua Fit3 e mostrará a última sincronização.")
            Text("A disponibilidade de cada dado será confirmada nos testes Bluetooth. Esta prévia não realiza sincronização.").foregroundStyle(p.muted)
        case .name:
            TextField("Seu nome", text: $draftName).textContentType(.givenName)
                .padding().background(p.surface, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityIdentifier("name.field")
                .submitLabel(.done).onSubmit { saveName() }
            PrimaryAction(title: "Salvar nome", symbol: "checkmark") { saveName() }
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("name.save")
        }
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
