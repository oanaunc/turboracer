import SceneKit
import UIKit

/// A launch ramp laid across part of the road. Progress is the fraction of
/// the lap where the ramp starts; lane is its centre in road-normal metres.
struct Ramp {
    let progress: Double
    let lane: Double
    let barrel: Bool
    var halfWidth: Double { barrel ? 2.4 : 3.2 }
    let length = 9.0
    var height: Double { barrel ? 1.5 : 1.25 }

    /// Two ramps per circuit, clear of the start line and the chip positions.
    static func layout(for circuit: Circuit) -> [Ramp] {
        let side = circuit.id%2==0 ? 1.0 : -1.0
        return [Ramp(progress:0.27,lane:side*3,barrel:false),Ramp(progress:0.655,lane:-side*3.4,barrel:true)]
    }

    /// Height of the ramp surface under a point, or nil when off the ramp.
    func surface(progress p: Double, lane l: Double, trackLength: Double) -> Double? {
        let d = ((p-floor(p))-progress)*trackLength
        guard d >= 0, d <= length, abs(l-lane) < halfWidth else { return nil }
        // The barrel ramp is raised on one side to throw the car into a roll.
        let tilt = barrel ? max(0,(l-lane)*(lane>0 ? -1:1)/halfWidth)*0.35 : 0
        return height*(d/length)*(1+tilt)
    }
    func passed(progress p: Double, trackLength: Double) -> Bool {
        let d = ((p-floor(p))-progress)*trackLength
        return d > length && d < length+6
    }
}

/// Vertical state for a car: on the ground, climbing a ramp, or airborne.
struct AirState {
    var height = 0.0
    var velocity = 0.0
    var airborne = false
    var airTime = 0.0
    var roll = 0.0
    var rollRate = 0.0
    var ramp: Int? = nil

    enum Landing { case none, jump(airTime: Double, barrel: Bool) }

    mutating func update(dt: Double, progress: Double, lane: Double, speed: Double, ramps: [Ramp], trackLength: Double) -> Landing {
        if airborne {
            velocity -= 24*dt; height += velocity*dt; airTime += dt; roll += rollRate*dt
            if height <= 0 {
                let barrel = rollRate != 0
                height = 0; velocity = 0; airborne = false; roll = 0; rollRate = 0; ramp = nil
                let time = airTime; airTime = 0
                return .jump(airTime: time, barrel: barrel)
            }
            return .none
        }
        for (index,r) in ramps.enumerated() {
            if let h = r.surface(progress: progress, lane: lane, trackLength: trackLength) { height = h; ramp = index; return .none }
        }
        if let index = ramp {
            // Leaving a ramp: off the lip launches, off the side just drops.
            let r = ramps[index]
            airborne = true; airTime = 0
            if r.passed(progress: progress, trackLength: trackLength) {
                velocity = min(10.5, max(5.5, speed*0.17))
                if r.barrel {
                    let g = 24.0, flight = (velocity+sqrt(velocity*velocity+2*g*height))/g
                    rollRate = (r.lane>0 ? 1 : -1)*2 * .pi/max(0.55,flight)
                }
            } else { velocity = 0 }
            ramp = nil
        } else { height = 0 }
        return .none
    }
}

@MainActor enum RampArt {
    private static let chevrons: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { context in
        UIColor(hex: 0x15181D).setFill(); context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
        UIColor(hex: 0xFFD23F).setFill()
        for row in stride(from: -256, to: 256, by: 64) {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: row+128)); path.addLine(to: CGPoint(x: 128, y: row)); path.addLine(to: CGPoint(x: 256, y: row+128))
            path.addLine(to: CGPoint(x: 256, y: row+160)); path.addLine(to: CGPoint(x: 128, y: row+32)); path.addLine(to: CGPoint(x: 0, y: row+160)); path.close(); path.fill()
        }
    }
    /// A steel launch wedge with chevron deck, side lights and a lip edge.
    static func node(_ ramp: Ramp, circuit: Circuit) -> SCNNode {
        let root = SCNNode(); root.name = "launch-ramp"
        let w = Float(ramp.halfWidth*2), l = Float(ramp.length), h = Float(ramp.height)
        let rise: (Float) -> Float = { x in
            guard ramp.barrel else { return h }
            let edge:Float = ramp.lane>0 ? -1 : 1
            return h*(1+max(0,x*edge/(w/2))*0.35)
        }
        // Deck and sides as one closed wedge in local space: +Z is forward.
        let xs: [Float] = [-w/2, w/2]
        var v: [SCNVector3] = []
        for x in xs { v += [SCNVector3(x,0,0), SCNVector3(x,0,l), SCNVector3(x,rise(x),l)] }
        let deck = SCNGeometry(sources: [SCNGeometrySource(vertices: [v[0],v[3],v[5],v[2]]),
                                         SCNGeometrySource(textureCoordinates: [CGPoint(x:0,y:0),CGPoint(x:1,y:0),CGPoint(x:1,y:CGFloat(l/4)),CGPoint(x:0,y:CGFloat(l/4))])],
                               elements: [SCNGeometryElement(indices: [Int32(0),2,1,0,3,2], primitiveType: .triangles)])
        let deckMaterial = SCNMaterial(); deckMaterial.lightingModel = .physicallyBased; deckMaterial.diffuse.contents = chevrons
        deckMaterial.diffuse.wrapT = .repeat; deckMaterial.roughness.contents = 0.55; deckMaterial.metalness.contents = 0.35; deckMaterial.isDoubleSided = true
        deck.materials = [deckMaterial]; root.addChildNode(SCNNode(geometry: deck))
        let steel = material(0x5D6B74); steel.metalness.contents = 0.8; steel.roughness.contents = 0.35; steel.isDoubleSided = true
        let sides = SCNGeometry(sources: [SCNGeometrySource(vertices: v+[v[2],v[5],SCNVector3(xs[1],0,l),SCNVector3(xs[0],0,l)])],
                                elements: [SCNGeometryElement(indices: [Int32(0),1,2,3,5,4,6,7,8,6,8,9], primitiveType: .triangles)])
        sides.materials = [steel]; root.addChildNode(SCNNode(geometry: sides))
        let glow = material(ramp.barrel ? 0xFF5FD2 : 0x46E5FF, glow: true)
        for x in xs {
            let strip = SCNNode(geometry: SCNBox(width: 0.08, height: 0.08, length: CGFloat(l), chamferRadius: 0.02))
            strip.geometry?.materials = [glow]; strip.position = SCNVector3(x, rise(x)/2+0.05, l/2)
            strip.eulerAngles.x = -atan2(rise(x), l); root.addChildNode(strip)
        }
        let lip = SCNNode(geometry: SCNBox(width: CGFloat(w), height: 0.1, length: 0.12, chamferRadius: 0.03))
        lip.geometry?.materials = [glow]; lip.position = SCNVector3(0, (rise(-w/2)+rise(w/2))/2, l); root.addChildNode(lip)
        let start = circuit.point(ramp.progress, lane: ramp.lane)
        root.position = SCNVector3(start.x, 0.11, start.z); root.eulerAngles.y = circuit.heading(ramp.progress)
        return root
    }
}
