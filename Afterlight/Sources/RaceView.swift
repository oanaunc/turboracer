import SwiftUI

struct RaceView: View {
    let request: RaceRequest
    @ObservedObject var garage: Garage
    @StateObject private var engine: RaceEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var recorded = false
    @State private var tutorial = false
    init(request:RaceRequest,garage:Garage) {
        self.request=request; self.garage=garage
        _engine=StateObject(wrappedValue:RaceEngine(circuit:request.circuit,mode:request.mode,car:garage.car,upgrade:garage.save.upgrades[garage.car.id] ?? 0,sensitivity:garage.save.steeringSensitivity,haptics:garage.save.haptics,sounds:garage.save.sounds ?? true))
    }
    var body: some View {
        ZStack {
            SceneSurface(engine:engine).ignoresSafeArea()
            LinearGradient(colors:[ink.opacity(0.85),.clear,.clear,ink.opacity(0.85)],startPoint:.top,endPoint:.bottom).ignoresSafeArea().allowsHitTesting(false)
            VStack {
                HStack(alignment:.top) { VStack(alignment:.leading,spacing:5) { Eyebrow(text:request.circuit.name); Text(request.mode.rawValue.uppercased()).font(.system(size:11,weight:.bold)).tracking(1).foregroundStyle(.white.opacity(0.7)) }; Spacer(); Button { engine.setPaused(true) } label: { Image(systemName:"pause.fill").font(.system(size:16,weight:.bold)).foregroundStyle(.white).frame(width:44,height:44).background(ink.opacity(0.7),in:Circle()) }.accessibilityLabel("Pause race") }
                HStack(alignment:.top) { hud("LAP","\(engine.lap)/\(engine.totalLaps)"); Spacer(); hud(request.mode == .circuit ? "POSITION" : "DRIFT",request.mode == .circuit ? "\(engine.position)/4" : engine.driftScore.formatted()); Spacer(); hud("TIME",String(format:"%.1f",engine.elapsed)) }.padding(.top,10)
                Spacer()
                if engine.offRoad { Text("OFF ROAD • RETURN TO THE CIRCUIT").font(.system(size:10,weight:.black)).tracking(1).padding(10).background(Color(hex:0xFF704D),in:Capsule()) }
                if !engine.sparkMessage.isEmpty { Text(engine.sparkMessage).font(.system(size:10,weight:.bold)).foregroundStyle(Color(hex:0xFFD76E)).padding(9).background(ink.opacity(0.8),in:Capsule()) }
                if engine.combo > 1 { Text("DRIFT CHAIN ×\(engine.combo)").font(.system(size:19,weight:.black,design:.rounded)).foregroundStyle(mint).shadow(color:.black,radius:6) }
                HStack(alignment:.bottom) { VStack(alignment:.leading,spacing:0) { Text(Int(engine.speed*3.6).formatted()).font(.system(size:54,weight:.black,design:.rounded)).monospacedDigit(); Eyebrow(text:"KM / H",color:.white.opacity(0.7)) }; Spacer(); VStack(alignment:.trailing,spacing:7) { Text("\(engine.collected)/12 SPARKS • \(engine.driftScore.formatted()) DRIFT").font(.system(size:12,weight:.bold,design:.monospaced)).foregroundStyle(mint); HStack { Image(systemName:"bolt.fill").foregroundStyle(mint); ProgressView(value:engine.nitro).tint(mint).frame(width:90) } } }.padding(.bottom,20)
                HStack(spacing:10) {
                    HoldControl(symbol:"chevron.left",title:"LEFT",color:.white) { held in engine.steering=held ? -1 : (engine.steering<0 ? 0 : engine.steering) }
                    HoldControl(symbol:"chevron.right",title:"RIGHT",color:.white) { held in engine.steering=held ? 1 : (engine.steering>0 ? 0 : engine.steering) }
                    Spacer(minLength:0)
                    HoldControl(symbol:"wind",title:"DRIFT",color:Color(hex:0xFFD76E)) { engine.drifting=$0 }
                    HoldControl(symbol:"bolt.fill",title:"NITRO",color:mint) { engine.nitroHeld=$0 }
                }
                HStack { HoldControl(symbol:"minus",title:"BRAKE",color:Color(hex:0xFF9A82),compact:true) { engine.braking=$0 }; Spacer(); Text("HOLD TO STEER • AUTO ACCELERATE").font(.system(size:8,weight:.bold,design:.monospaced)).foregroundStyle(.white.opacity(0.6)) }.padding(.top,6)
            }.padding(.horizontal,22).padding(.top,12).padding(.bottom,12)
            if engine.countdown>0 && !tutorial { Text(String(engine.countdown)).font(.system(size:110,weight:.black,design:.rounded)).foregroundStyle(.white).shadow(color:mint.opacity(0.7),radius:25).allowsHitTesting(false) }
            if engine.paused && !tutorial && engine.result==nil { overlay {
                Eyebrow(text:"TAKE A BREATH"); Text("THE ROAD\nCAN WAIT.").font(.system(size:32,weight:.black,design:.rounded)); ActionButton(title:"RESUME",icon:"play.fill") { engine.setPaused(false) }; Button("Leave race") { dismiss() }.foregroundStyle(muted).padding()
            } }
            if tutorial { overlay {
                Eyebrow(text:"MIKA'S QUICK BRIEFING"); Text("FIND YOUR\nRHYTHM.").font(.system(size:32,weight:.black,design:.rounded)); Text("Your car accelerates for you. Hold the arrows to steer across the road. Corners push you outward, so keep your line between the glowing rails.").foregroundStyle(muted).font(.system(size:14)).lineSpacing(5)
                Text("Collect gold memory sparks to recover your father's notebook and recharge nitro. DRIFT + steering builds a combo. NITRO gives you a burst of speed. BRAKE helps you settle into a tight turn.").foregroundStyle(muted).font(.system(size:14)).lineSpacing(5)
                ActionButton(title:"LET'S RACE",icon:"flag.checkered") { tutorial=false; engine.setPaused(false); engine.start() }
            } }
            if let result=engine.result { overlay {
                Eyebrow(text:result.stars==3 ? "A NIGHT TO REMEMBER" : "EVERY RUN IS PROGRESS")
                Text(result.stars==3 ? "YOU OWN\nTHE NIGHT." : "KEEP THE\nFIRE ALIVE.").font(.system(size:34,weight:.black,design:.rounded))
                HStack(spacing:12) { ForEach(0..<3) { i in Image(systemName:i<result.stars ? "star.fill" : "star").font(.system(size:30)).foregroundStyle(i<result.stars ? Color(hex:0xFFD76E) : muted.opacity(0.4)) } }.padding(.vertical,8)
                Text("\(result.collected) memory sparks recovered").font(.system(size:12,weight:.bold)).foregroundStyle(Color(hex:0xFFD76E))
                Text(request.mode == .circuit ? "Finished \(result.position) of 4 • \(String(format:"%.1f",result.time)) seconds" : "\(String(format:"%.1f",result.time)) seconds • \(result.drift) drift points").font(.system(size:14)).foregroundStyle(muted)
                HStack { Text("RACE REWARD").font(.system(size:11,weight:.bold)).tracking(1); Spacer(); Text("+\(result.credits) CREDITS").font(.system(size:16,weight:.black,design:.rounded)).foregroundStyle(mint) }.padding(16).background(ink,in:RoundedRectangle(cornerRadius:14))
                Text(result.stars==3 ? "Mika: “That's a line worth remembering. Bring that energy to the next race.”" : "Mika: “Use nitro on the straights, drift through the bends, and spend your credits on engine tuning. You've got this.”").font(.system(size:12)).foregroundStyle(muted).lineSpacing(4)
                ActionButton(title:"BACK TO THE FESTIVAL",icon:"arrow.right") { dismiss() }
            } }
        }.onAppear { if garage.save.races==0 { tutorial=true; engine.setPaused(true) } else { engine.start() } }
        .onDisappear { engine.stop() }
        .onChange(of:engine.result != nil) { _,finished in if finished && !recorded,let result=engine.result { recorded=true; garage.record(result,circuit:request.circuit,mode:request.mode,daily:request.daily) } }
        .onChange(of:scenePhase) { _,phase in if phase != .active { engine.setPaused(true) } }
        .statusBarHidden()
    }
    func hud(_ label:String,_ value:String) -> some View { VStack(alignment:.leading,spacing:5) { Eyebrow(text:label,color:.white.opacity(0.55)); Text(value).font(.system(size:23,weight:.black,design:.rounded)).monospacedDigit().foregroundStyle(.white) } }
    func overlay<Content:View>(@ViewBuilder content:() -> Content) -> some View { ZStack { ink.opacity(0.88).ignoresSafeArea(); ScrollView { VStack(alignment:.leading,spacing:19,content:content).padding(26).frame(maxWidth:450).background(Color(hex:0x182239),in:RoundedRectangle(cornerRadius:26)).padding(24).padding(.vertical,35) }.frame(maxHeight:650) } }
}
struct HoldControl: View {
    let symbol:String; let title:String; let color:Color; var compact=false
    let changed:(Bool)->Void
    @State private var held=false
    var body: some View {
        VStack(spacing:5) { Image(systemName:symbol).font(.system(size:compact ? 14 : 24,weight:.bold)); if !compact { Text(title).font(.system(size:8,weight:.black)).tracking(1) } }
            .frame(width:compact ? 65 : 65,height:compact ? 33 : 68)
            .foregroundStyle(held ? ink : color)
            .background(held ? color : ink.opacity(0.7),in:RoundedRectangle(cornerRadius:compact ? 12 : 20))
            .overlay(RoundedRectangle(cornerRadius:compact ? 12 : 20).stroke(color.opacity(0.4),lineWidth:1))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance:0).onChanged { _ in if !held { held=true; changed(true) } }.onEnded { _ in held=false; changed(false) })
            .onDisappear { held=false; changed(false) }
            .accessibilityElement(children: .ignore).accessibilityLabel(title).accessibilityIdentifier("control-"+title).accessibilityAddTraits(.isButton)
    }
}
