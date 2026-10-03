import SceneKit
import UIKit

/// Art settings are per circuit, independent of campaign district and road shape.
struct RouteLook {
    let setting: String
    let ground: String
    let landmark: Landmark
    let vegetation: Int // 0 sparse, 1 palms, 2 broadleaf, 3 conifers
    let density: Int
    let sun: UInt32
    let fog: UInt32
    let exposure: CGFloat
    enum Landmark: CaseIterable { case resort, neonPlaza, arch, chalet, beachClub, marina, grandstand, lighthouse, port, oldTown, financial, silos, windFarm, quarry, station, observatory, dam, skiLift, viaduct, radar }
    static let all: [RouteLook] = [
        .init(setting:"PALM RESORT",ground:"grass",landmark:.resort,vegetation:1,density:1,sun:0xFFE0AF,fog:0xC1C8C4,exposure:0),
        .init(setting:"NEON WATERFRONT",ground:"asphalt",landmark:.neonPlaza,vegetation:0,density:1,sun:0xA5BCD9,fog:0x192C43,exposure:0.05),
        .init(setting:"SANDSTONE ARCHES",ground:"sand",landmark:.arch,vegetation:0,density:2,sun:0xFFD09A,fog:0xB49A80,exposure:0),
        .init(setting:"FOREST LODGE",ground:"grass",landmark:.chalet,vegetation:3,density:1,sun:0xCFDEEE,fog:0xAABAC5,exposure:0.05),
        .init(setting:"BEACH CLUB",ground:"sand",landmark:.beachClub,vegetation:1,density:2,sun:0xFFF1D5,fog:0xBAD8DF,exposure:0.18),
        .init(setting:"SAILING MARINA",ground:"grass",landmark:.marina,vegetation:1,density:3,sun:0xFFDEA4,fog:0xB7CAD4,exposure:0.1),
        .init(setting:"FESTIVAL PADDOCK",ground:"grass",landmark:.grandstand,vegetation:2,density:2,sun:0xFFF1D9,fog:0xC4D0D6,exposure:0.12),
        .init(setting:"LIGHTHOUSE HEADLAND",ground:"rock",landmark:.lighthouse,vegetation:1,density:4,sun:0xFFB479,fog:0xBE9890,exposure:-0.1),
        .init(setting:"CONTAINER TERMINAL",ground:"asphalt",landmark:.port,vegetation:0,density:4,sun:0xAEC5D8,fog:0x263847,exposure:0.05),
        .init(setting:"HISTORIC QUARTER",ground:"stucco",landmark:.oldTown,vegetation:2,density:3,sun:0xFFD3A0,fog:0x483E46,exposure:0.05),
        .init(setting:"FINANCIAL DISTRICT",ground:"asphalt",landmark:.financial,vegetation:2,density:1,sun:0xB7D8F1,fog:0x26334F,exposure:0.1),
        .init(setting:"INDUSTRIAL WORKS",ground:"asphalt",landmark:.silos,vegetation:0,density:4,sun:0xFFB878,fog:0x39343C,exposure:0),
        .init(setting:"WIND FARM",ground:"sand",landmark:.windFarm,vegetation:0,density:4,sun:0xFFF2C9,fog:0xC6B593,exposure:0.2),
        .init(setting:"TERRACED QUARRY",ground:"rock",landmark:.quarry,vegetation:0,density:1,sun:0xFFE0AF,fog:0xA99B8B,exposure:0),
        .init(setting:"DESERT WAYSTATION",ground:"sand",landmark:.station,vegetation:0,density:3,sun:0xFFBA7A,fog:0xB69584,exposure:-0.05),
        .init(setting:"RIDGE OBSERVATORY",ground:"rock",landmark:.observatory,vegetation:0,density:2,sun:0xDFCAFF,fog:0x8E8AAB,exposure:-0.15),
        .init(setting:"HYDRO RESERVOIR",ground:"rock",landmark:.dam,vegetation:3,density:3,sun:0xD3E7F1,fog:0xA6BEC9,exposure:0.12),
        .init(setting:"SKI VILLAGE",ground:"snow",landmark:.skiLift,vegetation:3,density:1,sun:0xE7EDFF,fog:0xBBCAD8,exposure:0.15),
        .init(setting:"MOUNTAIN VIADUCT",ground:"rock",landmark:.viaduct,vegetation:3,density:2,sun:0xFFF0C7,fog:0xB8C2C2,exposure:0.08),
        .init(setting:"SUMMIT STATION",ground:"snow",landmark:.radar,vegetation:3,density:4,sun:0xFFCCE2,fog:0x9CABC9,exposure:-0.1)
    ]
}
extension Circuit { var look: RouteLook { RouteLook.all[id] } }

