import SwiftUI
import Charts

enum FitTab: Hashable { case today, trends, band, profile }
enum FitSheet: String, Identifiable {
    case goal, heart, sleep, welcome, pairing, faces, health, privacy, sync, name
    var id: String { rawValue }
}

struct FitLambdaRoot: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.colorScheme) private var scheme
    @State private var tab: FitTab = .today
    @State private var sheet: FitSheet?
    private var p: Palette { Palette(scheme) }

    var body: some View {
        TabView(selection: $tab) {
            TodayScreen(tab: $tab, sheet: $sheet)
                .tabItem { Label("Hoje", systemImage: "house.fill") }.tag(FitTab.today)
            TrendsScreen()
                .tabItem { Label("Evolução", systemImage: "chart.bar.fill") }.tag(FitTab.trends)
            BandScreen(sheet: $sheet)
                .tabItem { Label("Pulseira", systemImage: "applewatch") }.tag(FitTab.band)
            ProfileScreen(sheet: $sheet)
                .tabItem { Label("Perfil", systemImage: "person.fill") }.tag(FitTab.profile)
        }
        .tint(p.accent)
        .sheet(item: $sheet) { item in
            FitDetailSheet(kind: item)
                .environmentObject(demo)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct Page<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 28)
                .frame(maxWidth: 580)
                .frame(maxWidth: .infinity)
        }.background(Palette(scheme).background.ignoresSafeArea())
    }
}

struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette(scheme).surface, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(Palette(scheme).line, lineWidth: 1))
    }
}

struct Kicker: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var body: some View {
        Text(text).font(.caption2.weight(.medium)).tracking(1.6)
            .foregroundStyle(Palette(scheme).muted)
    }
}

struct DemoNote: View {
    var body: some View {
        Text("Prévia visual · dados fictícios.\nBluetooth e Apple Saúde ainda não integrados.")
            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding(.top, 8)
    }
}

struct PrimaryAction: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 17)
        }
        .foregroundStyle(Palette(scheme).ink)
        .background(Palette(scheme).accent, in: RoundedRectangle(cornerRadius: 18))
        .buttonStyle(.plain)
    }
}

struct TodayScreen: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.colorScheme) private var scheme
    @Binding var tab: FitTab
    @Binding var sheet: FitSheet?
    private var p: Palette { Palette(scheme) }
    var body: some View {
        Page {
            Kicker(text: "DOMINGO, 15 NOV")
            HStack {
                Text("Boa noite,\n\(demo.name).")
                    .font(.largeTitle.weight(.semibold)).tracking(-1.2)
                Spacer()
                Button { tab = .profile } label: {
                    Text(String(demo.name.prefix(1)).uppercased()).font(.subheadline)
                        .frame(width: 48, height: 48).background(p.surface, in: Circle())
                }.accessibilityLabel("Abrir perfil")
            }
            HStack {
                Button { tab = .band } label: { Label("Galaxy Fit3 · Demo", systemImage: "applewatch") }
                Spacer()
                Label("78%", systemImage: "battery.75percent").foregroundStyle(p.accent)
            }.font(.caption).foregroundStyle(p.muted)
            Card {
                HStack {
                    Kicker(text: "SEU MOVIMENTO")
                    Spacer()
                    Button { sheet = .goal } label: {
                        Image(systemName: "target").frame(width: 44, height: 44)
                    }.accessibilityLabel("Editar meta de passos")
                }
                ActivityArc(steps: demo.steps, goal: demo.goal).frame(height: 245)
                Text(demo.goal > Double(demo.steps)
                     ? "Faltam \(DemoStore.number(Int(demo.goal) - demo.steps)) passos. Você está perto."
                     : "Meta alcançada. Cada passo conta.")
                    .font(.caption).foregroundStyle(p.muted).frame(maxWidth: .infinity)
                Divider()
                HStack {
                    Stat(value: "5,8", unit: "km", label: "Distância")
                    Divider()
                    Stat(value: "382", unit: "kcal", label: "Energia ativa")
                    Divider()
                    Stat(value: "42", unit: "min", label: "Em movimento")
                }.fixedSize(horizontal: false, vertical: true)
            }
            Text("Seu corpo, em foco.").font(.headline)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { vitalCards }
                VStack(spacing: 12) { vitalCards }
            }
            Button { tab = .trends } label: {
                Card {
                    Label("Um passo de cada vez.", systemImage: "sparkles").font(.subheadline.weight(.medium))
                    Text("Você alcançou 10.000 passos em 4 dos últimos 7 dias. Veja a sua evolução.")
                        .font(.caption).foregroundStyle(p.muted)
                }
            }.buttonStyle(.plain)
            DemoNote()
        }
    }
    @ViewBuilder private var vitalCards: some View {
        VitalTile(title: "Coração", value: "68", unit: "bpm", detail: "Última leitura · 20:12", symbol: "heart", color: p.pink) { sheet = .heart }
        VitalTile(title: "Sono", value: "7h32", unit: "min", detail: "Tempo total dormindo", symbol: "moon", color: p.purple) { sheet = .sleep }
    }
}

