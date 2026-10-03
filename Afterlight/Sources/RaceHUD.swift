import SwiftUI

/// Race controls and instruments: glass round buttons with glowing rings,
/// a radial nitro charge, an arc tachometer with gear and speed, and a
/// position badge. Accessibility identifiers match the earlier controls.
struct GlassControl: View {
    let symbol: String; let title: String; let color: Color
    var size: CGFloat = 76
    /// Optional ring fill (0…1), e.g. the nitro tank.
    var fill: Double? = nil
    var badge: String? = nil
    let changed: (Bool) -> Void
    @State private var held = false
    var body: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
            Circle().fill(RadialGradient(colors: [color.opacity(held ? 0.55 : 0.18), .clear], center: .center, startRadius: 2, endRadius: size*0.6))
            Circle().stroke(.white.opacity(0.14), lineWidth: 1)
            Circle().inset(by: 4).stroke(color.opacity(0.22), lineWidth: 5)
            if let fill {
                Circle().inset(by: 4).trim(from: 0, to: max(0.001, fill)).stroke(AngularGradient(colors: [color.opacity(0.6), color, .white], center: .center), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90)).shadow(color: color.opacity(0.8), radius: 6)
            } else {
                Circle().inset(by: 4).stroke(color.opacity(held ? 1 : 0.55), lineWidth: 2)
            }
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: size*0.3, weight: .heavy)).foregroundStyle(held ? .white : color)
                    .shadow(color: color.opacity(0.9), radius: held ? 10 : 4)
                Text(title).font(.system(size: max(7, size*0.1), weight: .black)).tracking(1.2).foregroundStyle(.white.opacity(0.85))
            }
            if let badge {
                Text(badge).font(RacingType.title(12)).foregroundStyle(.black).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(color, in: Capsule()).offset(x: size*0.36, y: -size*0.38)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(held ? 0.93 : 1).animation(.spring(response: 0.18, dampingFraction: 0.6), value: held)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in if !held { held = true; changed(true) } }.onEnded { _ in held = false; changed(false) })
        .onDisappear { held = false; changed(false) }
        .accessibilityElement(children: .ignore).accessibilityLabel(title).accessibilityIdentifier("control-"+title).accessibilityAddTraits(.isButton)
    }
}

/// 240° tachometer: segmented rev arc that turns red near the limiter,
/// speed in the centre, gear above and the nitro tank as an inner arc.
struct Tachometer: View {
    let speed: Double; let rpm: Double; let gear: Int; let nitro: Double; let boosting: Bool
    // A 240° arc starting at the lower left (rotated 120°), gap at the bottom.
    private let start = 0.0, span = 0.667
    var body: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark).opacity(0.55)
            Circle().trim(from: start, to: start+span).stroke(.white.opacity(0.1), style: StrokeStyle(lineWidth: 9, lineCap: .butt, dash: [3, 2.2]))
                .rotationEffect(.degrees(120))
            let revs = max(0, min(1, (rpm-900)/6600))
            Circle().trim(from: start, to: start+span*revs)
                .stroke(AngularGradient(colors: [mint, Color(hex: 0x78D8DB), Color(hex: 0xFFD23F), Color(hex: 0xFF4D4D)], center: .center, startAngle: .degrees(0), endAngle: .degrees(240)), style: StrokeStyle(lineWidth: 9, lineCap: .butt, dash: [3, 2.2]))
                .rotationEffect(.degrees(120)).shadow(color: revs > 0.85 ? .red : mint.opacity(0.5), radius: 5)
            Circle().inset(by: 14).trim(from: start, to: start+span*nitro)
                .stroke(boosting ? Color(hex: 0xC48BFF) : Color(hex: 0x46E5FF), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(120)).shadow(color: Color(hex: 0x46E5FF), radius: boosting ? 8 : 3)
            VStack(spacing: -2) {
                Text(gear == 0 ? "N" : "\(gear)").font(RacingType.title(15)).foregroundStyle(revs > 0.9 ? Color(hex: 0xFF4D4D) : mint)
                Text(Int(speed*3.6).formatted()).font(RacingType.title(34)).monospacedDigit().foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 4)
                Text("KM/H").font(RacingType.data(7)).foregroundStyle(.white.opacity(0.6))
            }.offset(y: 4)
        }.frame(width: 120, height: 120).accessibilityElement(children: .ignore).accessibilityLabel("\(Int(speed*3.6)) kilometres per hour, gear \(gear)")
    }
}

