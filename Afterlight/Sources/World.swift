import Foundation
import SwiftUI

struct Car: Identifiable {
    let id: Int; let name: String; let subtitle: String; let price: Int
    let speed: Double; let handling: Double; let color: UInt32
    var modelName: String { ["LuxurySedan","SportsCoupe","ConceptGT","Roadster","Hyper","Hyper"][id] }
    // The later three garage entries share a platform. Exclude the whole
    // family so a rival cannot be a roof/wing variant of the player's body.
    var bodyFamily: String { id<3 ? modelName : "ConceptPlatform" }
    static func rivals(for player:Car,route:Int) -> [Car] {
        var used=Set([player.bodyFamily]),grid:[Car]=[]
        for offset in 0..<all.count {
            let candidate=all[(route+offset)%all.count]
            if used.insert(candidate.bodyFamily).inserted {grid.append(candidate)}
            if grid.count==3 {break}
        }
        return grid
    }
    static let all = [
        Car(id: 0, name: "SOLSTICE", subtitle: "An elegant grand tourer", price: 0, speed: 54, handling: 1.0, color: 0xFF780C),
        Car(id: 1, name: "KOMET", subtitle: "Light feet. Heavy attitude.", price: 1800, speed: 57, handling: 1.2, color: 0x59E8D4),
        Car(id: 2, name: "VANTA", subtitle: "Born for the midnight run", price: 3600, speed: 61, handling: 0.95, color: 0xA68CFF),
        Car(id: 3, name: "AURORA", subtitle: "A beautiful kind of chaos", price: 6000, speed: 65, handling: 1.1, color: 0xFFD76E),
        Car(id: 4, name: "SPECTRE", subtitle: "Leave nothing but light", price: 9000, speed: 70, handling: 1.05, color: 0xF576C5),
        Car(id: 5, name: "AFTERLIGHT", subtitle: "Tomorrow belongs to you", price: 13000, speed: 74, handling: 1.25, color: 0xD9F8F5)
    ]
}
/// Closed, arc-length sampled courses. Lane offsets are real metres normal to
/// the racing line, so a tight corner cannot squeeze the road or its colliders.
struct Circuit: Identifiable {
    let id: Int
    let name: String
    let tagline: String
    let environment: Int
    let route: Int
    private let samples: [SIMD3<Float>]
    let length: Double
    var region: String { ["01 / THE COAST","02 / THE CITY","03 / THE BADLANDS","04 / THE SUMMIT"][environment] }
    var color: UInt32 { [0xFFAA79,0x59E8D4,0xFFD76E,0xBBA8FF][environment] }
    var sky: UInt32 { [0x241B42,0x090F28,0x47283F,0x272B53][environment] }
    var ground: UInt32 { [0x224D57,0x121C34,0x623C3B,0x3A5060][environment] }
    var rival: String { ["Luca","Nova","Rafa","Iris"][environment] }
    var character: String { ["BALANCED", "HIGH SPEED", "TECHNICAL", "ENDURANCE", "PRECISION"][route] }
    var radius: Double { Double(samples.reduce(Float(0)) {max($0,max(abs($1.x),abs($1.z)))}) }
    var distortion: Double { 0 }

