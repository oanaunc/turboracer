import SwiftUI
import AVFoundation

let ink = Color(hex:0x0C1222)
let mint = Color(hex:0x65E8D5)
let muted = Color(hex:0x9FAAC3)

@main struct AfterlightApp: App {
    @StateObject private var garage = Garage()
    var body: some Scene { WindowGroup { HomeView().environmentObject(garage).preferredColorScheme(.dark) } }
}
final class Soundtrack {
    static let shared = Soundtrack()
    private var player: AVAudioPlayer?
    func play(enabled: Bool) {
        guard enabled else { player?.pause(); return }
        if player == nil, let url=Bundle.main.url(forResource:"afterlight",withExtension:"wav") {
            try? AVAudioSession.sharedInstance().setCategory(.ambient,mode:.default)
            player = try? AVAudioPlayer(contentsOf:url); player?.numberOfLoops = -1; player?.volume = 0.3
        }; player?.play()
    }
}
struct ActionButton: View {
    let title: String; var icon = "arrow.right"; var accent = mint; let action: () -> Void
    var body: some View { Button(action:action) { HStack { Text(title).font(.system(size:15,weight:.black,design:.rounded)).tracking(1.2); Spacer(); Image(systemName:icon).font(.system(size:17,weight:.bold)) }.padding(19).foregroundStyle(ink).background(accent,in:RoundedRectangle(cornerRadius:18)) }.buttonStyle(.plain) }
}
struct Eyebrow: View {
    let text: String; var color = mint
    var body: some View { Text(text).font(.system(size:10,weight:.bold,design:.monospaced)).tracking(2).foregroundStyle(color) }
}
struct HomeView: View {
    @EnvironmentObject var garage: Garage
    @State private var tab = 0
    @State private var settings = false
    @State private var activeRace: RaceRequest?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack { ink.ignoresSafeArea()
            VStack(spacing:0) {
                HStack { HStack(spacing:7) { Image(systemName:"bolt.fill").foregroundStyle(mint); Text("AFTERLIGHT").font(.system(size:14,weight:.black,design:.rounded)).tracking(3) }; Spacer(); Image(systemName:"hexagon.fill").foregroundStyle(Color(hex:0xFFD76E)); Text(garage.save.credits.formatted()).font(.system(size:13,weight:.bold,design:.monospaced)); Button { settings=true } label: { Image(systemName:"gearshape").foregroundStyle(muted).padding(8) }.accessibilityLabel("Settings") }.padding(.horizontal,24).padding(.top,12).padding(.bottom,14)
                ScrollView {
                    VStack(alignment:.leading,spacing:24) {
                        if tab==0 { home }
                        else if tab==1 { campaign }
                        else if tab==2 { GarageView() }
                        else { journal }
                    }.frame(maxWidth:650).padding(.horizontal,24).padding(.bottom,24).frame(maxWidth:.infinity)
                }
                HStack { nav("house.fill","HOME",0); nav("map.fill","WORLD",1); nav("car.side.fill","GARAGE",2); nav("book.closed.fill","STORY",3) }.padding(.top,15).padding(.bottom,8).background(Color(hex:0x111A2D))
            }
        }.sheet(isPresented:$settings) { SettingsView() }
        .fullScreenCover(item:$activeRace) { request in RaceView(request:request,garage:garage) }
        .onAppear { Soundtrack.shared.play(enabled:garage.save.music) }
        .onChange(of:garage.save.music) { _,value in Soundtrack.shared.play(enabled:value) }
        .onChange(of:scenePhase) { _,value in Soundtrack.shared.play(enabled:value == .active && garage.save.music) }
    }
    func nav(_ symbol: String,_ title: String,_ index: Int) -> some View {
        Button { tab=index } label: { VStack(spacing:7) { Image(systemName:symbol).font(.system(size:18)); Text(title).font(.system(size:9,weight:.bold)).tracking(1) }.foregroundStyle(tab==index ? mint : muted).frame(maxWidth:.infinity) }.accessibilityLabel(title)
    }
    var home: some View {
        VStack(alignment:.leading,spacing:22) {
            ZStack(alignment:.bottomLeading) {
                Image("Cover").resizable().scaledToFill().frame(height:410).clipped()
                LinearGradient(colors:[.clear,ink.opacity(0.15),ink],startPoint:.top,endPoint:.bottom)
                VStack(alignment:.leading,spacing:9) { Eyebrow(text:"TURBORACER / A NEW HORIZON"); Text("CHASE THE\nAFTERLIGHT.").font(.system(size:38,weight:.black,design:.rounded)).tracking(-1.5).lineSpacing(-2); Text("Four worlds. One road to becoming a legend.").font(.system(size:13)).foregroundStyle(Color(hex:0xD2DCEB)) }.padding(22)
            }.clipShape(RoundedRectangle(cornerRadius:25))
            ActionButton(title:garage.save.races == 0 ? "BEGIN YOUR STORY" : "BACK TO THE STREETS") { tab=1 }
            HStack(alignment:.top,spacing:15) {
                Image(systemName:"waveform.path").font(.title2).foregroundStyle(mint)
                VStack(alignment:.leading,spacing:6) { Eyebrow(text:"RADIO / MIKA"); Text(garage.save.races==0 ? "“Your father's garage still has one last car. The festival starts tonight. Let's give this city something to remember.”" : "“Every corner teaches you something. Keep racing, build your garage, and open the road to Cloudline.”").font(.system(size:13)).foregroundStyle(muted).lineSpacing(4) }
            }.padding(18).background(Color(hex:0x172036),in:RoundedRectangle(cornerRadius:18))
            HStack { Eyebrow(text:"TODAY'S DETOUR"); Spacer(); Text("NEW EVERY DAY").font(.system(size:9,weight:.bold)).foregroundStyle(muted) }
            Button { activeRace=RaceRequest(circuit:Garage.dailyCircuit,mode:.drift,daily:true) } label: {
                HStack { VStack(alignment:.leading,spacing:7) { Text("AFTER HOURS").font(.system(size:21,weight:.black,design:.rounded)); Text("\(Garage.dailyCircuit.name) • Drift challenge").font(.system(size:12)).foregroundStyle(muted); Text("First starred run today: +350 bonus credits.").font(.system(size:11)).foregroundStyle(muted) }; Spacer(); Image(systemName:"moon.stars.fill").font(.system(size:32)).foregroundStyle(Color(hex:0xBBA8FF)) }.padding(20).background(Color(hex:0x1C203A),in:RoundedRectangle(cornerRadius:18)).foregroundStyle(.white)
            }.buttonStyle(.plain)
            HStack { stat("RACES",garage.save.races.formatted()); stat("WINS",garage.save.wins.formatted()); stat("KM",String(format:"%.1f",garage.save.distance)) }
        }
    }
    func stat(_ title: String,_ value: String) -> some View { VStack(alignment:.leading,spacing:7) { Text(value).font(.system(size:23,weight:.bold,design:.rounded)); Eyebrow(text:title,color:muted) }.frame(maxWidth:.infinity,alignment:.leading).padding(16).background(Color(hex:0x151E31),in:RoundedRectangle(cornerRadius:15)) }
    var campaign: some View {
        VStack(alignment:.leading,spacing:20) {
            Eyebrow(text:"THE AFTERLIGHT FESTIVAL"); Text("A WORLD\nWORTH CHASING.").font(.system(size:32,weight:.black,design:.rounded)); Text("Earn 5 stars in each region to open the next. Every event rewards credits, even while you learn.").font(.system(size:13)).foregroundStyle(muted).lineSpacing(4)
            ForEach(Circuit.all) { circuit in
                let locked = circuit.id > garage.save.unlockedRegion
                VStack(alignment:.leading,spacing:14) {
                    HStack { Eyebrow(text:circuit.region,color:Color(hex:circuit.color)); Spacer(); if locked { Image(systemName:"lock.fill").foregroundStyle(muted) } else { Text("\((0..<3).reduce(0) { $0 + (garage.save.medals[circuit.id*3+$1] ?? 0) }) / 9 ★").font(.system(size:11,weight:.bold)).foregroundStyle(Color(hex:circuit.color)) } }
                    Text(circuit.name).font(.system(size:27,weight:.black,design:.rounded)); Text(circuit.tagline).font(.system(size:12)).foregroundStyle(muted)
                    TrackMap(circuit:circuit).frame(height:105)
                    ForEach(Array(RaceMode.allCases.enumerated()),id:\.offset) { index,mode in
                        Button { activeRace=RaceRequest(circuit:circuit,mode:mode,daily:false) } label: { HStack {
                            Image(systemName:mode == .circuit ? "flag.checkered" : mode == .sprint ? "stopwatch" : "wind").frame(width:25).foregroundStyle(Color(hex:circuit.color))
                            VStack(alignment:.leading,spacing:3) { Text(mode.rawValue).font(.system(size:14,weight:.bold)); Text(mode.detail).font(.system(size:10)).foregroundStyle(muted) }; Spacer()
                            Text(String(repeating:"★",count:garage.save.medals[circuit.id*3+index] ?? 0)).font(.system(size:12)).foregroundStyle(Color(hex:0xFFD76E)); Image(systemName:locked ? "lock" : "arrow.up.right").font(.system(size:12))
                        }.padding(13).background(ink.opacity(0.5),in:RoundedRectangle(cornerRadius:12)) }.buttonStyle(.plain).disabled(locked)
                    }
                }.padding(20).background(LinearGradient(colors:[Color(hex:circuit.color).opacity(0.13),Color(hex:0x151E31)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:22)).opacity(locked ? 0.65 : 1)
            }
        }
    }
    var journal: some View {
        VStack(alignment:.leading,spacing:22) {
            Eyebrow(text:"THE PEOPLE BEHIND THE ROAD"); Text("EVERY LEGEND\nSTARTS SOMEWHERE.").font(.system(size:31,weight:.black,design:.rounded))
            Text("You inherited a shuttered garage and your father's Solstice. Mika, your oldest friend and mechanic, has a plan: enter the Afterlight Festival, win back the garage's reputation, and reach the summit race your father never finished.").font(.system(size:15)).foregroundStyle(muted).lineSpacing(6)
            ForEach(Circuit.all) { c in
                VStack(alignment:.leading,spacing:12) { HStack { Text(String(c.rival.prefix(1))).font(.system(size:28,weight:.black)).frame(width:58,height:58).background(Color(hex:c.color).opacity(0.15),in:Circle()).foregroundStyle(Color(hex:c.color)); VStack(alignment:.leading,spacing:5) { Eyebrow(text:c.region,color:Color(hex:c.color)); Text(c.rival.uppercased()).font(.system(size:20,weight:.black,design:.rounded)) } }
                    HStack { Image(systemName:"sparkle").foregroundStyle(Color(hex:0xFFD76E)); Text("FATHER'S NOTEBOOK • \(min(12,garage.save.memorySparks?[c.id] ?? 0))/12 SPARKS").font(.system(size:9,weight:.bold,design:.monospaced)).foregroundStyle(muted) }
                    if (garage.save.memorySparks?[c.id] ?? 0) >= 12 { Text(notebook(c.id)).font(.system(size:13,weight:.medium,design:.serif)).italic().foregroundStyle(Color(hex:0xF0D8AA)).lineSpacing(5).padding(14).background(ink,in:RoundedRectangle(cornerRadius:12)) }
                    Text(story(c.id)).font(.system(size:13)).foregroundStyle(muted).lineSpacing(5)
                    if c.id <= garage.save.unlockedRegion { Text(c.id==0 ? "“Speed is easy. A clean line takes heart.”" : c.id==1 ? "“The lights don't make the city. The people do.”" : c.id==2 ? "“Out here, patience is faster than pride.”" : "“Your father left a road. You get to choose where it leads.”").font(.system(size:14,weight:.semibold)).foregroundStyle(Color(hex:c.color)) }
                }.padding(20).background(Color(hex:0x151E31),in:RoundedRectangle(cornerRadius:20))
            }
            Eyebrow(text:"YOUR MILESTONES")
            milestone("First light","Finish your first event",garage.save.races>0)
            milestone("A place on the podium","Win a circuit race",garage.save.wins>0)
            milestone("Collector","Own three original cars",garage.save.owned.count>=3)
            milestone("Road to the summit","Unlock Cloudline",garage.save.unlockedRegion==3)
            milestone("Festival legend","Earn all 36 campaign stars",garage.save.medals.values.reduce(0,+)>=36)
        }
    }
    func milestone(_ title:String,_ description:String,_ achieved:Bool) -> some View { HStack { Image(systemName:achieved ? "checkmark.seal.fill" : "seal").foregroundStyle(achieved ? mint : muted); VStack(alignment:.leading,spacing:4) { Text(title).font(.system(size:14,weight:.bold)); Text(description).font(.system(size:11)).foregroundStyle(muted) }; Spacer() }.padding(15).background(Color(hex:0x151E31),in:RoundedRectangle(cornerRadius:12)) }
    func notebook(_ id:Int) -> String { ["“The coast taught me that a road is never just asphalt. It's every person waiting at the other end. Take care of the car. Take better care of the people.”", "“Nova was right: we drive to keep a place alive. Neon Harbor doesn't belong to the fastest driver. It belongs to everyone who calls it home.”", "“I lost a race in Ember Canyon and found something better: patience. Lift before the bend. Look further than the next corner. That works off the road, too.”", "“Iris, if I never make it back to Cloudline, tell my kid this: the finish line was never the point. I wanted to see what waited beyond the mountain. Now it's their turn.”"][id] }
    func story(_ id:Int) -> String { ["Luca runs the coastal delivery route. He knew your father, and offers your first invitation to the festival. Learn the rhythm of the coast and prove you belong.","Nova is the harbor's night-racing champion. Her crew protects the old waterfront from becoming another silent luxury district. Win her respect, and the city's roads open to you.","Rafa builds engines in a desert workshop. He values control over bravado. The canyon's tightening bends test whether you have learned to listen to your car.","Iris was your father's final rival. At Cloudline, the festival becomes more than a race: a chance to finish an old story and begin your own."][id] }
}
struct TrackMap: View {
    let circuit: Circuit
    var body: some View { GeometryReader { geometry in
        let points=(0...180).map { circuit.point(Double($0)/180) }
        let bound = CGFloat(circuit.radius*(1+circuit.distortion))*2.2
        Path { p in for (i,v) in points.enumerated() { let point=CGPoint(x:geometry.size.width/2+CGFloat(v.x)/bound*geometry.size.height,y:geometry.size.height/2+CGFloat(v.z)/bound*geometry.size.height); if i==0 { p.move(to:point) } else { p.addLine(to:point) } } }.stroke(Color(hex:circuit.color),style:StrokeStyle(lineWidth:3,lineCap:.round)).shadow(color:Color(hex:circuit.color).opacity(0.5),radius:8)
    } }
}
struct GarageView: View {
    @EnvironmentObject var garage: Garage
    @State private var inspected = 0
    var car: Car { Car.all[inspected] }
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            Eyebrow(text:"BUILT FOR YOUR NEXT CHAPTER"); Text("YOUR DREAM\nGARAGE.").font(.system(size:34,weight:.black,design:.rounded))
            CarShowroom(car:car).frame(height:220).background(RadialGradient(colors:[Color(hex:car.color).opacity(0.18),ink],center:.center,startRadius:5,endRadius:170),in:RoundedRectangle(cornerRadius:22))
            HStack { Text(car.name).font(.system(size:30,weight:.black,design:.rounded)); Spacer(); Text("0\(car.id+1) / 06").font(.system(size:11,weight:.bold,design:.monospaced)).foregroundStyle(muted) }
            Text(car.subtitle).font(.system(size:13)).foregroundStyle(muted)
            HStack { ForEach(Car.all) { c in Button { inspected=c.id } label: { Circle().fill(Color(hex:c.color)).frame(width:32,height:32).padding(5).overlay(Circle().stroke(inspected==c.id ? .white : .clear,lineWidth:2)) }.accessibilityLabel(c.name) } }
            VStack(spacing:13) { rating("TOP SPEED",car.speed/80); rating("HANDLING",car.handling/1.4); rating("TUNING",Double(garage.save.upgrades[car.id] ?? 0)/4) }.padding(18).background(Color(hex:0x151E31),in:RoundedRectangle(cornerRadius:18))
            if garage.save.owned.contains(car.id) {
                ActionButton(title:garage.save.selectedCar==car.id ? "READY TO RACE" : "SELECT THIS CAR",icon:"checkmark",accent:Color(hex:car.color)) { garage.save.selectedCar=car.id }
                let level=garage.save.upgrades[car.id] ?? 0
                if garage.save.selectedCar==car.id && level<4 { Button { garage.upgrade() } label: { HStack { Image(systemName:"wrench.adjustable.fill"); Text("TUNE ENGINE • \((level+1)*600) CREDITS"); Spacer(); Text("\(level)/4") }.font(.system(size:12,weight:.bold)).foregroundStyle(garage.save.credits >= (level+1)*600 ? mint : muted).padding(18).background(Color(hex:0x172036),in:RoundedRectangle(cornerRadius:16)) }.disabled(garage.save.credits < (level+1)*600) }
            } else {
                ActionButton(title:"UNLOCK • \(car.price.formatted()) CREDITS",icon:"key.fill",accent:garage.save.credits>=car.price ? Color(hex:car.color) : muted) { garage.buy(car) }.disabled(garage.save.credits<car.price)
                Text("Earn credits by racing. Every car and upgrade is unlocked through play.").font(.system(size:12)).foregroundStyle(muted)
            }
        }.onAppear { inspected=garage.save.selectedCar }
    }
    func rating(_ title:String,_ amount:Double) -> some View { HStack { Text(title).font(.system(size:10,weight:.bold,design:.monospaced)).tracking(1).foregroundStyle(muted).frame(width:85,alignment:.leading); GeometryReader { g in ZStack(alignment:.leading) { Capsule().fill(ink); Capsule().fill(Color(hex:car.color)).frame(width:g.size.width*min(1,amount)) } }.frame(height:5) } }
}
struct SettingsView: View {
    @EnvironmentObject var garage: Garage
    @Environment(\.dismiss) var dismiss
    @State private var reset = false
    var body: some View { NavigationStack { Form {
        Section("The driving experience") { Toggle("Original synth soundtrack",isOn:$garage.save.music); Toggle("Engine and collectible sounds",isOn:Binding(get:{ garage.save.sounds ?? true },set:{ garage.save.sounds=$0 })); Toggle("Haptic feedback",isOn:$garage.save.haptics); VStack(alignment:.leading) { Text("Steering sensitivity"); Slider(value:$garage.save.steeringSensitivity,in:0.65...1.5) } }
        Section("How to drive") { Text("Your car accelerates automatically. Hold the left and right arrows to move across the track. Hold BRAKE to slow down; hold DRIFT while steering to build a combo. NITRO gives a burst of speed and recharges as you drive. Stay between the illuminated barriers.").font(.subheadline) }
        Section("Your data") { Text("Your garage, race records, and settings stay on this device. No account, advertising, analytics, or tracking."); Link("Privacy policy",destination:URL(string:"https://oanarinaldi.com/turboracerprivacy.html")!); Button("Reset all progress",role:.destructive) { reset=true } }
        Section { Text("TurboRacer: Afterlight • 2.0\nOriginal cars, circuits, story, and soundtrack.\nCreated by Oana Rinaldi.").font(.footnote).foregroundStyle(.secondary) }
    }.navigationTitle("Settings").toolbar { Button("Done") { dismiss() } }.confirmationDialog("Erase your garage and all race records?",isPresented:$reset,titleVisibility:.visible) { Button("Erase all progress",role:.destructive) { garage.reset() } } } }
}
struct RaceRequest: Identifiable { let id=UUID(); let circuit:Circuit; let mode:RaceMode; let daily:Bool }
