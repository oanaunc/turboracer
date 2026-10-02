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
    init(request:RaceRequest,garage:Garage,openCalendar:@escaping () -> Void = {}) {
        self.request=request; self.garage=garage; self.openCalendar=openCalendar
        _engine=StateObject(wrappedValue:RaceEngine(circuit:request.circuit,mode:request.mode,car:garage.car,upgrade:garage.save.upgrades[garage.car.id] ?? 0,sensitivity:garage.save.steeringSensitivity,haptics:garage.save.haptics,sounds:garage.save.sounds ?? true))
    }
    var body: some View {
        GeometryReader { geometry in ZStack {
            SceneSurface(engine:engine).frame(width:geometry.size.width,height:geometry.size.height).ignoresSafeArea()
            LinearGradient(colors:[ink.opacity(0.28),.clear,.clear,ink.opacity(0.45)],startPoint:.top,endPoint:.bottom).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing:8) {
                HStack(alignment:.top,spacing:24) {
                    VStack(alignment:.leading,spacing:3) {Eyebrow(text:request.circuit.name);Text(request.mode.rawValue.uppercased()).font(RacingType.data(8)).foregroundStyle(muted)}
                    hud("LAP","\(engine.lap)/\(engine.totalLaps)")
                    hud(request.mode == .circuit ? "POSITION":"DRIFT",request.mode == .circuit ? "\(engine.position)/4":engine.driftScore.formatted())
                    hud("TIME",String(format:"%.1f",engine.elapsed))
                    Spacer()
                    TrackMap(circuit:request.circuit,progress:engine.routeProgress).frame(width:72,height:60).accessibilityLabel("Live circuit map")
                    Button {engine.setPaused(true)} label: {Image(systemName:"pause.fill").foregroundStyle(.white).frame(width:40,height:40).background(ink.opacity(0.7),in:RacingPanel(cut:7))}.accessibilityLabel("Pause race")
                }
                Spacer(minLength:0)
                if engine.offRoad {Text("OFF ROAD • RETURN TO THE CIRCUIT").font(RacingType.data(9)).padding(8).background(Color(hex:0xFF704D),in:Capsule())}
                if !engine.sparkMessage.isEmpty {Text(engine.sparkMessage).font(RacingType.data(9)).foregroundStyle(mint).padding(6).background(ink.opacity(0.7),in:Capsule())}
                if engine.combo>1 {Text("DRIFT CHAIN ×\(engine.combo)").font(RacingType.title(18)).foregroundStyle(mint)}
                HStack(alignment:.bottom,spacing:12) {
                    HoldControl(symbol:"chevron.left",title:"LEFT",color:.white) {held in engine.steering=held ? -1:(engine.steering<0 ? 0:engine.steering)}
                    HoldControl(symbol:"chevron.right",title:"RIGHT",color:.white) {held in engine.steering=held ? 1:(engine.steering>0 ? 0:engine.steering)}
                    HoldControl(symbol:"minus",title:"BRAKE",color:Color(hex:0xFF9A82),compact:true) {engine.braking=$0}
                    Spacer()
                    VStack(spacing:2) {HStack(alignment:.firstTextBaseline,spacing:5) {Text(Int(engine.speed*3.6).formatted()).font(RacingType.title(42)).monospacedDigit();Text("KM/H").font(RacingType.data(8)).foregroundStyle(muted)};TelemetryBar(value:engine.nitro,color:Color(hex:0x78D8DB)).frame(width:115,height:4);Text("\(engine.collected)/12 CHIPS").font(RacingType.data(8)).foregroundStyle(mint)}
                    Spacer()
                    HoldControl(symbol:"wind",title:"DRIFT",color:Color(hex:0xFFD76E)) {engine.drifting=$0}
                    HoldControl(symbol:"bolt.fill",title:"NITRO",color:Color(hex:0x78D8DB)) {engine.nitroHeld=$0}
                }
            }.padding(.horizontal,22).padding(.vertical,12)
            if engine.countdown>0 && !tutorial { Text(String(engine.countdown)).font(RacingType.title(110)).foregroundStyle(.white).shadow(color:mint.opacity(0.7),radius:25).allowsHitTesting(false) }
            if engine.paused && !tutorial && engine.result==nil { overlay {
                Eyebrow(text:"SESSION CONTROL"); Text("RACE PAUSED").font(RacingType.title(34)); ActionButton(title:"RESUME",icon:"play.fill") { engine.setPaused(false) }; Button("Leave race") { dismiss() }.foregroundStyle(muted).padding()
            } }
            if tutorial { overlay {
                Eyebrow(text:"PIT RADIO / MIKA"); Text("GRID BRIEFING").font(RacingType.title(34)); Text("Your car accelerates for you. Hold the arrows to steer across the road. Corners push you outward, so keep your line inside the white markings.").foregroundStyle(muted).font(.system(size:14)).lineSpacing(5)
                Text("Collect cyan memory chips to recover your father's notebook and recharge nitro. DRIFT + steering builds a combo. NITRO gives you a burst of speed. BRAKE helps you settle into a tight turn.").foregroundStyle(muted).font(.system(size:14)).lineSpacing(5)
                ActionButton(title:"LET'S RACE",icon:"flag.checkered") { tutorial=false; engine.setPaused(false); engine.start() }
            } }
            if let result=engine.result {
                ZStack {
                    ink.opacity(0.92).ignoresSafeArea()
                    VStack(alignment:.leading,spacing:16) {
                        HStack(alignment:.top,spacing:28) {
                            VStack(alignment:.leading,spacing:12) {
                                Eyebrow(text:"OFFICIAL SESSION RESULT")
                                Text(result.stars==3 ? "PODIUM FINISH" : "SESSION COMPLETE").font(RacingType.title(30))
                                HStack(spacing:12) { ForEach(0..<3) { i in Image(systemName:i<result.stars ? "star.fill" : "star").font(.system(size:26)).foregroundStyle(i<result.stars ? mint : muted.opacity(0.4)) } }
                                Text(request.mode == .circuit ? "Finished \(result.position) of 4 • \(String(format:"%.1f",result.time)) seconds" : "\(String(format:"%.1f",result.time)) seconds • \(result.drift) drift points").font(.system(size:13)).foregroundStyle(muted)
                            }.frame(maxWidth:.infinity,alignment:.leading)
                            VStack(alignment:.leading,spacing:12) {
                                Eyebrow(text:"RACE REWARD",color:racingBlue)
                                Text("+\(result.credits) CREDITS").font(RacingType.title(27)).foregroundStyle(mint)
                                Text("\(result.collected) memory chips recovered").font(.system(size:12,weight:.bold)).foregroundStyle(muted)
                                Text("Choose another event in the calendar. Earn five stars across this region to open the next destination.").font(.system(size:12)).foregroundStyle(muted).fixedSize(horizontal:false,vertical:true)
                            }.frame(maxWidth:.infinity,alignment:.leading)
                        }
                        HStack(spacing:14) {
                            ActionButton(title:"BACK TO THE FESTIVAL",icon:"arrow.left",accent:racingBlue) { dismiss() }
                            ActionButton(title:"CHOOSE NEXT EVENT",icon:"flag.checkered") { openCalendar(); dismiss() }
                        }
                    }.padding(24).frame(maxWidth:850).background(Color(hex:0x1A2228),in:RacingPanel(cut:18)).padding(.horizontal,32)
                }
            }
        }.frame(width:geometry.size.width,height:geometry.size.height) }.ignoresSafeArea().onAppear { if garage.save.races==0 { tutorial=true; engine.setPaused(true) } else { engine.start() } }
        .onDisappear { engine.stop() }
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
