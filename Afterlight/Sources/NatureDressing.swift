import SceneKit

/// Scanned CC0 Poly Haven trees and rocks give each district its own natural
/// character: olive-like island trees and shoreline rocks on the coast,
/// quiver trees, boulders and cliffs in the badlands, mossy rocks, stumps and
/// rock faces among the alpine firs. Every piece keeps the full road clear.
@MainActor enum NatureDressing {
    private struct Piece { let name: String; let height: ClosedRange<Float>; let radius: Float; let lanes: ClosedRange<Double> }
    private static func palette(_ circuit: Circuit) -> [Piece] {
        switch circuit.environment {
        case 0: return [Piece(name: "IslandTree", height: 5...8, radius: 3, lanes: 15...40), Piece(name: "CoastLandRocks", height: 1.2...2.2, radius: 4, lanes: 14...30),
                        Piece(name: "RockFace", height: 2.5...4, radius: 3, lanes: 24...55)]
        case 2: return [Piece(name: "QuiverTree", height: 4...7, radius: 1.5, lanes: 14...45), Piece(name: "QuiverTreeB", height: 2.5...4, radius: 1.5, lanes: 14...40),
                        Piece(name: "DesertBoulder", height: 1.2...2.6, radius: 2.5, lanes: 13...35), Piece(name: "DesertBoulderB", height: 0.8...1.8, radius: 1.5, lanes: 13...30),
                        Piece(name: "DesertCliff", height: 6...11, radius: 9, lanes: 30...70), Piece(name: "DeadTrunk", height: 0.9...1.3, radius: 2.5, lanes: 14...30)]
        case 3: return [Piece(name: "MossRocks", height: 1.4...2.6, radius: 4.5, lanes: 14...40), Piece(name: "Boulder", height: 1.2...2.4, radius: 1.8, lanes: 13...35),
                        Piece(name: "RockFace", height: 4...8, radius: 4, lanes: 28...60), Piece(name: "Stump", height: 0.6...0.9, radius: 1.2, lanes: 13...28),
                        Piece(name: "DeadTrunk", height: 0.9...1.2, radius: 2.5, lanes: 14...30)]
        default: return []
        }
    }
    static func dress(_ circuit: Circuit, ground: (SIMD3<Float>) -> Float) -> SCNNode {
        let root = SCNNode(); root.name = "nature"
        let pieces = palette(circuit)
        guard !pieces.isEmpty else { return root }
        let road = (0..<240).map { circuit.point(Double($0)/240) }
        var seed = UInt32(circuit.id*7919+3)
        func r() -> Float { seed = seed &* 1664525 &+ 1013904223; return Float(seed >> 8)/Float(1 << 24) }
        let count = circuit.environment == 2 ? 90 : 70
        for i in 0..<count {
            let piece = pieces[i % pieces.count]
            let t = (Double(i)+Double(r()))/Double(count)
            let side: Double = r() < 0.5 ? -1 : 1
            let lane = piece.lanes.lowerBound+Double(r())*(piece.lanes.upperBound-piece.lanes.lowerBound)
            let p = circuit.point(t, lane: side*lane)
            if circuit.environment == 0 && p.x < -150 { continue }
            let scale = piece.height.lowerBound+r()*(piece.height.upperBound-piece.height.lowerBound)
            let radius = piece.radius*scale/piece.height.upperBound
            guard RouteScenery.allowsScenery(p, radius: radius, circuit: circuit),
                  road.allSatisfy({ hypot($0.x-p.x, $0.z-p.z) > 11+radius }),
                  let node = SceneDressing.asset(piece.name, height: scale) else { continue }
            node.position = SCNVector3(p.x, ground(p)-0.08, p.z); node.eulerAngles.y = r()*2 * .pi
            node.name = "nature-"+piece.name
            root.addChildNode(node)
        }
        return root
    }
}
