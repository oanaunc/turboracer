import SwiftUI

struct RaceView: View {
    let request: RaceRequest
    @ObservedObject var garage: Garage
    var openCalendar: () -> Void
    @StateObject private var engine: RaceEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var recorded = false
    @State private var tutorial = false
    @State private var tilt = TiltSteering()
    private var tiltOn: Bool { garage.save.tiltSteering ?? false }
    init(request:RaceRequest,garage:Garage,openCalendar:@escaping () -> Void = {}) {
        self.request=request; self.garage=garage; self.openCalendar=openCalendar
        _engine=StateObject(wrappedValue:RaceEngine(circuit:request.circuit,mode:request.mode,car:garage.car,upgrade:garage.save.upgrades[garage.car.id] ?? 0,sensitivity:garage.save.steeringSensitivity,haptics:garage.save.haptics,sounds:garage.save.sounds ?? true))
    }
    var body: some View {
        GeometryReader { geometry in ZStack {
            SceneSurface(engine:engine).frame(width:geometry.size.width,height:geometry.size.height).ignoresSafeArea()
            LinearGradient(colors:[ink.opacity(0.28),.clear,.clear,ink.opacity(0.45)],startPoint:.top,endPoint:.bottom).ignoresSafeArea().allowsHitTesting(false)
            if !ProcessInfo.processInfo.arguments.contains("--hide-hud") {
            VStack(spacing:8) {
                HStack(alignment:.top,spacing:18) {
                    if request.mode.hasRivals { PositionBadge(position:engine.position,field:engine.rivalCars.count+1-engine.eliminated) }
                    VStack(alignment:.leading,spacing:3) {Eyebrow(text:request.circuit.name);Text(request.mode.rawValue.uppercased()).font(RacingType.data(8)).foregroundStyle(muted)}
                    hud("LAP","\(engine.lap)/\(engine.totalLaps)")
                    if !request.mode.hasRivals { hud("DRIFT",engine.driftScore.formatted()) }
                    if request.mode == .elimination { hud("OUT IN",String(format:"%.0f",max(0,engine.eliminationClock))) }
                    if request.mode == .knockdown { hud("TAKEDOWNS","\(engine.takedowns)/\(RaceEngine.knockdownTarget)") }
                    hud("TIME",String(format:"%.1f",engine.elapsed))
                    Spacer()
                    TrackMap(circuit:request.circuit,progress:engine.routeProgress).frame(width:72,height:60).padding(4).background(.ultraThinMaterial.opacity(0.5),in:RoundedRectangle(cornerRadius:12)).environment(\.colorScheme,.dark).accessibilityLabel("Live circuit map")
                    Button {engine.setPaused(true)} label: {Image(systemName:"pause.fill").foregroundStyle(.white).frame(width:40,height:40).background(.ultraThinMaterial,in:Circle()).environment(\.colorScheme,.dark)}.accessibilityLabel("Pause race")
                }
                Spacer(minLength:0)
                if engine.offRoad {Text("OFF ROAD • RETURN TO THE CIRCUIT").font(RacingType.data(9)).padding(8).background(Color(hex:0xFF704D),in:Capsule())}
                if !engine.sparkMessage.isEmpty {Text(engine.sparkMessage).font(RacingType.data(9)).foregroundStyle(mint).padding(6).background(ink.opacity(0.7),in:Capsule())}
                if !engine.stunt.isEmpty {
                    Text(engine.stunt).font(RacingType.title(30)).foregroundStyle(engine.stunt.hasPrefix("TAKEDOWN") ? Color(hex:0xFF5F6D) : engine.stunt.hasPrefix("BARREL") ? Color(hex:0xFF5FD2) : mint)
                        .shadow(color:.black.opacity(0.6),radius:6).id(engine.stunt).transition(.scale(scale:1.6).combined(with:.opacity)).accessibilityIdentifier("stunt-callout")
                }
                if engine.shockwave {Text("SHOCKWAVE NITRO").font(RacingType.data(10)).foregroundStyle(Color(hex:0xE3A8FF))}
                if engine.combo>1 {Text("DRIFT CHAIN ×\(engine.combo)").font(RacingType.title(18)).foregroundStyle(mint)}
                HStack(alignment:.bottom,spacing:12) {
                    if !tiltOn {
                        GlassControl(symbol:"chevron.left",title:"LEFT",color:.white,size:84) {held in engine.steering=held ? -1:(engine.steering<0 ? 0:engine.steering)}
                        GlassControl(symbol:"chevron.right",title:"RIGHT",color:.white,size:84) {held in engine.steering=held ? 1:(engine.steering>0 ? 0:engine.steering)}
                    }
                    GlassControl(symbol:"pause.rectangle.fill",title:"BRAKE",color:Color(hex:0xFF7A66),size:52) {engine.braking=$0}
                    Spacer()
                    VStack(spacing:2) {Tachometer(speed:engine.speed,rpm:engine.rpm,gear:engine.gear,nitro:engine.nitro,boosting:engine.boosting);Text("\(engine.collected)/12 CHIPS").font(RacingType.data(8)).foregroundStyle(mint)}.padding(.bottom,4)
                    GlassControl(symbol:"wind",title:"DRIFT",color:Color(hex:0xFFB347),size:70,badge:engine.combo>1 ? "×\(engine.combo)" : nil) {engine.drifting=$0}
                    GlassControl(symbol:"bolt.fill",title:"NITRO",color:engine.nitro >= 0.5 ? Color(hex:0xC48BFF) : Color(hex:0x46E5FF),size:92,fill:engine.nitro) {engine.nitroHeld=$0}
                }
            }.padding(.horizontal,22).padding(.vertical,12)
            }
            if engine.countdown>0 && !tutorial && !ProcessInfo.processInfo.arguments.contains("--hide-hud") { Text(String(engine.countdown)).font(RacingType.title(110)).foregroundStyle(.white).shadow(color:mint.opacity(0.7),radius:25).allowsHitTesting(false) }
            if engine.paused && !tutorial && engine.result==nil { overlay {
                Eyebrow(text:"SESSION CONTROL"); Text("RACE PAUSED").font(RacingType.title(34)); ActionButton(title:"RESUME",icon:"play.fill") { engine.setPaused(false) }; Button("Leave race") { dismiss() }.foregroundStyle(muted).padding()
            } }
            if tutorial { overlay {
                Eyebrow(text:"PIT RADIO / MIKA"); Text("GRID BRIEFING").font(RacingType.title(34)); Text("Your car accelerates for you. Hold the arrows to steer across the road. Corners push you outward, so keep your line inside the white markings.").foregroundStyle(muted).font(.system(size:14)).lineSpacing(5)
                Text("Collect cyan memory chips to recover your father's notebook and recharge nitro. DRIFT + steering builds a combo. NITRO gives you a burst of speed; double-tap it with half a tank for a shockwave. Hit rivals under nitro to take them down, and launch off ramps for jumps and barrel rolls. BRAKE helps you settle into a tight turn.").foregroundStyle(muted).font(.system(size:14)).lineSpacing(5)
                ActionButton(title:"LET'S RACE",icon:"flag.checkered") { tutorial=false; engine.setPaused(false); engine.start() }
            } }
            if let result=engine.result {
                RaceResultView(result:result,mode:request.mode,field:engine.rivalCars.count+1,circuit:request.circuit,back:{dismiss()},next:{openCalendar();dismiss()})
            }
        }.frame(width:geometry.size.width,height:geometry.size.height) }.ignoresSafeArea().onAppear { if garage.save.races==0 { tutorial=true; engine.setPaused(true) } else { engine.start() } }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--preview-result") { DispatchQueue.main.asyncAfter(deadline:.now()+1) { engine.debugFinish() } }
            #endif
            Soundtrack.shared.switchTo(Soundtrack.track(for:request.circuit.environment),volume:0.24); if tiltOn { tilt.start { [weak engine] value in engine?.steering=value } } }
        .onDisappear { engine.stop(); tilt.stop(); Soundtrack.shared.switchTo("menu") }
        .onChange(of:engine.result != nil) { _,finished in if finished && !recorded,let result=engine.result { recorded=true; garage.record(result,circuit:request.circuit,mode:request.mode,daily:request.daily) } }
        .onChange(of:scenePhase) { _,phase in if phase != .active { engine.setPaused(true) } }
        .statusBarHidden()
    }
    func hud(_ label:String,_ value:String) -> some View { VStack(alignment:.leading,spacing:5) { Eyebrow(text:label,color:.white.opacity(0.55)); Text(value).font(RacingType.data(21)).monospacedDigit().foregroundStyle(.white) } }
    func overlay<Content:View>(@ViewBuilder content:() -> Content) -> some View { ZStack { ink.opacity(0.88).ignoresSafeArea(); ScrollView { VStack(alignment:.leading,spacing:19,content:content).padding(26).frame(maxWidth:450).background(Color(hex:0x1A2228),in:RacingPanel(cut:18)).padding(24).padding(.vertical,35) }.frame(maxHeight:650) } }
}
struct HoldControl: View {
    let symbol:String; let title:String; let color:Color; var compact=false
    let changed:(Bool)->Void
    @State private var held=false
    var body: some View {
        VStack(spacing:5) { Image(systemName:symbol).font(.system(size:compact ? 14 : 24,weight:.bold)); if !compact { Text(title).font(.system(size:8,weight:.black)).tracking(1) } }
            .frame(width:compact ? 65 : 65,height:compact ? 33 : 68)
            .foregroundStyle(held ? ink : color)
            .background(held ? color : ink.opacity(0.7),in:RacingPanel(cut:compact ? 6 : 12))
            .overlay(RacingPanel(cut:compact ? 6 : 12).stroke(color.opacity(0.4),lineWidth:1))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance:0).onChanged { _ in if !held { held=true; changed(true) } }.onEnded { _ in held=false; changed(false) })
            .onDisappear { held=false; changed(false) }
            .accessibilityElement(children: .ignore).accessibilityLabel(title).accessibilityIdentifier("control-"+title).accessibilityAddTraits(.isButton)
    }
}
