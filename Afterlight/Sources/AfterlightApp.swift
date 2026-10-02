import SwiftUI
import AVFoundation

let ink = Color(hex:0x101519)
let mint = Color(hex:0xFFD52A)
let muted = Color(hex:0xAABFCE)
let racingBlue = Color(hex:0x47CFFF)

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
    var body: some View { Button(action:action) { HStack { Text(title).font(RacingType.title(17)).tracking(0.6); Spacer(); Image(systemName:icon).font(.system(size:17,weight:.bold)) }.padding(18).foregroundStyle(ink).background(accent,in:RacingPanel()) }.buttonStyle(.plain) }
}
struct Eyebrow: View {
    let text: String; var color = mint
    var body: some View { Text(text).font(.system(size:10,weight:.bold,design:.monospaced)).tracking(2).foregroundStyle(color) }
}
struct HomeView: View {
    @EnvironmentObject var garage: Garage
    @State private var tab = 0
    @State private var calendarRegion = 0
    @State private var inspectedCar = 0
    @State private var settings = false
    @State private var activeRace: RaceRequest?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            if tab==2 {
                CarShowroom(car:Car.all[inspectedCar]).ignoresSafeArea()
                LinearGradient(colors:[ink.opacity(0.85),.clear,.clear],startPoint:.leading,endPoint:.trailing).ignoresSafeArea().allowsHitTesting(false)
                LinearGradient(colors:[ink.opacity(0.65),.clear,ink.opacity(0.25)],startPoint:.top,endPoint:.bottom).ignoresSafeArea().allowsHitTesting(false)
            } else {PaddockBackground()}
            VStack(spacing:0) {
                HStack(spacing:10) {
                    Image(systemName:"flag.checkered").foregroundStyle(mint).font(.system(size:20))
                    VStack(alignment:.leading,spacing:1) { Text("AFTERLIGHT").font(RacingType.title(21)).tracking(1); Text("TURBORACER / MOTORSPORT FESTIVAL").font(RacingType.data(7)).tracking(1).foregroundStyle(muted) }
                    Spacer()
                    VStack(alignment:.trailing,spacing:2) {Text(garage.save.credits.formatted()).font(RacingType.data(15));Text("RACE CREDITS").font(RacingType.data(7)).foregroundStyle(mint)}
                    Button { settings=true } label: { Image(systemName:"gearshape").foregroundStyle(muted).padding(10).background(.white.opacity(0.04),in:RacingPanel(cut:6)) }.accessibilityLabel("Settings")
                }.padding(.horizontal,20).padding(.top,10).padding(.bottom,15)
                HStack(spacing:16) {
                    VStack(spacing:24) {nav("house.fill","HOME",0);nav("map.fill","WORLD",1);nav("car.side.fill","GARAGE",2);nav("book.closed.fill","STORY",3)}.frame(width:68).padding(.vertical,12)
                    if tab==0 {landscapeHome}
                    else if tab==2 {GarageView(inspected:$inspectedCar)}
                    else {ScrollView {VStack(alignment:.leading,spacing:20) {if tab==1 {campaign}else{journal}}.padding(.trailing,20).padding(.bottom,20)}}
                }.padding(.bottom,8)
            }
        }.sheet(isPresented:$settings) { SettingsView() }
        .fullScreenCover(item:$activeRace) { request in RaceView(request:request,garage:garage,openCalendar:{tab=1}) }
        .onAppear { Soundtrack.shared.play(enabled:garage.save.music)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--preview-garage") {tab=2;inspectedCar=garage.save.selectedCar}
            if ProcessInfo.processInfo.arguments.contains("--preview-calendar") {tab=1}
            if let index=ProcessInfo.processInfo.arguments.firstIndex(of:"--preview-car"),ProcessInfo.processInfo.arguments.count>index+1,let car=Int(ProcessInfo.processInfo.arguments[index+1]),Car.all.indices.contains(car) {garage.save.selectedCar=car}
            if let index=ProcessInfo.processInfo.arguments.firstIndex(of:"--preview-region"),ProcessInfo.processInfo.arguments.count>index+1,let region=Int(ProcessInfo.processInfo.arguments[index+1]),Circuit.all.indices.contains(region) {garage.save.races=1;activeRace=RaceRequest(circuit:Circuit.all[region],mode:ProcessInfo.processInfo.arguments.contains("--preview-grid") ? .circuit:.sprint,daily:false)}
            #endif
        }
        .onChange(of:garage.save.music) { _,value in Soundtrack.shared.play(enabled:value) }
        .onChange(of:scenePhase) { _,value in Soundtrack.shared.play(enabled:value == .active && garage.save.music) }
    }
    func nav(_ symbol: String,_ title: String,_ index: Int) -> some View {
        Button { tab=index } label: { VStack(spacing:6) { Rectangle().fill(tab==index ? mint : .clear).frame(width:28,height:2); Image(systemName:symbol).font(.system(size:17)); Text(["PADDOCK","CALENDAR","GARAGE","CREW"][index]).font(RacingType.data(8)).tracking(0.4) }.foregroundStyle(tab==index ? mint : muted).frame(maxWidth:.infinity) }.accessibilityLabel(title)
    }
    var landscapeHome: some View {
        let next=Circuit.all[garage.save.unlockedRegion]
        return HStack(spacing:16) {
            ZStack(alignment:.bottomLeading) {
                CarShowroom(car:garage.car)
                LinearGradient(colors:[.clear,ink.opacity(0.9)],startPoint:.center,endPoint:.bottom).allowsHitTesting(false)
                VStack(alignment:.leading,spacing:5) {Eyebrow(text:"SEASON 01 / YOUR CURRENT DRIVE");Text(garage.car.name).font(RacingType.title(36));Text("\(Int(garage.car.speed*3.6)) KM/H  /  STAGE \(garage.save.upgrades[garage.car.id] ?? 0)").font(RacingType.data(9)).foregroundStyle(muted)}.padding(20)
            }.clipShape(RacingPanel(cut:18)).frame(maxWidth:.infinity,maxHeight:.infinity)
            VStack(alignment:.leading,spacing:10) {
                Eyebrow(text:"NEXT SESSION / \(next.region)")
                HStack {Text(next.name).font(RacingType.title(25));Spacer();TrackMap(circuit:next).frame(width:55,height:50)}
                Text("CIRCUIT / 2 LAPS / 4 DRIVERS").font(RacingType.data(8)).foregroundStyle(muted)
                ActionButton(title:garage.save.races==0 ? "START YOUR FIRST RACE":"ENTER THE GRID",icon:"flag.checkered") {activeRace=RaceRequest(circuit:next,mode:.circuit,daily:false)}
                Button {tab=1} label: {Text("RACE CALENDAR →").font(RacingType.data(9)).foregroundStyle(muted)}
                Rectangle().fill(.white.opacity(0.1)).frame(height:1).padding(.vertical,4)
                Eyebrow(text:"DAILY CHALLENGE / +350")
                Button {activeRace=RaceRequest(circuit:Garage.dailyCircuit,mode:.drift,daily:true)} label: {HStack {Image(systemName:"wind");Text("AFTER HOURS").font(RacingType.title(18));Spacer();Image(systemName:"arrow.up.right")}.foregroundStyle(mint)}
                Text("\(Garage.dailyCircuit.name) / DRIFT TRIAL").font(RacingType.data(8)).foregroundStyle(muted)
                Spacer(minLength:0)
            }.padding(18).frame(width:280).background(Color(hex:0x11212D),in:RacingPanel(cut:14))
        }.padding(.trailing,20)
    }
    var home: some View {
        let next=Circuit.all[garage.save.unlockedRegion]
        return VStack(alignment:.leading,spacing:18) {
            SectionHeading(number:"01",title:"THE PADDOCK",detail:"SEASON 01")
            ZStack(alignment:.bottomLeading) {
                CarShowroom(car:garage.car).frame(height:295)
                LinearGradient(colors:[.clear,ink.opacity(0.88)],startPoint:.center,endPoint:.bottom).allowsHitTesting(false)
                VStack(alignment:.leading,spacing:5) { Eyebrow(text:"YOUR CURRENT DRIVE");Text(garage.car.name).font(RacingType.title(38));Text("\(Int(garage.car.speed*3.6)) KM/H  /  STAGE \(garage.save.upgrades[garage.car.id] ?? 0)  /  RWD").font(RacingType.data(9)).foregroundStyle(muted) }.padding(18)
            }.clipShape(RacingPanel(cut:18)).overlay(RacingPanel(cut:18).stroke(.white.opacity(0.1),lineWidth:1))
            VStack(alignment:.leading,spacing:12) {
                HStack { Eyebrow(text:"NEXT RACE / \(next.region)");Spacer();Image(systemName:"flag.checkered").foregroundStyle(mint) }
                HStack(alignment:.center) { VStack(alignment:.leading,spacing:6) {Text(next.name).font(RacingType.title(26));Text("CIRCUIT  /  2 LAPS  /  4 DRIVERS").font(RacingType.data(8)).foregroundStyle(muted)};Spacer();TrackMap(circuit:next).frame(width:90,height:70) }
                ActionButton(title:garage.save.races==0 ? "START YOUR FIRST RACE" : "ENTER THE GRID",icon:"flag.checkered") { activeRace=RaceRequest(circuit:next,mode:.circuit,daily:false) }
                Button { tab=1 } label: { HStack {Text("VIEW RACE CALENDAR").font(RacingType.data(9));Spacer();Image(systemName:"arrow.up.right")}.foregroundStyle(muted).padding(.top,2) }
            }.padding(18).background(Color(hex:0x1A2228),in:RacingPanel())
            HStack(alignment:.top,spacing:12) {
                Image(systemName:"antenna.radiowaves.left.and.right").foregroundStyle(mint)
                VStack(alignment:.leading,spacing:5) {Eyebrow(text:"PIT RADIO / MIKA");Text(garage.save.races==0 ? "Your father's Solstice is ready. A clean line, a little courage—let's get the garage back on the grid." : "Keep it smooth. Save nitro for the exit, and bring the car home in one piece.").font(.system(size:12)).foregroundStyle(muted).lineSpacing(3)}
            }.padding(16).background(Color(hex:0x182027),in:RacingPanel())
            SectionHeading(number:"02",title:"DAILY SESSION",detail:"+350 BONUS")
            Button { activeRace=RaceRequest(circuit:Garage.dailyCircuit,mode:.drift,daily:true) } label: {
                HStack {Image(systemName:"wind").font(.system(size:26)).foregroundStyle(mint);VStack(alignment:.leading,spacing:6) {Text("AFTER HOURS").font(RacingType.title(22));Text("\(Garage.dailyCircuit.name) / DRIFT TRIAL").font(RacingType.data(8)).foregroundStyle(muted)};Spacer();Image(systemName:"arrow.up.right")}.padding(18).background(Color(hex:0x1A2228),in:RacingPanel()).foregroundStyle(.white)
            }.buttonStyle(.plain)
            HStack(spacing:8) {stat("STARTS",garage.save.races.formatted());stat("WINS",garage.save.wins.formatted());stat("DISTANCE / KM",String(format:"%.1f",garage.save.distance))}
        }
    }
    func stat(_ title: String,_ value: String) -> some View { VStack(alignment:.leading,spacing:7) { Text(value).font(RacingType.data(23)); Eyebrow(text:title,color:muted) }.frame(maxWidth:.infinity,alignment:.leading).padding(16).background(Color(hex:0x1A2228),in:RacingPanel(cut:8)) }
    var campaign: some View {
        VStack(alignment:.leading,spacing:8) {
            SectionHeading(number:"03",title:"WORLD TOUR",detail:"20 CIRCUITS / 60 EVENTS")
            HStack(spacing:8) {
                ForEach(0..<4,id:\.self) {region in
                    let color=Color(hex:Circuit.all[region].color)
                    Button {calendarRegion=region} label: {
                        HStack(spacing:8) {
                            Text(String(format:"%02d",region+1)).font(RacingType.data(11)).foregroundStyle(color)
                            VStack(alignment:.leading,spacing:3) {
                                Text(["RIVIERA","NIGHT CITY","BADLANDS","ALPINE"][region]).font(RacingType.title(15))
                                Text("5 ROUTES / \(garage.save.stars(in:region)) OF 45 ★").font(RacingType.data(7)).foregroundStyle(muted)
                            }
                            Spacer(minLength:0)
                            if region>garage.save.unlockedRegion {Image(systemName:"lock.fill").font(.system(size:10))}
                        }.padding(11).background(calendarRegion==region ? color.opacity(0.22):ink.opacity(0.6),in:RacingPanel(cut:8))
                        .overlay(alignment:.bottom) {Rectangle().fill(calendarRegion==region ? color:.clear).frame(height:2)}
                    }.buttonStyle(.plain).accessibilityIdentifier("district-\(region)")
                }
            }
            ScrollView(.horizontal) {
                HStack(alignment:.top,spacing:14) {ForEach(Circuit.all.filter {$0.environment==calendarRegion}) {circuit in
                    let locked = !garage.save.isUnlocked(circuit)
                    VStack(alignment:.leading,spacing:6) {
                        HStack {Eyebrow(text:String(format:"ROUTE %02d",circuit.route+1),color:Color(hex:circuit.color));Spacer();Text(locked ? "LOCKED":"\((0..<3).reduce(0) {$0+(garage.save.medals[circuit.id*3+$1] ?? 0)})/9 ★").font(RacingType.data(8)).foregroundStyle(muted)}
                        HStack {VStack(alignment:.leading,spacing:5) {Text(circuit.name).font(RacingType.title(21));Text("\(String(format:"%.2f",circuit.length/1000)) KM / \(circuit.character)").font(RacingType.data(8)).foregroundStyle(muted)};Spacer();TrackMap(circuit:circuit).frame(width:66,height:44)}
                        ForEach(Array(RaceMode.allCases.enumerated()),id:\.offset) {index,mode in
                            Button {activeRace=RaceRequest(circuit:circuit,mode:mode,daily:false)} label: {HStack {
                                Image(systemName:mode == .circuit ? "flag.checkered":mode == .sprint ? "stopwatch":"wind").foregroundStyle(Color(hex:circuit.color))
                                VStack(alignment:.leading,spacing:2) {Text(mode.rawValue).font(.system(size:11,weight:.bold));Text(mode.detail).font(RacingType.data(7)).foregroundStyle(muted)}
                                Spacer();Image(systemName:locked ? "lock":"arrow.up.right").font(.system(size:10))
                            }.padding(7).background(ink.opacity(0.6),in:RacingPanel(cut:6))}.buttonStyle(.plain).disabled(locked)
                            .accessibilityIdentifier("event-\(circuit.id)-\(index)")
                        }
                        Text(locked ? "EARN 5 STARS IN THE PREVIOUS DISTRICT":circuit.look.setting).font(RacingType.data(7)).lineLimit(1).foregroundStyle(muted)
                    }.padding(10).frame(width:310).background(LinearGradient(colors:[Color(hex:circuit.color).opacity(0.18),Color(hex:0x11212D)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RacingPanel(cut:14)).opacity(locked ? 0.65:1)
                }}.padding(.bottom,8)
            }.accessibilityIdentifier("race-calendar").id(calendarRegion)
        }
    }
    var journal: some View {
        VStack(alignment:.leading,spacing:22) {
            SectionHeading(number:"04",title:"THE PIT WALL",detail:"CREW & LEGACY")
            Text("You inherited a shuttered garage and your father's Solstice. Mika, your oldest friend and mechanic, has a plan: enter the Afterlight Festival, win back the garage's reputation, and reach the summit race your father never finished.").font(.system(size:15)).foregroundStyle(muted).lineSpacing(6)
            ForEach(Array(Circuit.all.prefix(4))) { c in
                VStack(alignment:.leading,spacing:12) { HStack { Text(String(c.rival.prefix(1))).font(.system(size:28,weight:.black)).frame(width:58,height:58).background(Color(hex:c.color).opacity(0.15),in:Circle()).foregroundStyle(Color(hex:c.color)); VStack(alignment:.leading,spacing:5) { Eyebrow(text:c.region,color:Color(hex:c.color)); Text(c.rival.uppercased()).font(RacingType.title(24)) } }
                    HStack { Image(systemName:"sparkle").foregroundStyle(Color(hex:0xFFD76E)); Text("FATHER'S NOTEBOOK • \(garage.save.memories(in:c.environment))/12 SPARKS").font(.system(size:9,weight:.bold,design:.monospaced)).foregroundStyle(muted) }
                    if garage.save.memories(in:c.environment) >= 12 { Text(notebook(c.id)).font(.system(size:13,weight:.medium,design:.serif)).italic().foregroundStyle(Color(hex:0xF0D8AA)).lineSpacing(5).padding(14).background(ink,in:RacingPanel(cut:6)) }
                    Text(story(c.id)).font(.system(size:13)).foregroundStyle(muted).lineSpacing(5)
                    if c.id <= garage.save.unlockedRegion { Text(c.id==0 ? "“Speed is easy. A clean line takes heart.”" : c.id==1 ? "“The lights don't make the city. The people do.”" : c.id==2 ? "“Out here, patience is faster than pride.”" : "“Your father left a road. You get to choose where it leads.”").font(.system(size:14,weight:.semibold)).foregroundStyle(Color(hex:c.color)) }
                }.padding(20).background(Color(hex:0x1A2228),in:RacingPanel(cut:12))
            }
            Eyebrow(text:"YOUR MILESTONES")
            milestone("First light","Finish your first event",garage.save.races>0)
            milestone("A place on the podium","Win a circuit race",garage.save.wins>0)
            milestone("Collector","Own three original cars",garage.save.owned.count>=3)
            milestone("Road to the summit","Unlock Cloudline",garage.save.unlockedRegion==3)
            milestone("Festival legend","Earn all 180 campaign stars",garage.save.medals.values.reduce(0,+)>=180)
        }
    }
    func milestone(_ title:String,_ description:String,_ achieved:Bool) -> some View { HStack { Image(systemName:achieved ? "checkmark.seal.fill" : "seal").foregroundStyle(achieved ? mint : muted); VStack(alignment:.leading,spacing:4) { Text(title).font(.system(size:14,weight:.bold)); Text(description).font(.system(size:11)).foregroundStyle(muted) }; Spacer() }.padding(15).background(Color(hex:0x1A2228),in:RacingPanel(cut:6)) }
    func notebook(_ id:Int) -> String { ["“The coast taught me that a road is never just asphalt. It's every person waiting at the other end. Take care of the car. Take better care of the people.”", "“Nova was right: we drive to keep a place alive. Neon Harbor doesn't belong to the fastest driver. It belongs to everyone who calls it home.”", "“I lost a race in Ember Canyon and found something better: patience. Lift before the bend. Look further than the next corner. That works off the road, too.”", "“Iris, if I never make it back to Cloudline, tell my kid this: the finish line was never the point. I wanted to see what waited beyond the mountain. Now it's their turn.”"][id] }
    func story(_ id:Int) -> String { ["Luca runs the coastal delivery route. He knew your father, and offers your first invitation to the festival. Learn the rhythm of the coast and prove you belong.","Nova is the harbor's night-racing champion. Her crew protects the old waterfront from becoming another silent luxury district. Win her respect, and the city's roads open to you.","Rafa builds engines in a desert workshop. He values control over bravado. The canyon's tightening bends test whether you have learned to listen to your car.","Iris was your father's final rival. At Cloudline, the festival becomes more than a race: a chance to finish an old story and begin your own."][id] }
}
struct TrackMap: View {
    let circuit: Circuit
    var progress: Double? = nil
    var body: some View { GeometryReader { geometry in
        let points=(0...180).map { circuit.point(Double($0)/180) }
        let bound = CGFloat(circuit.radius*(1+circuit.distortion))*2.2
        Path { p in for (i,v) in points.enumerated() { let point=CGPoint(x:geometry.size.width/2+CGFloat(v.x)/bound*geometry.size.height,y:geometry.size.height/2+CGFloat(v.z)/bound*geometry.size.height); if i==0 { p.move(to:point) } else { p.addLine(to:point) } } }.stroke(Color(hex:circuit.color),style:StrokeStyle(lineWidth:3,lineCap:.round)).shadow(color:Color(hex:circuit.color).opacity(0.5),radius:8)
        if let progress {
            let car=circuit.point(progress)
            Circle().fill(.white).frame(width:7,height:7).shadow(color:.black,radius:2)
                .position(x:geometry.size.width/2+CGFloat(car.x)/bound*geometry.size.height,y:geometry.size.height/2+CGFloat(car.z)/bound*geometry.size.height)
        }
    } }
}
struct GarageView: View {
    @EnvironmentObject var garage: Garage
    @Binding var inspected: Int
    var car: Car { Car.all[inspected] }
    var body: some View {
        ZStack {
            LinearGradient(colors:[ink.opacity(0.85),.clear,.clear,ink.opacity(0.45)],startPoint:.leading,endPoint:.trailing).allowsHitTesting(false)
            VStack(alignment:.leading,spacing:10) {
                HStack(alignment:.top) {
                    VStack(alignment:.leading,spacing:12) {
                        Text("MOTORWORKS / COLLECTION").font(RacingType.data(7)).tracking(1.5).foregroundStyle(racingBlue)
                        Text(car.name).font(RacingType.title(30));Text(car.subtitle.uppercased()).font(RacingType.data(8)).foregroundStyle(racingBlue)
                        rating("TOP SPEED",car.speed/80);rating("HANDLING",car.handling/1.4);rating("TUNING",Double(garage.save.upgrades[car.id] ?? 0)/4)
                        Text("\(Int(car.speed*3.6)) KM/H  /  STAGE \(garage.save.upgrades[car.id] ?? 0)").font(RacingType.data(9)).foregroundStyle(.white)
                    }.frame(width:185,alignment:.leading).padding(14).background(ink.opacity(0.52),in:RacingPanel(cut:8))
                    Spacer()
                    Text("CLASS \(["GT","C","S","S","R","X"][car.id])").font(RacingType.title(22)).foregroundStyle(mint).padding(12).background(ink.opacity(0.6),in:RacingPanel(cut:8))
                }
                Spacer(minLength:10)
                HStack(alignment:.bottom,spacing:12) {
                    VStack(alignment:.leading,spacing:10) {
                        HStack(spacing:6) {ForEach(Car.all) {c in Button {inspected=c.id} label: {VStack(spacing:4) {Rectangle().fill(Color(hex:c.color)).frame(height:4);Text(c.name).font(RacingType.data(7)).foregroundStyle(inspected==c.id ? .white:muted)}.padding(9).background(inspected==c.id ? racingBlue.opacity(0.35):ink.opacity(0.65),in:RacingPanel(cut:4))}.accessibilityLabel(c.name)}}
                        if garage.save.selectedCar==car.id && (garage.save.upgrades[car.id] ?? 0)<4 {
                            Button {garage.upgrade()} label: {Label("UPGRADE • \(((garage.save.upgrades[car.id] ?? 0)+1)*600)",systemImage:"wrench.and.screwdriver.fill").font(RacingType.title(13)).foregroundStyle(ink).padding(12).background(racingBlue,in:RacingPanel(cut:6))}.disabled(garage.save.credits<((garage.save.upgrades[car.id] ?? 0)+1)*600)
                        }
                    }
                    Spacer(minLength:0)
                    if garage.save.owned.contains(car.id) {
                        ActionButton(title:garage.save.selectedCar==car.id ? "SELECTED":"SELECT",icon:"checkmark") {garage.save.selectedCar=car.id}.frame(width:190)
                    } else {ActionButton(title:"UNLOCK • \(car.price.formatted())",icon:"key.fill") {garage.buy(car)}.frame(width:190).disabled(garage.save.credits<car.price)}
                }
            }.padding(18)
        }.onAppear {inspected=garage.save.selectedCar}
    }

    func garageSpec(_ label:String,_ value:String,_ unit:String) -> some View { VStack(alignment:.leading,spacing:5) {Text(label).font(RacingType.data(7)).foregroundStyle(muted);Text(value).font(RacingType.title(25));Text(unit).font(RacingType.data(7)).foregroundStyle(mint)}.frame(maxWidth:.infinity,alignment:.leading).padding(12).background(Color(hex:0x1A2228),in:RacingPanel(cut:6)) }
    func rating(_ title:String,_ amount:Double) -> some View { HStack { Text(title).font(.system(size:10,weight:.bold,design:.monospaced)).tracking(1).foregroundStyle(muted).frame(width:85,alignment:.leading); TelemetryBar(value:amount,color:racingBlue) } }
}
struct SettingsView: View {
    @EnvironmentObject var garage: Garage
    @Environment(\.dismiss) var dismiss
    @State private var reset = false
    var body: some View { NavigationStack { Form {
        Section("The driving experience") { Toggle("Original synth soundtrack",isOn:$garage.save.music); Toggle("Engine and collectible sounds",isOn:Binding(get:{ garage.save.sounds ?? true },set:{ garage.save.sounds=$0 })); Toggle("Haptic feedback",isOn:$garage.save.haptics); VStack(alignment:.leading) { Text("Steering sensitivity"); Slider(value:$garage.save.steeringSensitivity,in:0.65...1.5) } }
        Section("How to drive") { Text("Your car accelerates automatically. Hold the left and right arrows to move across the track. Hold BRAKE to slow down; hold DRIFT while steering to build a combo. NITRO gives a burst of speed and recharges as you drive. Stay inside the road markings and safety barriers.").font(.subheadline) }
        Section("Your data") { Text("Your garage, race records, and settings stay on this device. No account, advertising, analytics, or tracking."); Link("Privacy policy",destination:URL(string:"https://oanarinaldi.com/turboracerprivacy.html")!); Button("Reset all progress",role:.destructive) { reset=true } }
        Section("Art credits") {if let url=Bundle.main.url(forResource:"AssetCredits",withExtension:"txt"),let credits=try? String(contentsOf:url) {Text(credits).font(.caption).textSelection(.enabled)}}
        Section { Text("TurboRacer: Afterlight • 2.0\nFictional racing cars, original circuits, story, and soundtrack.\nCreated by Oana Rinaldi.").font(.footnote).foregroundStyle(.secondary) }
    }.navigationTitle("Settings").toolbar { Button("Done") { dismiss() } }.confirmationDialog("Erase your garage and all race records?",isPresented:$reset,titleVisibility:.visible) { Button("Erase all progress",role:.destructive) { garage.reset() } } } }
}
struct RaceRequest: Identifiable { let id=UUID(); let circuit:Circuit; let mode:RaceMode; let daily:Bool }
