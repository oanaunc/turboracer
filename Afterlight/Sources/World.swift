import Foundation
import SwiftUI

struct Car: Identifiable {
    let id: Int; let name: String; let subtitle: String; let price: Int
    let speed: Double; let handling: Double; let color: UInt32
    static let all = [
        Car(id: 0, name: "SOLSTICE", subtitle: "An elegant grand tourer", price: 0, speed: 54, handling: 1.0, color: 0xFF780C),
        Car(id: 1, name: "KOMET", subtitle: "Light feet. Heavy attitude.", price: 1800, speed: 57, handling: 1.2, color: 0x59E8D4),
        Car(id: 2, name: "VANTA", subtitle: "Born for the midnight run", price: 3600, speed: 61, handling: 0.95, color: 0xA68CFF),
        Car(id: 3, name: "AURORA", subtitle: "A beautiful kind of chaos", price: 6000, speed: 65, handling: 1.1, color: 0xFFD76E),
        Car(id: 4, name: "SPECTRE", subtitle: "Leave nothing but light", price: 9000, speed: 70, handling: 1.05, color: 0xF576C5),
        Car(id: 5, name: "AFTERLIGHT", subtitle: "Tomorrow belongs to you", price: 13000, speed: 74, handling: 1.25, color: 0xD9F8F5)
    ]
}
struct Circuit: Identifiable {
    let id: Int; let name: String; let region: String; let tagline: String
    let color: UInt32; let radius: Double; let distortion: Double
    let sky: UInt32; let ground: UInt32; let rival: String
    static let all = [
        Circuit(id: 0, name: "PALM COAST", region: "01 / THE COAST", tagline: "Salt in the air. Fire in the engine.", color: 0xFFAA79, radius: 105, distortion: 0.14, sky: 0x241B42, ground: 0x224D57, rival: "Luca"),
        Circuit(id: 1, name: "NEON HARBOR", region: "02 / THE CITY", tagline: "The city only sleeps when you stop.", color: 0x59E8D4, radius: 115, distortion: 0.25, sky: 0x090F28, ground: 0x121C34, rival: "Nova"),
        Circuit(id: 2, name: "EMBER CANYON", region: "03 / THE BADLANDS", tagline: "Find your line through the fire.", color: 0xFFD76E, radius: 125, distortion: 0.32, sky: 0x47283F, ground: 0x623C3B, rival: "Rafa"),
        Circuit(id: 3, name: "CLOUDLINE", region: "04 / THE SUMMIT", tagline: "Above the noise. Beyond the ordinary.", color: 0xBBA8FF, radius: 110, distortion: 0.38, sky: 0x272B53, ground: 0x3A5060, rival: "Iris")
    ]
    func point(_ progress: Double, lane: Double = 0) -> SIMD3<Float> {
        let t = progress * 2 * Double.pi
        let r = radius * (1 + distortion * sin(3*t + Double(id))) + lane
        return SIMD3(Float(sin(t)*r), 0, Float(cos(t)*r))
    }
    func heading(_ progress: Double) -> Float {
        let a = point(progress), b = point(progress + 0.0001)
        return atan2(b.x-a.x, b.z-a.z)
    }
    var length: Double {
        (0..<600).reduce(0) { sum, i in
            let a = point(Double(i)/600), b = point(Double(i+1)/600)
            return sum + Double(sqrt(pow(b.x-a.x,2)+pow(b.z-a.z,2)))
        }
    }
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
    var unlockedRegion: Int { min(3, (0..<4).first(where: { region in (0..<3).reduce(0) { $0 + (medals[region*3+$1] ?? 0) } < 5 }) ?? 3) }
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
    static var dailyCircuit: Circuit { let days = Int(Date().timeIntervalSince1970/86400); return Circuit.all[days % 4] }
    func reset() { save = SaveData() }
}
extension Color { init(hex: UInt32) { self.init(red: Double((hex>>16)&255)/255, green: Double((hex>>8)&255)/255, blue: Double(hex&255)/255) } }