@MainActor enum RouteScenery {
    private static var cached:[Int:SCNNode]=[:]
    private static var footprints:[Int:[(SIMD3<Float>,Float)]]=[:]
    static func allowsScenery(_ point:SIMD3<Float>,radius:Float,circuit:Circuit) -> Bool {
        (footprints[circuit.id] ?? []).allSatisfy {hypot($0.0.x-point.x,$0.0.z-point.z)>$0.1+radius+3}
    }
    static func terrainRelief(_ x:Float,_ z:Float,circuit:Circuit) -> Float {
        (footprints[circuit.id] ?? []).reduce(Float(1)) {min($0,max(0,min(1,(hypot($1.0.x-x,$1.0.z-z)-$1.1-3)/12)))}
    }
    static func ground(_ circuit:Circuit) -> SCNMaterial {
        if circuit.look.ground=="snow" {
            let m=material(0xA3B4C3);m.normal.contents=SurfaceLibrary.image("sand-normal");m.normal.intensity=0.2;m.roughness.contents=0.94
            m.normal.wrapS = .repeat;m.normal.wrapT = .repeat;return m
        }
        // Badlands ground takes a warm red-ochre cast so canyon routes read as desert.
        if circuit.environment==2 {return SurfaceLibrary.surface(circuit.look.ground,tint:UIColor(hex:circuit.look.ground=="rock" ? 0xD49066 : 0xEBB98A))}
        return SurfaceLibrary.surface(circuit.look.ground)
    }
    static func landmarks(_ circuit:Circuit) -> SCNNode {
        if let cached=cached[circuit.id] {return cached.clone()}
        let root=SCNNode()
        footprints[circuit.id]=[]
        // Full bounds are checked against the entire route, including distant bends.
        // Never solve a placement failure by moving props into the road corridor.
        for (index,t) in [0.08,0.39,0.71].enumerated() {
            let node=landmark(circuit.look.landmark,variant:index)
            node.eulerAngles.y=circuit.heading(t)
            let b=node.boundingBox
            var radius:Float=0
            for x in [b.min.x,b.max.x] {for z in [b.min.z,b.max.z] {
                let p=node.convertPosition(SCNVector3(x,0,z),to:nil);radius=max(radius,hypot(p.x,p.z))
            }}
            var placed=false
            for side in [-1.0,1.0] where !placed {
                for offset in stride(from:Double(radius)+22,through:Double(radius)+180,by:8) {
                    let p=circuit.point(t,lane:side*offset)
                    if circuit.environment==0 && p.x-radius < -152 {continue}
                    let clear=(0..<480).allSatisfy {i in let road=circuit.point(Double(i)/480);return hypot(road.x-p.x,road.z-p.z)>radius+15}
                    if clear {node.eulerAngles.y=circuit.heading(t)-Float(side)*Float.pi/2;node.position=SCNVector3(p.x,-0.08,p.z);node.name="route-landmark";root.addChildNode(node);footprints[circuit.id,default:[]].append((p,radius));placed=true;break}
                }
            }
        }
        cached[circuit.id]=root
        return root.clone()
    }
    private static func landmark(_ type:RouteLook.Landmark,variant:Int) -> SCNNode {
        let root=SCNNode()
        let stone=SurfaceLibrary.surface("stucco"),rock=SurfaceLibrary.surface("rock"),steel=material(0x344C5B),white=material(0xDAE1DF),timber=SurfaceLibrary.surface("bark"),glass=material(0x21485A)
        steel.metalness.contents=0.65;steel.roughness.contents=0.38;glass.metalness.contents=0.6;glass.roughness.contents=0.2
        let orange=material(0xD96A31),blue=material(0x187B91),gold=material(0xEFC358)
        @discardableResult func box(_ x:Float,_ y:Float,_ z:Float,_ w:CGFloat,_ h:CGFloat,_ d:CGFloat,_ m:SCNMaterial) -> SCNNode {
            let g=SCNBox(width:w,height:h,length:d,chamferRadius:0.06);g.materials=[m];let n=SCNNode(geometry:g);n.position=SCNVector3(x,y,z);root.addChildNode(n);return n
        }
        @discardableResult func cylinder(_ x:Float,_ y:Float,_ z:Float,_ r:CGFloat,_ h:CGFloat,_ m:SCNMaterial) -> SCNNode {
            let g=SCNCylinder(radius:r,height:h);g.radialSegmentCount=24;g.materials=[m];let n=SCNNode(geometry:g);n.position=SCNVector3(x,y,z);root.addChildNode(n);return n
        }
        func sphere(_ x:Float,_ y:Float,_ z:Float,_ r:CGFloat,_ m:SCNMaterial) {let g=SCNSphere(radius:r);g.segmentCount=32;g.materials=[m];let n=SCNNode(geometry:g);n.position=SCNVector3(x,y,z);root.addChildNode(n)}
        func beam(_ a:SCNVector3,_ b:SCNVector3,_ width:CGFloat,_ m:SCNMaterial) {
            let d=simd_length(SIMD3<Float>(b.x-a.x,b.y-a.y,b.z-a.z));let g=SCNCylinder(radius:width,height:CGFloat(d));g.radialSegmentCount=8;g.materials=[m]
            let n=SCNNode(geometry:g);n.position=SCNVector3((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2);n.look(at:b,up:SCNVector3(0,0,1),localFront:SCNVector3(0,1,0));root.addChildNode(n)
        }
        func sign(_ title:String,_ x:Float,_ y:Float,_ z:Float,_ color:UInt32=0xE5ECE9) {
            let g=SCNText(string:title,extrusionDepth:0.025);g.font=UIFont.systemFont(ofSize:1,weight:.bold);g.flatness=0.12;g.materials=[material(color,glow:true)]
            let n=SCNNode(geometry:g);n.scale=SCNVector3(0.65,0.65,0.65);n.position=SCNVector3(x,y,z);root.addChildNode(n)
        }
        func cabin(_ x:Float,_ z:Float,_ snow:Bool=false) {
            box(x,2.7,z,10,5.4,8,timber)
            let roof=ArchitectureArt.pitchedRoof(width:11.2,depth:10,rise:2.8,wall:timber,cover:snow ? white:SurfaceLibrary.surface("terracotta"))
            roof.position=SCNVector3(x,5.4,z);root.addChildNode(roof)
            // Timber fascia and ridge sit directly on the filled gable.
            for side:Float in [-1,1] {box(x+side*5.4,5.4,z,0.18,0.3,10,timber)}
            box(x+2.9,7.4,z-1.8,0.85,3.3,0.85,stone);box(x+2.9,9.1,z-1.8,1.15,0.18,1.15,steel)
            for dx:Float in [-3,0,3] {box(x+dx,3,z+4.05,1.8,2.2,0.1,glass);box(x+dx,1.8,z+4.14,2,0.18,0.3,white)}
            box(x,0.2,z,11,0.4,9,stone)
        }
        func container(_ x:Float,_ y:Float,_ z:Float,_ m:SCNMaterial) {
            box(x,y+1.3,z,8,2.6,3,m)
            for i in -9...9 {box(x+Float(i)*0.4,y+1.3,z+1.54,0.05,2.45,0.07,steel)}
            for dx:Float in [-3.9,3.9] {box(x+dx,y+1.3,z,0.1,2.7,3.1,steel)}
        }
        switch type {
        case .resort:
            box(0,0.1,0,32,0.4,21,stone)
            for x:Float in [-10,0,10] {
                box(x,6,-2,9,12,10,stone);box(x,12.1,-2,10,0.35,11,white)
                for y:Float in [2,5.5,9] {box(x,y,3.1,7.5,2.2,0.1,glass);box(x,y-1.2,4,8.5,0.25,2,white)}
            }
            sign("PALM / RESORT",-6,13,3.6)
        case .beachClub:
            box(0,2,0,20,4,8,stone);box(0,4.2,0,23,0.35,11,white);box(0,2,4.1,17,2.8,0.1,glass)
            for x:Float in [-12,-6,0,6,12] {
                cylinder(x,1.8,9,0.09,3.6,timber)
                let g=SCNCone(topRadius:0,bottomRadius:2.3,height:1);g.radialSegmentCount=16;g.materials=[x==0 ? blue:white];let n=SCNNode(geometry:g);n.position=SCNVector3(x,3.8,9);root.addChildNode(n)
                box(x,0.45,10.5,1.4,0.25,2.6,white)
            }
            sign("AZURE / BEACH CLUB",-7,4.7,4.6)
        case .marina:
            box(0,-0.02,0,34,0.15,30,material(0x287B98))
            box(0,0.2,0,3,0.5,31,timber)
            for z:Float in [-10,0,10] {
                box(0,0.2,z,28,0.5,1.6,timber)
                for x:Float in [-9,9] {
                    let hull=box(x,0.6,z+4,3,1.3,8,white);hull.geometry=SCNCapsule(capRadius:1.4,height:8);hull.geometry?.materials=[white];hull.eulerAngles.x = .pi/2;hull.scale=SCNVector3(1,1,0.5)
                    box(x,1.4,z+3,1.9,1.1,3,white);cylinder(x,7,z+3,0.07,12,steel)
                    beam(SCNVector3(x,12,z+3),SCNVector3(x,1,z+7),0.018,white)
                }
            }
        case .grandstand:
            for tier in 0..<6 {let y=Float(tier)*0.85;box(0,y+0.45,Float(tier)*1.4,32,0.8,1.5,stone)
                for seat in -13...13 {box(Float(seat),y+0.96,Float(tier)*1.4,0.7,0.2,0.8,tier%2==0 ? blue:white)}
            }
            for x:Float in [-15,-5,5,15] {box(x,5,8,0.25,10,0.25,steel)}
            box(0,10,4,34,0.4,11,white);sign("RIVIERA / GRAND PRIX",-8,7.3,8.3,0xFFD52A)
        case .lighthouse:
            cylinder(0,0.5,0,8,1.2,rock)
            let g=SCNCone(topRadius:2.0,bottomRadius:3.3,height:24);g.radialSegmentCount=32;g.materials=[white];let n=SCNNode(geometry:g);n.position.y=13;root.addChildNode(n)
            cylinder(0,15,0,2.7,3,orange);cylinder(0,25.3,0,3.8,0.6,steel);cylinder(0,27,0,2.1,3,glass);cylinder(0,28.6,0,2.7,0.5,steel)
            for i in 0..<12 {let a=Float(i)*2 * .pi/12;cylinder(sin(a)*3.4,26.1,cos(a)*3.4,0.05,1.3,steel)}
            sphere(0,27,0,0.55,material(0xFFF0BE,glow:true));box(7,2.4,0,7,4.8,7,stone)
        case .neonPlaza:
            box(0,0.1,0,30,0.4,22,stone)
            for x:Float in [-10,10] {box(x,10,0,4,20,4,steel);box(x,10,2.1,2.5,18,0.12,material(x<0 ? 0x51DAD1:0xE365AF,glow:true))}
            for i in 0..<5 {let n=box(0,Float(i)*2.4+4,0,13,0.2,3,white);n.eulerAngles.y=Float(i)*0.2}
            sign("AFTERLIGHT / HARBOR",-7,1.5,6,0x69E8E1)
        case .port:
            for row in 0..<3 {for col in 0..<3 {container(Float(col-1)*8.5,Float(row%2)*2.6,Float(row-1)*6,[orange,blue,steel][(row+col)%3])}}
            for x:Float in [-12,12] {box(x,13,-7,1,26,1,gold)}
            box(0,26,-7,29,1.3,1.5,gold);box(0,26,2,1.2,1.5,26,gold)
            for z:Float in [-8,0,8] {beam(SCNVector3(0,26,z),SCNVector3(0,8,z),0.04,steel)}
            box(0,8,0,7,0.5,3,gold)
        case .oldTown:
            for x:Float in [-11,11] {box(x,6,0,8,12,11,stone);box(x,12,0,9,0.45,12,orange)
                for y:Float in [3,7,10] {for dx:Float in [-2,2] {box(x+dx,y,5.6,1.4,2,0.1,glass);box(x+dx,y-1.2,6,2,0.2,1,white)}}}
            cylinder(0,0.4,0,5,0.8,stone);cylinder(0,1,0,3.8,0.3,blue);cylinder(0,2.4,0,0.5,3,white);sphere(0,4.2,0,1,white)
        case .financial:
            for (x,h) in [(-12.0,40.0),(0.0,55.0),(12.0,33.0)] {
                box(Float(x),Float(h/2),0,10,CGFloat(h),12,glass)
                for y in stride(from:0.0,through:h,by:3) {box(Float(x),Float(y),0,10.2,0.12,12.2,steel)}
                for dx:Float in [-4,-2,0,2,4] {box(Float(x)+dx,Float(h/2),6.1,0.12,CGFloat(h),0.1,white)}
            }
        case .silos:
            for x:Float in [-9,0,9] {cylinder(x,9,0,3.8,18,white);cylinder(x,18.2,0,4,0.4,steel);box(x,18.7,0,1,0.15,8,steel)
                for y in stride(from:Float(1),through:18,by:0.65) {box(x, y,4,0.9,0.07,0.12,steel)}
            }
            box(0,15,-5,25,0.4,2,steel);box(0,0,0,30,0.2,14,stone)
        case .arch:
            var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uv:[CGPoint]=[],indices:[Int32]=[]
            let segments=40,sides=12
            for ring in 0...segments {let a=Float(ring)/Float(segments) * .pi
                for side in 0...sides {let b=Float(side)/Float(sides)*2 * .pi
                    let thickness:Float=3.1*(1+0.14*sin(a*9+b*3)+0.08*cos(b*5+a*6))
                    vertices.append(SCNVector3(cos(a)*(14+cos(b)*thickness),3+sin(a)*(17+cos(b)*thickness),sin(b)*thickness))
                    normals.append(SCNVector3(cos(a)*cos(b),sin(a)*cos(b),sin(b)))
                    uv.append(CGPoint(x:Double(ring)/Double(segments)*12,y:Double(side)/Double(sides)*3))
                }
            }
            for ring in 0..<segments {for side in 0..<sides {let a=Int32(ring*(sides+1)+side),b=a+1,c=a+Int32(sides+1);indices += [a,b,c,b,c+1,c]}}
            let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
            let sandstone=SurfaceLibrary.surface("rock",tint:UIColor(hex:0xCFAD89));sandstone.isDoubleSided=true;g.materials=[sandstone];root.addChildNode(SCNNode(geometry:g))
            for side:Float in [-1,1] {let pedestal=SurfaceLibrary.rock(radius:5,height:7,seed:variant+Int(side)+7,desert:true);pedestal.position=SCNVector3(side*14,3,0);root.addChildNode(pedestal)}
        case .windFarm:
            for x:Float in [-17,0,17] {
                let h:Float=x==0 ? 33:26;cylinder(x,h/2,0,0.55,CGFloat(h),white);box(x,h,0,1.8,1.5,3.5,white);sphere(x,h,2,0.8,white)
                for blade in 0..<3 {let a=Float(blade)*2 * .pi/3+Float(variant)*0.4;beam(SCNVector3(x+sin(a),h+cos(a),2),SCNVector3(x+sin(a)*12,h+cos(a)*12,2),0.22,white)}
            }
        case .quarry:
            for tier in 0..<4 {box(0,Float(tier)*3+1.5,-Float(tier)*3,CGFloat(40-tier*6),3,CGFloat(22-tier*3),rock)}
            for x:Float in [-12,12] {box(x,2,12,4,4,3,gold);cylinder(x,0.8,12,1.4,3,steel).eulerAngles.z = .pi/2}
            beam(SCNVector3(-12,4,12),SCNVector3(10,14,0),0.45,steel)
        case .station:
            box(0,2,0,18,4,7,stone);box(0,4.3,4,24,0.5,15,orange)
            for x:Float in [-10,10] {box(x,2.1,10,0.25,4.2,0.25,steel)}
            for x:Float in [-5,0,5] {box(x,1.3,7,1,2.6,0.65,white);box(x,1.7,7.35,0.7,0.7,0.06,glass)}
            sign("DUST / SERVICE",-6,4.8,4,0xFFD77B)
            cylinder(13,6,0,1.5,12,steel);cylinder(13,12,0,3,3,orange)
        case .observatory:
            cylinder(0,3.5,0,8,7,stone);sphere(0,7,0,8,white);box(0,9,6.5,1.2,9,0.25,steel)
            for x:Float in [-13,13] {box(x,1,0,7,2,9,stone);let panel=box(x,3.1,0,6,0.16,8,glass);panel.eulerAngles.x = -0.3}
        case .chalet:
            cabin(-8,0);cabin(8,-5);box(0,0.15,7,32,0.3,6,stone)
            for x:Float in [-15,15] {cylinder(x,3,7,0.12,6,steel);sphere(x,6,7,0.35,material(0xFFE7B2,glow:true))}
        case .dam:
            box(0,6,0,42,12,6,stone);box(0,12.3,0,44,0.6,8,white)
            for x:Float in [-18,-12,-6,0,6,12,18] {box(x,6,3.5,1.3,12,1.6,stone);box(x,12.9,3.8,0.12,1.2,0.12,steel)}
            box(0,11,-16,42,0.2,26,material(0x357E92));box(0,1,8,26,0.15,10,material(0x3C8493))
        case .skiLift:
            cabin(-12,0,true);cabin(12,0,true)
            for x:Float in [-15,15] {cylinder(x,7,8,0.35,14,steel);box(x,14,8,5,0.4,0.4,orange)}
            for z:Float in [6,10] {beam(SCNVector3(-17,14,z),SCNVector3(17,14,z),0.035,steel)}
            for x:Float in [-10,0,10] {beam(SCNVector3(x,14,6),SCNVector3(x,11,6),0.06,steel);box(x,11,6,2.2,2.4,1.6,orange);box(x,11.3,6.85,1.8,1.2,0.04,glass)}
        case .viaduct:
            box(0,15,0,48,1.2,8,stone)
            for x:Float in [-20,-10,0,10,20] {box(x,7.5,0,2,15,5,stone);box(x,14,0,5,1.2,6,stone)}
            for z:Float in [-4,4] {box(0,16,z,48,0.8,0.15,steel)}
        case .radar:
            box(0,3,0,15,6,12,stone);sphere(0,10,0,6,white);cylinder(12,13,0,0.25,26,steel)
            for y:Float in [10,16,22] {box(12,y,0,4,0.12,0.12,orange)}
            sign("SUMMIT / 2840 M",-6,3.5,6.2,0xCBE7FA)
        }
        // A shallow, sealed platform seats each complex on the terrain.
        let bounds=root.boundingBox
        box((bounds.min.x+bounds.max.x)/2,-0.4,(bounds.min.z+bounds.max.z)/2,CGFloat(bounds.max.x-bounds.min.x)+1,1,CGFloat(bounds.max.z-bounds.min.z)+1,stone)
        return root
    }
}