struct ActivityArc: View {
    @Environment(\.colorScheme) private var scheme
    let steps: Int
    let goal: Double
    private var p: Palette { Palette(scheme) }
    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: 0.75).stroke(p.line, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: CGFloat(min(Double(steps) / goal, 1)) * 0.75)
                .stroke(p.accent, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(135))
            VStack(spacing: 9) {
                Image(systemName: "figure.walk").font(.title3).foregroundStyle(p.accent)
                Text(DemoStore.number(steps)).font(.system(size: 48, weight: .semibold, design: .rounded)).minimumScaleFactor(0.7)
                Text("de \(DemoStore.number(Int(goal))) passos").font(.caption).foregroundStyle(p.muted)
            }.padding(.bottom, 20)
            VStack { Spacer(); Text("\(Int(Double(steps) / goal * 100))% da meta").font(.caption.weight(.semibold)).foregroundStyle(p.accent).padding(.bottom, 8) }
        }.frame(maxWidth: 245).frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(steps) passos de uma meta de \(Int(goal)) passos")
    }
}

struct Stat: View {
    let value: String
    let unit: String
    let label: String
    var body: some View {
        VStack(spacing: 7) {
            (Text(value).font(.title3.weight(.semibold)) + Text(" \(unit)").font(.caption2))
                .lineLimit(1).minimumScaleFactor(0.75)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct VitalTile: View {
    let title: String
    let value: String
    let unit: String
    let detail: String
    let symbol: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                Label(title, systemImage: symbol).font(.caption).foregroundStyle(color)
                (Text(value).font(.title.weight(.medium)) + Text(" \(unit)").font(.caption))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
                HStack(alignment: .center, spacing: 4) {
                    ForEach(0..<15) { i in Capsule().fill(color.opacity(i % 3 == 0 ? 0.4 : 0.8)).frame(height: CGFloat(8 + (i * 7) % 21)) }
                }.frame(height: 29).accessibilityHidden(true)
            }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 23))
        }.buttonStyle(.plain)
    }
}

struct TrendsScreen: View {
    @Environment(\.colorScheme) private var scheme
    @State private var period = 0
    private var data: [StepDay] { period == 0 ? DemoStore.week : DemoStore.month }
    private var p: Palette { Palette(scheme) }
    var body: some View {
        Page {
            Kicker(text: "CADA DIA CONTA")
            Text("Seu ritmo.").font(.largeTitle.weight(.semibold)).tracking(-1.2)
            Text("O progresso mora na constância.").font(.subheadline).foregroundStyle(p.muted)
            Picker("Período", selection: $period) {
                Text("Semana").tag(0); Text("Mês").tag(1)
            }.pickerStyle(.segmented)
            Text(period == 0 ? "9 — 15 de novembro · exemplo" : "1 — 15 de novembro · exemplo")
                .font(.caption).foregroundStyle(p.muted).frame(maxWidth: .infinity)
            Card {
                Text(DemoStore.number(data.map(\.steps).reduce(0, +) / data.count))
                    .font(.system(size: 43, weight: .semibold)).tracking(-1.5)
                Text("Média diária de passos").font(.caption).foregroundStyle(p.muted)
                Chart(data) { day in
                    BarMark(x: .value("Período", day.day), y: .value("Passos", day.steps))
                        .foregroundStyle(p.accent.opacity(day.day == data.last?.day ? 1 : 0.4))
                        .cornerRadius(5)
                        .accessibilityLabel("\(day.day), \(day.steps) passos")
                }.chartYScale(domain: 0...12000).frame(height: 210)
            }
            Text("Um olhar mais de perto.").font(.headline)
            Card {
                Label("4 de 7 dias com 10.000 passos", systemImage: "target")
                Divider()
                Label("Quinta: 11.500 passos", systemImage: "figure.walk")
            }.font(.subheadline)
            DemoNote()
        }
    }
}