/// Large race position with an ordinal suffix.
struct PositionBadge: View {
    let position: Int; let field: Int
    var suffix: String { position == 1 ? "ST" : position == 2 ? "ND" : position == 3 ? "RD" : "TH" }
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(position)").font(RacingType.title(44)).foregroundStyle(position == 1 ? Color(hex: 0xFFD23F) : .white)
            Text(suffix).font(RacingType.title(16)).foregroundStyle(.white.opacity(0.85))
            Text("/\(field)").font(RacingType.data(12)).foregroundStyle(.white.opacity(0.5)).padding(.leading, 4)
        }
        .padding(.horizontal, 12).padding(.vertical, 2)
        .background(LinearGradient(colors: [ink.opacity(0.75), ink.opacity(0.2)], startPoint: .leading, endPoint: .trailing), in: RacingPanel(cut: 10))
        .overlay(alignment: .leading) { Rectangle().fill(position == 1 ? Color(hex: 0xFFD23F) : mint).frame(width: 3) }
        .accessibilityElement(children: .ignore).accessibilityLabel("Position \(position) of \(field)")
    }
}

/// Podium-style results: big finishing place, stars that pop in one by one,
/// a counting credit total with its breakdown, and experience gained.
struct RaceResultView: View {
    let result: RaceResult; let mode: RaceMode; let field: Int; let circuit: Circuit
    let back: () -> Void; let next: () -> Void
    @State private var revealed = 0
    @State private var credits = 0
    @State private var appear = false
    private var place: String { ["1ST","2ND","3RD","4TH","5TH"][max(0,min(4,result.position-1))] }
    private var headline: String {
        switch mode {
        case .knockdown: return "\(result.takedowns) TAKEDOWNS"
        case .sprint: return String(format:"%.1f S", result.time)
        case .drift: return "\(result.drift) PTS"
        default: return place
        }
    }
    var body: some View {
        ZStack {
            LinearGradient(colors:[ink.opacity(0.55),ink.opacity(0.96)],startPoint:.top,endPoint:.bottom).ignoresSafeArea()
            HStack(alignment:.center,spacing:30) {
                VStack(alignment:.leading,spacing:10) {
                    Eyebrow(text:"\(circuit.name) / \(mode.rawValue.uppercased())",color:Color(hex:circuit.color))
                    Text(headline).font(RacingType.title(86)).foregroundStyle(result.position==1 || result.stars==3 ? Color(hex:0xFFD23F) : .white)
                        .shadow(color:Color(hex:0xFFD23F).opacity(result.stars==3 ? 0.5:0),radius:20)
                        .scaleEffect(appear ? 1:1.6).opacity(appear ? 1:0)
                    Text(result.stars==3 ? "PODIUM FINISH" : result.stars>0 ? "SESSION COMPLETE" : "TRY AGAIN").font(RacingType.title(22))
                    HStack(spacing:14) {
                        ForEach(0..<3) { i in
                            Image(systemName:i<result.stars ? "star.fill":"star").font(.system(size:34,weight:.bold))
                                .foregroundStyle(i<result.stars ? Color(hex:0xFFD23F):.white.opacity(0.25))
                                .scaleEffect(i<revealed ? 1:0.2).opacity(i<revealed ? 1:0.3)
                                .shadow(color:Color(hex:0xFFD23F).opacity(i<revealed && i<result.stars ? 0.8:0),radius:10)
                        }
                    }
                    if mode.hasRivals && mode != .knockdown {Text("Finished \(result.position) of \(field) • \(String(format:"%.1f",result.time)) s").font(.system(size:13)).foregroundStyle(muted)}
                }.frame(maxWidth:.infinity,alignment:.leading)
                VStack(alignment:.leading,spacing:9) {
                    Eyebrow(text:"RACE REWARD",color:racingBlue)
                    Text("+\(credits.formatted()) CR").font(RacingType.title(34)).foregroundStyle(mint).monospacedDigit()
                    row("Memory chips","\(result.collected)/12")
                    row("Stunts",result.stunts.formatted())
                    row("Takedowns",result.takedowns.formatted())
                    row("Experience","+\(Garage.experience(for:result)) XP")
                    HStack(spacing:12) {
                        ActionButton(title:"FESTIVAL",icon:"arrow.left",accent:racingBlue,action:back)
                        ActionButton(title:"NEXT EVENT",icon:"flag.checkered",action:next)
                    }.padding(.top,6)
                }.padding(20).frame(width:380).background(.ultraThinMaterial,in:RacingPanel(cut:16)).environment(\.colorScheme,.dark)
            }.padding(.horizontal,40)
        }
        .onAppear {
            withAnimation(.spring(response:0.5,dampingFraction:0.6)) {appear=true}
            for i in 0..<3 { DispatchQueue.main.asyncAfter(deadline:.now()+0.45+Double(i)*0.28) { withAnimation(.spring(response:0.35,dampingFraction:0.5)) {revealed=i+1} } }
            let steps=30
            for step in 1...steps { DispatchQueue.main.asyncAfter(deadline:.now()+0.3+Double(step)*0.035) { credits=result.credits*step/steps } }
        }
    }
    func row(_ title:String,_ value:String) -> some View {
        HStack {Text(title.uppercased()).font(RacingType.data(9)).foregroundStyle(muted);Spacer();Text(value).font(RacingType.data(11))}
            .padding(.vertical,4).overlay(alignment:.bottom) {Rectangle().fill(.white.opacity(0.08)).frame(height:1)}
    }
}
