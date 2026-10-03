import SceneKit
import UIKit

/// Dense roadside ground cover and road detailing: alpha-cut grass and scrub
/// cards batched into a few culled chunks, red/white kerbs and tyre wear.
@MainActor enum GroundCover {
    /// Grass blade atlas generated once per palette: tapered, curved blades
    /// with a darker base, drawn with a fixed seed for repeatable art.
    private static func tuftImage(base: UIColor, tip: UIColor, blades: Int, seed: UInt32) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { ctx in
            let c = ctx.cgContext
            var s = seed
            func r() -> CGFloat { s = s &* 1664525 &+ 1013904223; return CGFloat(s >> 8) / CGFloat(1 << 24) }
            for _ in 0..<blades {
                let x = 30 + r()*196, h = 120 + r()*130, lean = (r()-0.5)*110, w = 4 + r()*6
                let path = UIBezierPath()
                path.move(to: CGPoint(x: x-w, y: 256))
                path.addQuadCurve(to: CGPoint(x: x+lean, y: 256-h), controlPoint: CGPoint(x: x-w*0.3+lean*0.2, y: 256-h*0.55))
                path.addQuadCurve(to: CGPoint(x: x+w, y: 256), controlPoint: CGPoint(x: x+w*0.3+lean*0.25, y: 256-h*0.5))
                path.close()
                c.saveGState(); path.addClip()
                let mix = r()*0.35
                let colors = [tip.withAlphaComponent(1).cgColor, base.cgColor] as CFArray
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
                c.setAlpha(0.88+mix*0.3)
                c.drawLinearGradient(g, start: CGPoint(x: x, y: 256-h), end: CGPoint(x: x, y: 256), options: [])
                c.restoreGState()
            }
        }
    }
    private static var materials: [Int: SCNMaterial] = [:]
    private static func cardMaterial(_ environment: Int, snow: Bool) -> SCNMaterial {
        let key = environment*2+(snow ? 1:0)
        if let m = materials[key] { return m }
        let image: UIImage
        switch (environment, snow) {
        case (2, _): image = tuftImage(base: UIColor(hex: 0x6B4A2A), tip: UIColor(hex: 0xD9B66A), blades: 46, seed: 11)
        case (_, true): image = tuftImage(base: UIColor(hex: 0x2E3A2C), tip: UIColor(hex: 0xA9B48C), blades: 38, seed: 23)
        default: image = tuftImage(base: UIColor(hex: 0x24401C), tip: UIColor(hex: 0x9CC25A), blades: 60, seed: 5)
        }
        let m = SCNMaterial(); m.lightingModel = .physicallyBased; m.diffuse.contents = image
        m.roughness.contents = 0.85; m.metalness.contents = 0; m.isDoubleSided = true
        m.diffuse.mipFilter = .linear; m.diffuse.wrapS = .clamp; m.diffuse.wrapT = .clamp
        GLBAsset.configureCutout(m, cutoff: 0.45)
        materials[key] = m; return m
    }

    /// Crossed-card tufts placed in bands beside the road, split into chunks
    /// along the lap so SceneKit can frustum-cull most of them.
    static func tufts(_ circuit: Circuit, ground: (SIMD3<Float>) -> Float) -> SCNNode {
        let root = SCNNode(); root.name = "ground-cover"
        guard circuit.environment != 1 else { return root }
        let snow = circuit.look.ground == "snow"
        let material = cardMaterial(circuit.environment, snow: snow)
        let road = (0..<480).map { circuit.point(Double($0)/480) }
        let chunks = 16, perChunk = circuit.environment == 2 ? 80 : 200
        var seed: UInt32 = UInt32(circuit.id*977+13)
        func r() -> Float { seed = seed &* 1664525 &+ 1013904223; return Float(seed >> 8) / Float(1 << 24) }
        for chunk in 0..<chunks {
            var v: [SCNVector3] = [], n: [SCNVector3] = [], uv: [CGPoint] = [], idx: [Int32] = []
            for _ in 0..<perChunk {
                let t = (Double(chunk)+Double(r()))/Double(chunks)
                let side: Double = r() < 0.5 ? -1 : 1
                // Densest just beyond the kerb, thinning out with distance.
                let offset = 12.4 + Double(pow(r(), 1.8))*30
                let p = circuit.point(t, lane: side*offset)
                if circuit.environment == 0 && p.x < -150 { continue }
                guard RouteScenery.allowsScenery(p, radius: 0.8, circuit: circuit) else { continue }
                let nearest = road.reduce(Float.greatestFiniteMagnitude) { min($0, hypot($1.x-p.x, $1.z-p.z)) }
                guard nearest > 11.6 else { continue }
                let h = (0.45 + r()*0.75) * (circuit.environment == 2 ? 0.8 : 1), w = h*1.5
                let y = ground(p)
                let yaw = r() * .pi
                for k in 0..<2 {
                    let a = yaw + Float(k) * .pi/2
                    let dx = cos(a)*w/2, dz = sin(a)*w/2
                    let base = Int32(v.count)
                    v += [SCNVector3(p.x-dx, y, p.z-dz), SCNVector3(p.x+dx, y, p.z+dz), SCNVector3(p.x+dx, y+h, p.z+dz), SCNVector3(p.x-dx, y+h, p.z-dz)]
                    // Upward-tilted normals light the cards like the ground beneath.
                    let up = SCNVector3(0, 1, 0); n += [up, up, up, up]
                    uv += [CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 0)]
                    idx += [base, base+1, base+2, base, base+2, base+3]
                }
            }
            guard !v.isEmpty else { continue }
            let g = SCNGeometry(sources: [SCNGeometrySource(vertices: v), SCNGeometrySource(normals: n), SCNGeometrySource(textureCoordinates: uv)],
                                elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
            g.materials = [material]
            let node = SCNNode(geometry: g); node.castsShadow = false; node.name = "ground-cover-chunk"
            root.addChildNode(node)
        }
        return root
    }

    /// Red and white kerb blocks, two metres per colour along the lap.
    static let kerb: SCNMaterial = {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 128)).image { ctx in
            UIColor(hex: 0xD8262E).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            UIColor(hex: 0xF2F0EA).setFill(); ctx.fill(CGRect(x: 0, y: 64, width: 64, height: 64))
            UIColor(white: 0, alpha: 0.18).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 6, height: 128))
        }
        let m = SCNMaterial(); m.lightingModel = .physicallyBased; m.diffuse.contents = image
        m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat; m.diffuse.contentsTransform = SCNMatrix4MakeScale(1, 0.5, 1)
        m.roughness.contents = 0.55; m.metalness.contents = 0; return m
    }()

    /// Darker tyre lines and oil staining along each lane, applied through the
    /// asphalt's multiply channel so the base texture keeps its grain.
    static let wear: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512)).image { ctx in
        UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
        let c = ctx.cgContext
        // Road U spans 0…3.6 (18 m); lanes centre on −6, 0 and 6 m.
        func x(_ lane: CGFloat) -> CGFloat { (lane+9)/18*512 }
        for centre: CGFloat in [-6, 0, 6] { for track: CGFloat in [-0.85, 0.85] {
            let cx = x(centre+track)
            for i in 0..<6 {
                let w = CGFloat(18-i*3)
                UIColor(white: 0.72+CGFloat(i)*0.045, alpha: 0.35).setFill()
                c.fill(CGRect(x: cx-w/2, y: 0, width: w, height: 512))
            }
        }}
        var s: UInt32 = 3
        func r() -> CGFloat { s = s &* 1664525 &+ 1013904223; return CGFloat(s >> 8) / CGFloat(1 << 24) }
        for _ in 0..<26 {
            let lane = [-6, 0, 6][Int(r()*3)] as CGFloat
            let rect = CGRect(x: x(lane)-20+r()*40, y: r()*512, width: 14+r()*30, height: 30+r()*90)
            UIColor(white: 0.62, alpha: 0.25).setFill(); c.fillEllipse(in: rect)
        }
    }
}