struct BandIllustration: View {
    let face: Int
    private var tone: Color { face == 1 ? Color(hex: 0xEFF1DF) : face == 2 ? Color(hex: 0x251B2E) : Color(hex: 0x0A100A) }
    private var ink: Color { face == 1 ? Color(hex: 0x2A3122) : face == 2 ? Color(hex: 0xD3BAFF) : Color(hex: 0xD4F68A) }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [Color(hex: 0x1A211C), Color(hex: 0x39433A), Color(hex: 0x171E19)], startPoint: .leading, endPoint: .trailing)).frame(width: 79, height: 268)
            RoundedRectangle(cornerRadius: 26).fill(LinearGradient(colors: [.gray, Color(hex: 0xCAD3C7), .gray], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 108, height: 151)
            RoundedRectangle(cornerRadius: 22).fill(tone).frame(width: 99, height: 143)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(.black, lineWidth: 6))
            VStack(spacing: 3) {
                Text("DOM, 15 NOV").font(.system(size: 7, weight: .medium)).tracking(1)
                Text("09\n41").font(.system(size: 44, weight: face == 1 ? .light : .bold, design: .rounded)).lineSpacing(-11)
                Text("8.432 PASSOS").font(.system(size: 6)).tracking(1)
            }.foregroundStyle(ink)
        }.frame(height: 280).rotationEffect(.degrees(-12))
            .shadow(color: .black.opacity(0.15), radius: 10, x: 12, y: 14)
            .accessibilityLabel("Ilustração conceitual da Galaxy Fit3")
    }
}

struct BandScreen: View {
    @EnvironmentObject private var demo: DemoStore
    @Binding var sheet: FitSheet?
    var body: some View {
        Page {
            Kicker(text: "SEMPRE COM VOCÊ")
            Text("Sua Fit.").font(.largeTitle.weight(.semibold)).tracking(-1.2)
            Text("Pequena no pulso. Parte do seu dia.").font(.subheadline).foregroundStyle(.secondary)
            BandIllustration(face: demo.face).frame(maxWidth: .infinity)
            VStack(spacing: 8) {
                Text("Galaxy Fit3").font(.title2.weight(.semibold))
                Text(demo.connectionPreview ? "Conexão simulada · modo demonstração" : "Pronta para fazer parte do seu ritmo.").font(.caption).foregroundStyle(.secondary)
                Label("78% de bateria · exemplo", systemImage: "battery.75percent").font(.caption)
            }.frame(maxWidth: .infinity)
            PrimaryAction(title: "Simular conexão", symbol: "link") { sheet = .pairing }
            Card {
                Button { sheet = .faces } label: { RowLabel(title: "Seu estilo, no pulso", symbol: "paintpalette") }
                Divider()
                Button { sheet = .sync } label: { RowLabel(title: "Sincronização planejada", symbol: "arrow.triangle.2.circlepath") }
            }.buttonStyle(.plain)
            DemoNote()
        }
    }
}

struct RowLabel: View {
    let title: String
    let symbol: String
    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: symbol); Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }.font(.subheadline).frame(minHeight: 38)
    }
}

struct ProfileScreen: View {
    @EnvironmentObject private var demo: DemoStore
    @Binding var sheet: FitSheet?
    var body: some View {
        Page {
            Kicker(text: "UM ESPAÇO SEU")
            Text("Do seu jeito.").font(.largeTitle.weight(.semibold)).tracking(-1.2)
            Button { sheet = .name } label: {
                HStack(spacing: 15) {
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 54))
                    VStack(alignment: .leading, spacing: 7) {
                        Text(demo.name).font(.title2.weight(.semibold))
                        Text("Seu ritmo. Suas escolhas.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(); Image(systemName: "pencil")
                }
            }.buttonStyle(.plain)
            Kicker(text: "SEU DIA A DIA")
            Card {
                Button { sheet = .goal } label: { RowLabel(title: "Meta: \(DemoStore.number(Int(demo.goal))) passos", symbol: "target") }
                Divider()
                Toggle("Aparência escura", isOn: $demo.isDark)
                Divider()
                Toggle("Prévia de lembretes", isOn: $demo.reminders)
                Text("Demonstração visual. Nenhum lembrete é enviado.").font(.caption).foregroundStyle(.secondary)
            }.buttonStyle(.plain).font(.subheadline)
            Kicker(text: "SEUS DADOS")
            Card {
                Button { sheet = .health } label: { RowLabel(title: "Apple Saúde · planejado", symbol: "heart") }
                Divider()
                Button { sheet = .privacy } label: { RowLabel(title: "Privacidade", symbol: "hand.raised") }
                Divider()
                Button { sheet = .welcome } label: { RowLabel(title: "Rever boas-vindas", symbol: "sparkles") }
            }.buttonStyle(.plain)
            Text("FitΛ\nDesign preview 0.2.0").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            DemoNote()
        }
    }
}