    private init(_ id: Int, _ name: String, _ tagline: String, _ environment: Int, _ route: Int, _ coordinates: [(Float,Float)]) {
        self.id=id; self.name=name; self.tagline=tagline; self.environment=environment; self.route=route
        let controls=coordinates.map {SIMD3<Float>($0.0,0,$0.1)}, count=controls.count, resolution=1024
        func raw(_ t:Float) -> SIMD3<Float> {
            let u=t*Float(count), i=Int(u)%count, f=u-Float(Int(u))
            let a=controls[(i+count-1)%count], b=controls[i], c=controls[(i+1)%count], d=controls[(i+2)%count]
            return (b*2+(c-a)*f+(a*2-b*5+c*4-d)*f*f+(-a+b*3-c*3+d)*f*f*f)*0.5
        }
        let source=(0...resolution).map {raw(Float($0)/Float(resolution))}
        var distances=[Float(0)]
        for i in 1...resolution {let delta=source[i]-source[i-1]; distances.append(distances.last!+sqrt(delta.x*delta.x+delta.z*delta.z))}
        let total=distances.last!; self.length=Double(total)
        var points:[SIMD3<Float>]=[], segment=1
        for i in 0..<resolution {
            let target=total*Float(i)/Float(resolution)
            while segment<resolution && distances[segment]<target {segment += 1}
            let fraction=(target-distances[segment-1])/max(0.0001,distances[segment]-distances[segment-1])
            points.append(source[segment-1]+(source[segment]-source[segment-1])*fraction)
        }
        self.samples=points
    }
    private func center(_ progress: Double) -> SIMD3<Float> {
        let wrapped=progress-floor(progress), u=wrapped*Double(samples.count), i=Int(u)%samples.count
        return samples[i]+(samples[(i+1)%samples.count]-samples[i])*Float(u-floor(u))
    }
    func heading(_ progress: Double) -> Float {
        let tangent=center(progress+0.0005)-center(progress-0.0005)
        return atan2(tangent.x,tangent.z)
    }
    func point(_ progress: Double, lane: Double = 0) -> SIMD3<Float> {
        let p=center(progress)
        guard lane != 0 else {return p}
        let h=heading(progress)
        return p+SIMD3<Float>(cos(h)*Float(lane),0,-sin(h)*Float(lane))
    }
    // Preserve the four original IDs: medals, records and notebook saves migrate
    // without losing progress. Each district gains four separately authored routes.
    static let all: [Circuit] = [
        Circuit(0,"PALM COAST","Salt in the air. Fire in the engine.",0,0,[(0,120),(100,110),(135,30),(90,-95),(-20,-125),(-110,-65),(-125,45)]),
        Circuit(1,"NEON HARBOR","The city only sleeps when you stop.",1,0,[(0,140),(120,140),(145,60),(65,10),(135,-80),(55,-145),(-105,-130),(-140,-40),(-85,45),(-125,125)]),
        Circuit(2,"EMBER CANYON","Find your line through the fire.",2,0,[(0,150),(105,100),(75,10),(155,-55),(95,-130),(-10,-100),(-100,-145),(-155,-50),(-65,20),(-100,100)]),
        Circuit(3,"CLOUDLINE","Above the noise. Beyond the ordinary.",3,0,[(0,140),(130,110),(110,25),(35,-25),(105,-100),(10,-160),(-120,-100),(-100,-20),(-150,65),(-75,120)]),
        Circuit(4,"AZURE RUN","A long seafront straight. One perfect exit.",0,1,[(0,180),(110,155),(130,30),(105,-150),(0,-185),(-110,-140),(-120,0),(-90,155)]),
        Circuit(5,"MARINA LOOP","Late braking around the old marina.",0,2,[(0,110),(100,120),(135,35),(55,-15),(90,-105),(-20,-145),(-105,-80),(-65,0),(-115,70)]),
        Circuit(6,"RIVIERA GP","From the coastal villas to the headland.",0,3,[(0,190),(125,180),(180,95),(120,10),(165,-110),(30,-190),(-110,-130),(-100,-25),(-130,100)]),
        Circuit(7,"SUNSET POINT","Clip the apex. Chase the last light.",0,4,[(0,125),(125,75),(80,-10),(140,-90),(20,-145),(-110,-100),(-60,-15),(-120,70)]),
        Circuit(8,"DOCKLANDS","Open the throttle through the shipping district.",1,1,[(0,190),(145,165),(155,-135),(80,-195),(-130,-175),(-160,-90),(-95,0),(-145,130)]),
        Circuit(9,"OLD QUARTER","A rhythm of squares and narrow exits.",1,2,[(0,135),(120,105),(115,15),(40,-30),(80,-120),(-15,-150),(-120,-65),(-60,25),(-110,100)]),
        Circuit(10,"METROPOLIS","The full city. No room for hesitation.",1,3,[(0,195),(140,150),(185,30),(110,-60),(130,-160),(0,-200),(-140,-140),(-180,-20),(-105,50),(-140,155)]),
        Circuit(11,"NIGHTSHIFT","Link the harbor's four hardest corners.",1,4,[(0,130),(135,100),(110,5),(30,-50),(75,-145),(-70,-130),(-140,-30),(-70,25),(-95,115)]),
        Circuit(12,"REDLINE MESA","Long straights beneath the red cliffs.",2,1,[(0,190),(120,140),(140,-145),(30,-195),(-115,-160),(-145,65),(-85,160)]),
        Circuit(13,"DEVIL'S ELBOW","Two linked bends demand a steady hand.",2,2,[(0,140),(120,115),(140,20),(55,-20),(100,-110),(-20,-165),(-140,-80),(-65,0),(-120,95)]),
        Circuit(14,"DUST TRAIL","An endurance loop through the badlands.",2,3,[(0,210),(155,150),(185,25),(100,-55),(150,-150),(0,-220),(-160,-150),(-190,-40),(-110,30),(-150,140)]),
        Circuit(15,"COPPER RIDGE","Commit to every braking point.",2,4,[(0,155),(115,85),(60,0),(145,-80),(45,-165),(-80,-120),(-140,-25),(-60,35),(-105,125)]),
        Circuit(16,"SKY EXPRESS","Clean mountain air. Unbroken speed.",3,1,[(0,205),(110,155),(140,-130),(40,-205),(-120,-160),(-140,100),(-70,185)]),
        Circuit(17,"ALPINE SWITCH","A technical dance above the treeline.",3,2,[(0,150),(125,115),(90,25),(145,-65),(35,-140),(-105,-105),(-60,-10),(-130,75)]),
        Circuit(18,"SUMMIT TOUR","The longest road to the festival crown.",3,3,[(0,215),(145,165),(200,50),(100,-30),(165,-130),(20,-220),(-130,-170),(-200,-50),(-110,45),(-150,150)]),
        Circuit(19,"LAST LIGHT","Your final invitation. Make it count.",3,4,[(0,165),(135,105),(75,20),(150,-70),(40,-170),(-110,-130),(-160,-30),(-75,40),(-115,135)])
    ]
}
enum RaceMode: String, CaseIterable { case circuit = "Circuit", sprint = "Time attack", drift = "Drift run"
    var detail: String { switch self { case .circuit: return "2 laps • 3 rivals"; case .sprint: return "1 lap • chase the clock"; case .drift: return "1 lap • build your drift score" } }
}
struct RaceResult {
    let position: Int; let time: Double; let drift: Int; let credits: Int; let stars: Int
    var collected: Int = 0
}
struct SaveData: Codable {
    var credits = 0; var selectedCar = 0; var owned = [0]
    var upgrades: [Int: Int] = [:]; var medals: [Int: Int] = [:]
    var bestTimes: [Int: Double] = [:]; var bestDrifts: [Int: Int] = [:]
    var races = 0; var wins = 0; var distance = 0.0
    var sounds: Bool? = nil
    var music = true; var haptics = true; var steeringSensitivity = 1.0
    var dailyStamp = ""; var dailyBest = 0
    var memorySparks: [Int: Int]? = nil
    var dailyRewardStamp: String? = nil
    func stars(in environment: Int) -> Int {
        Circuit.all.filter {$0.environment == environment}.reduce(0) {sum,c in sum+(0..<3).reduce(0) {$0+(medals[c.id*3+$1] ?? 0)}}
    }
    func memories(in environment: Int) -> Int {
        min(12,Circuit.all.filter {$0.environment==environment}.reduce(0) {$0+(memorySparks?[$1.id] ?? 0)})
    }
    var unlockedRegion: Int { min(3,(0..<4).first(where:{stars(in:$0)<5}) ?? 3) }
    func isUnlocked(_ circuit: Circuit) -> Bool { circuit.environment <= unlockedRegion }
}
@MainActor final class Garage: ObservableObject {
    @Published var save: SaveData { didSet { persist() } }
    private let storage: UserDefaults
    init(storage: UserDefaults = .standard) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--journey-review") {
            let fixture=UserDefaults(suiteName:"afterlight.journey.review")!
            fixture.removePersistentDomain(forName:"afterlight.journey.review")
            self.storage=fixture;save=SaveData();return
        }
        if ProcessInfo.processInfo.arguments.contains("--visual-review") {
            let fixture=UserDefaults(suiteName:"afterlight.visual.review")!
            fixture.removePersistentDomain(forName:"afterlight.visual.review")
            self.storage=fixture
            var demo=SaveData();demo.credits=30000;demo.owned=Array(0..<6)
            for region in 0..<3 { demo.medals[region*3]=3;demo.medals[region*3+1]=3 }
            save=demo;return
        }
        #endif
        self.storage = storage
        save = storage.data(forKey: "afterlight.save.v1").flatMap { try? JSONDecoder().decode(SaveData.self, from: $0) } ?? SaveData()
    }
    func persist() { if let data = try? JSONEncoder().encode(save) { storage.set(data, forKey: "afterlight.save.v1") } }
    var car: Car { Car.all.first { $0.id == save.selectedCar } ?? Car.all[0] }
    func buy(_ car: Car) { guard !save.owned.contains(car.id), save.credits >= car.price else { return }; save.credits -= car.price; save.owned.append(car.id); save.selectedCar = car.id }
    func upgrade() { let level = save.upgrades[car.id] ?? 0; let cost = (level+1)*600; guard level < 4, save.credits >= cost else { return }; save.credits -= cost; save.upgrades[car.id] = level+1 }
    func record(_ result: RaceResult, circuit: Circuit, mode: RaceMode, daily: Bool) {
        let key = circuit.id*3 + (RaceMode.allCases.firstIndex(of: mode) ?? 0)
        save.credits += result.credits; save.races += 1; save.wins += result.position == 1 ? 1 : 0
        save.distance += circuit.length * (mode == .circuit ? 2 : 1) / 1000
        if !daily { save.medals[key] = max(save.medals[key] ?? 0, result.stars) }
        var memories = save.memorySparks ?? [:]; memories[circuit.id] = min(12,(memories[circuit.id] ?? 0)+result.collected); save.memorySparks = memories
        save.bestTimes[key] = min(save.bestTimes[key] ?? .infinity, result.time)
        save.bestDrifts[key] = max(save.bestDrifts[key] ?? 0, result.drift)
        if daily { let day = Self.dayStamp(); if save.dailyRewardStamp != day && result.stars > 0 { save.credits += 350; save.dailyRewardStamp = day }; if save.dailyStamp != day { save.dailyBest = 0 }; save.dailyStamp = day; save.dailyBest = max(save.dailyBest, result.drift) }
    }
    static func dayStamp(date: Date = Date()) -> String { let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
    static var dailyCircuit: Circuit { let days = Int(Date().timeIntervalSince1970/86400); return Circuit.all[days % Circuit.all.count] }
    func reset() { save = SaveData() }
}
extension Color { init(hex: UInt32) { self.init(red: Double((hex>>16)&255)/255, green: Double((hex>>8)&255)/255, blue: Double(hex&255)/255) } }
