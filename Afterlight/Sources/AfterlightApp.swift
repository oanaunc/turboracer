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
/// Licensed Suno soundtrack: a menu theme and one track per district.
/// Switching tracks fades the old one out and the new one in.
final class Soundtrack {
    static let shared = Soundtrack()
    private var player: AVAudioPlayer?
    private var current = ""
    private var enabled = true
    static func track(for environment: Int) -> String { ["coast","city","badlands","summit"][max(0,min(3,environment))] }
    func play(enabled: Bool) { self.enabled = enabled; enabled ? switchTo(current.isEmpty ? "menu" : current) : player?.pause() }
    func switchTo(_ name: String, volume: Float = 0.32) {
        guard enabled else { current = name; return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient,mode:.default)
        if name == current, let player { player.setVolume(volume,fadeDuration:0.8); if !player.isPlaying { player.play() }; return }
        current = name
        let old = player
        old?.setVolume(0,fadeDuration:0.8)
        DispatchQueue.main.asyncAfter(deadline:.now()+0.85) { old?.stop() }
        guard let url = Bundle.main.url(forResource:"music-"+name,withExtension:"mp3") ?? Bundle.main.url(forResource:"afterlight",withExtension:"wav") else { return }
        let next = try? AVAudioPlayer(contentsOf:url); next?.numberOfLoops = -1; next?.volume = 0
        next?.play(); next?.setVolume(volume,fadeDuration:1.2); player = next
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
            if tab==0 {
                CarShowroom(car:garage.car,isActive:activeRace==nil && scenePhase == .active,focus:2.2).ignoresSafeArea()
                LinearGradient(colors:[ink.opacity(0.75),.clear,.clear,ink.opacity(0.8)],startPoint:.leading,endPoint:.trailing).ignoresSafeArea().allowsHitTesting(false)
                LinearGradient(colors:[ink.opacity(0.6),.clear,ink.opacity(0.55)],startPoint:.top,endPoint:.bottom).ignoresSafeArea().allowsHitTesting(false)
            } else if tab==2 {
                CarShowroom(car:Car.all[inspectedCar],isActive:activeRace==nil && scenePhase == .active).ignoresSafeArea()
                LinearGradient(colors:[ink.opacity(0.85),.clear,.clear],startPoint:.leading,endPoint:.trailing).ignoresSafeArea().allowsHitTesting(false)
                LinearGradient(colors:[ink.opacity(0.65),.clear,ink.opacity(0.25)],startPoint:.top,endPoint:.bottom).ignoresSafeArea().allowsHitTesting(false)
            } else {PaddockBackground()}
            VStack(spacing:0) {
                HStack(spacing:10) {
                    Image(systemName:"flag.checkered").foregroundStyle(mint).font(.system(size:20))
                    VStack(alignment:.leading,spacing:1) { Text("AFTERLIGHT").font(RacingType.title(21)).tracking(1); Text("MOTORSPORT / RACING FESTIVAL").font(RacingType.data(7)).tracking(1).foregroundStyle(muted) }
                    Spacer()
                    HStack(spacing:8) {
                        ZStack {Circle().stroke(.white.opacity(0.15),lineWidth:3);Circle().trim(from:0,to:garage.save.levelProgress).stroke(Color(hex:0xFFD23F),style:StrokeStyle(lineWidth:3,lineCap:.round)).rotationEffect(.degrees(-90));Text("\(garage.save.driverLevel)").font(RacingType.title(15))}.frame(width:34,height:34)
                        VStack(alignment:.leading,spacing:1) {Text("DRIVER LEVEL").font(RacingType.data(7)).foregroundStyle(muted);Text("\((garage.save.xp ?? 0)%1200)/1200 XP").font(RacingType.data(8))}
                    }.padding(.trailing,10).accessibilityElement(children:.combine)
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
            if let index=ProcessInfo.processInfo.arguments.firstIndex(of:"--preview-region"),ProcessInfo.processInfo.arguments.count>index+1,let region=Int(ProcessInfo.processInfo.arguments[index+1]),Circuit.all.indices.contains(region) {garage.save.races=1;activeRace=RaceRequest(circuit:Circuit.all[region],mode:ProcessInfo.processInfo.arguments.firstIndex(of:"--preview-mode").flatMap {i in RaceMode.allCases.first {$0.rawValue.lowercased()==ProcessInfo.processInfo.arguments[i+1]}} ?? (ProcessInfo.processInfo.arguments.contains("--preview-grid") ? .circuit:.sprint),daily:false)}
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
        let special=Garage.dailyCircuit
        let specialMode=RaceMode.special(for:special)
        return HStack(alignment:.bottom,spacing:16) {
            // The hero car fills the screen behind; its name sits low on the left.
            VStack(alignment:.leading,spacing:6) {
                Spacer()
                HStack(spacing:8) {Text("CLASS \(garage.car.carClass)").font(RacingType.title(13)).foregroundStyle(ink).padding(.horizontal,8).padding(.vertical,3).background(mint,in:RacingPanel(cut:4));Eyebrow(text:"YOUR CURRENT DRIVE")}
                Text(garage.car.name).font(RacingType.title(44)).shadow(color:.black.opacity(0.6),radius:8)
                HStack(spacing:14) {
                    miniStat("TOP SPEED","\(Int(garage.car.speed*3.6)) KM/H");miniStat("STAGE","\(garage.save.upgrades[garage.car.id] ?? 0)/4");miniStat("WINS",garage.save.wins.formatted())
                }
            }.frame(maxWidth:.infinity,alignment:.leading)
            VStack(spacing:10) {
                Button {activeRace=RaceRequest(circuit:next,mode:.circuit,daily:false)} label: {
                    modeTile(art:next,eyebrow:"CAREER / \(next.region)",title:next.name,detail:garage.save.races==0 ? "START YOUR FIRST RACE":"ENTER THE GRID",icon:"flag.checkered",accent:Color(hex:0xFFD23F),height:132)
                }.buttonStyle(.plain).accessibilityLabel(garage.save.races==0 ? "Start your first race" : "Enter the grid")
                HStack(spacing:10) {
                    Button {activeRace=RaceRequest(circuit:special,mode:specialMode,daily:false)} label: {
                        modeTile(art:special,eyebrow:"SPECIAL EVENT",title:specialMode.rawValue.uppercased(),detail:special.name,icon:specialMode.icon,accent:Color(hex:0xFF5F6D),height:96)
                    }.buttonStyle(.plain).disabled(!garage.save.isUnlocked(special))
                    Button {activeRace=RaceRequest(circuit:Garage.dailyCircuit,mode:.drift,daily:true)} label: {
                        modeTile(art:Garage.dailyCircuit,eyebrow:"DAILY / +350",title:"AFTER HOURS",detail:"DRIFT TRIAL",icon:"wind",accent:mint,height:96)
                    }.buttonStyle(.plain)
                }
                Button {tab=1} label: {HStack {Image(systemName:"map.fill");Text("WORLD TOUR / 80 EVENTS").font(RacingType.data(9));Spacer();Image(systemName:"arrow.right")}.foregroundStyle(.white).padding(12).background(.ultraThinMaterial,in:RacingPanel(cut:8)).environment(\.colorScheme,.dark)}
            }.frame(width:330)
        }.padding(.trailing,20).padding(.bottom,6)
    }
    func miniStat(_ title:String,_ value:String) -> some View {VStack(alignment:.leading,spacing:2) {Text(value).font(RacingType.data(13));Text(title).font(RacingType.data(7)).foregroundStyle(muted)}}
    func modeTile(art:Circuit,eyebrow:String,title:String,detail:String,icon:String,accent:Color,height:CGFloat) -> some View {
        ZStack(alignment:.bottomLeading) {
            CircuitArtwork(circuit:art,showsSetting:false)
            LinearGradient(colors:[.clear,ink.opacity(0.92)],startPoint:.top,endPoint:.bottom)
            VStack(alignment:.leading,spacing:3) {
                Text(eyebrow).font(RacingType.data(7)).tracking(1.5).foregroundStyle(accent)
                Text(title).font(RacingType.title(height>110 ? 26:17)).lineLimit(1).minimumScaleFactor(0.6)
                HStack {Text(detail).font(RacingType.data(8)).foregroundStyle(.white.opacity(0.75)).lineLimit(1);Spacer();Image(systemName:icon).foregroundStyle(accent)}
            }.padding(10)
        }.frame(height:height).clipShape(RacingPanel(cut:12)).overlay(RacingPanel(cut:12).stroke(accent.opacity(0.55),lineWidth:1)).foregroundStyle(.white)
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
            SectionHeading(number:"03",title:"WORLD TOUR",detail:"20 CIRCUITS / 80 EVENTS")
            HStack(spacing:8) {
                ForEach(0..<4,id:\.self) {region in
                    let color=Color(hex:Circuit.all[region].color)
                    Button {calendarRegion=region} label: {
                        HStack(spacing:8) {
                            Text(String(format:"%02d",region+1)).font(RacingType.data(11)).foregroundStyle(color)
                            VStack(alignment:.leading,spacing:3) {
                                Text(["RIVIERA","NIGHT CITY","BADLANDS","ALPINE"][region]).font(RacingType.title(15))
                                Text("5 ROUTES / \(garage.save.stars(in:region)) OF 60 ★").font(RacingType.data(7)).foregroundStyle(muted)
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
                        ZStack(alignment:.bottomLeading) {
                            CircuitArtwork(circuit:circuit,showsSetting:false).frame(height:96).clipShape(RacingPanel(cut:8))
                            LinearGradient(colors:[.clear,ink.opacity(0.85)],startPoint:.top,endPoint:.bottom).clipShape(RacingPanel(cut:8)).allowsHitTesting(false)
                            HStack(alignment:.bottom) {
                                VStack(alignment:.leading,spacing:3) {Eyebrow(text:String(format:"ROUTE %02d",circuit.route+1),color:Color(hex:circuit.color));Text(circuit.name).font(RacingType.title(19));Text("\(String(format:"%.2f",circuit.length/1000)) KM / \(circuit.character)").font(RacingType.data(7)).foregroundStyle(muted)}
                                Spacer()
                                VStack(alignment:.trailing,spacing:4) {TrackMap(circuit:circuit).frame(width:46,height:32);Text(locked ? "LOCKED":"\(RaceMode.events(for:circuit).reduce(0) {$0+(garage.save.medals[RaceMode.key(circuit,$1)] ?? 0)})/12 ★").font(RacingType.data(8)).foregroundStyle(.white)}
                            }.padding(9)
                        }.frame(height:96)
                        LazyVGrid(columns:[GridItem(.flexible(),spacing:6),GridItem(.flexible(),spacing:6)],spacing:6) {
                            ForEach(Array(RaceMode.events(for:circuit).enumerated()),id:\.offset) {index,mode in
                                let stars=garage.save.medals[RaceMode.key(circuit,mode)] ?? 0
                                Button {activeRace=RaceRequest(circuit:circuit,mode:mode,daily:false)} label: {HStack(spacing:6) {
                                    Image(systemName:mode.icon).font(.system(size:13)).foregroundStyle(Color(hex:circuit.color)).frame(width:20).minimumScaleFactor(0.5)
                                    VStack(alignment:.leading,spacing:2) {Text(mode.rawValue).font(.system(size:11,weight:.bold)).lineLimit(1);Text(locked ? "LOCKED":String(repeating:"★",count:stars)+String(repeating:"☆",count:3-stars)).font(RacingType.data(7)).foregroundStyle(stars>0 ? mint:muted)}
                                    Spacer(minLength:0)
                                }.padding(7).background(index==3 ? Color(hex:circuit.color).opacity(0.22):ink.opacity(0.6),in:RacingPanel(cut:6))}.buttonStyle(.plain).disabled(locked)
                                .accessibilityIdentifier("event-\(circuit.id)-\(index)").accessibilityHint(mode.detail)
                            }
                        }
                        if locked {Text("EARN 5 STARS IN THE PREVIOUS DISTRICT").font(RacingType.data(7)).lineLimit(1).foregroundStyle(muted)}
                    }.padding(10).frame(width:310).background(LinearGradient(colors:[Color(hex:circuit.color).opacity(0.18),Color(hex:0x11212D)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RacingPanel(cut:14)).opacity(locked ? 0.65:1)
                }}.padding(.bottom,8)
            }.accessibilityIdentifier("race-calendar").id(calendarRegion)
        }
    }
    var journal: some View {
        VStack(alignment:.leading,spacing:22) {
            SectionHeading(number:"04",title:"THE PIT WALL",detail:"CREW & LEGACY")
            if let art=SurfaceLibrary.image("crew") { Image(uiImage:art).resizable().aspectRatio(contentMode:.fit).clipShape(RacingPanel(cut:16)).accessibilityLabel("Luca, Nova, Rafa and Iris in the Afterlight workshop") }
            Text("You inherited a shuttered garage and your father's Solstice. Mika, your oldest friend and mechanic, has a plan: enter the Afterlight Festival, win back the garage's reputation, and reach the summit race your father never finished.").font(.system(size:15)).foregroundStyle(muted).lineSpacing(6)
            ForEach(Array(Circuit.all.prefix(4))) { c in
                VStack(alignment:.leading,spacing:12) { HStack { Text(String(c.rival.prefix(1))).font(.system(size:28,weight:.black)).frame(width:58,height:58).background(Color(hex:c.color).opacity(0.15),in:Circle()).foregroundStyle(Color(hex:c.color)); VStack(alignment:.leading,spacing:5) { Eyebrow(text:c.region,color:Color(hex:c.color)); Text(c.rival.uppercased()).font(RacingType.title(24)) } }
                    HStack { Image(systemName:"memorychip.fill").foregroundStyle(racingBlue); Text("FATHER'S NOTEBOOK • \(garage.save.memories(in:c.environment))/12 CHIPS").font(.system(size:9,weight:.bold,design:.monospaced)).foregroundStyle(muted) }
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
            milestone("Festival legend","Earn all 240 campaign stars",garage.save.medals.values.reduce(0,+)>=240)
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
                        Text(car.name).font(RacingType.title(30)).lineLimit(1).minimumScaleFactor(0.6);Text(car.subtitle.uppercased()).font(RacingType.data(8)).foregroundStyle(racingBlue)
                        rating("TOP SPEED",car.speed/80);rating("ACCEL",car.acceleration);rating("HANDLING",car.handling/1.4);rating("TUNING",Double(garage.save.upgrades[car.id] ?? 0)/4)
                        Text("\(Int(car.speed*3.6)) KM/H  /  STAGE \(garage.save.upgrades[car.id] ?? 0)").font(RacingType.data(9)).foregroundStyle(.white)
                    }.frame(width:185,alignment:.leading).padding(14).background(ink.opacity(0.52),in:RacingPanel(cut:8))
                    Spacer()
                    Text("CLASS \(car.carClass)").font(RacingType.title(22)).foregroundStyle(mint).padding(12).background(ink.opacity(0.6),in:RacingPanel(cut:8))
                }
                Spacer(minLength:10)
                HStack(alignment:.bottom,spacing:12) {
                    VStack(alignment:.leading,spacing:10) {
                        ScrollViewReader { proxy in ScrollView(.horizontal,showsIndicators:false) {HStack(spacing:6) {ForEach(Car.all) {c in Button {inspected=c.id} label: {VStack(alignment:.leading,spacing:4) {Rectangle().fill(Color(hex:c.color)).frame(height:4);HStack(spacing:5) {Text(c.carClass).font(RacingType.title(10)).foregroundStyle(mint);Text(c.name).font(RacingType.data(7)).foregroundStyle(inspected==c.id ? .white:muted).lineLimit(1)};if !garage.save.owned.contains(c.id) {Image(systemName:"lock.fill").font(.system(size:7)).foregroundStyle(muted)}}.frame(minWidth:74,alignment:.leading).padding(9).background(inspected==c.id ? racingBlue.opacity(0.35):ink.opacity(0.65),in:RacingPanel(cut:4))}.id(c.id).accessibilityLabel(c.name)}}}.frame(maxWidth:560).onAppear {proxy.scrollTo(inspected,anchor:.center)}.onChange(of:inspected) {_,value in withAnimation {proxy.scrollTo(value,anchor:.center)}} }
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
        Section("The driving experience") { Toggle("Music",isOn:$garage.save.music); Toggle("Engine and collectible sounds",isOn:Binding(get:{ garage.save.sounds ?? true },set:{ garage.save.sounds=$0 })); Toggle("Haptic feedback",isOn:$garage.save.haptics); Toggle("Tilt to steer",isOn:Binding(get:{ garage.save.tiltSteering ?? false },set:{ garage.save.tiltSteering=$0 })); VStack(alignment:.leading) { Text("Steering sensitivity"); Slider(value:$garage.save.steeringSensitivity,in:0.65...1.5) } }
        Section("How to drive") { Text("Your car accelerates automatically. Hold the left and right arrows, or turn on Tilt to steer and turn your device like a wheel. Hold BRAKE to slow down; hold DRIFT while steering to build a combo. NITRO gives a burst of speed and recharges as you drive. Stay inside the road markings and safety barriers.").font(.subheadline) }
        Section("Your data") { Text("Your garage, race records, and settings stay on this device. No account, advertising, analytics, or tracking."); Link("Privacy policy",destination:URL(string:"https://oanarinaldi.com/afterlightprivacy.html")!); Button("Reset all progress",role:.destructive) { reset=true } }
        Section("Art credits") {if let url=Bundle.main.url(forResource:"AssetCredits",withExtension:"txt"),let credits=try? String(contentsOf:url) {Text(credits).font(.caption).textSelection(.enabled)}}
        Section { Text("Afterlight: Racing Festival • 1.0\nFictional racing cars, original circuits, story, and soundtrack.\nCreated by Oana Rinaldi.").font(.footnote).foregroundStyle(.secondary) }
    }.navigationTitle("Settings").toolbar { Button("Done") { dismiss() } }.confirmationDialog("Erase your garage and all race records?",isPresented:$reset,titleVisibility:.visible) { Button("Erase all progress",role:.destructive) { garage.reset() } } } }
}
struct RaceRequest: Identifiable { let id=UUID(); let circuit:Circuit; let mode:RaceMode; let daily:Bool }
