import SceneKit
import UIKit

/// Small, grounded trackside assemblies establish human scale and depth.
/// Each cluster is culled separately and reserves its complete road clearance.
@MainActor enum TracksideArt {
    static func dress(_ circuit:Circuit) -> SCNNode {
        let root=SCNNode(),road=(0..<480).map {circuit.point(Double($0)/480)}
        let stone=SurfaceLibrary.surface("stucco",tint:UIColor(hex:0xBEB7A5))
        let steel=material(0x24343C),yellow=material(0xEBC52D),blue=material(0x087A9E)
        let timber=SurfaceLibrary.surface("bark",tint:UIColor(hex:0xA89272))
        func clear(_ p:SIMD3<Float>,_ radius:Float)->Bool {
            (circuit.environment != 0 || p.x-radius > -153) && RouteScenery.allowsScenery(p,radius:radius,circuit:circuit) && road.allSatisfy {hypot($0.x-p.x,$0.z-p.z)>14+radius}
        }
        func box(_ root:SCNNode,_ size:SCNVector3,_ position:SCNVector3,_ m:SCNMaterial) {
            let g=SCNBox(width:CGFloat(size.x),height:CGFloat(size.y),length:CGFloat(size.z),chamferRadius:0.02);g.materials=[m]
            let n=SCNNode(geometry:g);n.position=position;root.addChildNode(n)
        }
        func ground(_ p:SIMD3<Float>)->Float {
            guard circuit.environment>=2 else{return -0.03}
            let nearest=road.map {hypot($0.x-p.x,$0.z-p.z)}.min() ?? 0
            let relief=max(0,min(1,(nearest-19)/65))*RouteScenery.terrainRelief(p.x,p.z,circuit:circuit)
            return -0.04+relief*(1.8+sin(p.x*0.03)*cos(p.z*0.025)*1.7)
        }
        // Paired landscaping beds and benches frame the coast and city streets.
        if circuit.environment<2 {
            for i in 0..<40 {
                let t=Double(i)/40+0.017,side:Double=i%2==0 ? -1:1
                let p=circuit.point(t,lane:side*21)
                guard clear(p,5.5) else{continue}
                let cluster=SCNNode()
                box(cluster,SCNVector3(3.6,0.38,7.5),SCNVector3(0,0.1,0),stone)
                box(cluster,SCNVector3(3.3,0.12,7.1),SCNVector3(0,0.32,0),material(0x393D26))
                for z:Float in [-2.2,0,2.2] {
                    if let shrub=SceneDressing.asset("CoastalShrub",height:1.3,maxWidth:3) {shrub.position=SCNVector3(0,0.35,z);cluster.addChildNode(shrub)}
                }
                if i%4==0, let tree=SceneDressing.asset("island_tree_01",height:6,maxWidth:5) {tree.position=SCNVector3(0,0.4,0);cluster.addChildNode(tree)}
                if i%3==0 {
                    for z:Float in [-0.5,-0.15,0.2] {box(cluster,SCNVector3(2.2,0.09,0.24),SCNVector3(3,0.65,z),timber)}
                    for x:Float in [2.15,3.85] {box(cluster,SCNVector3(0.10,0.6,0.85),SCNVector3(x,0.3,-0.15),steel)}
                    box(cluster,SCNVector3(2.25,0.45,0.12),SCNVector3(3,1.0,-0.62),timber)
                }
                let bounds=cluster.boundingBox
                let batch=cluster.flattenedClone();batch.boundingBox=bounds;batch.name="trackside-garden";batch.eulerAngles.y=circuit.heading(t);batch.position=SCNVector3(p.x,ground(p),p.z);root.addChildNode(batch)
            }
        }
        // Forest stands sit at several depths, rather than one evenly spaced row.
        if circuit.environment==3 {
            for i in 0..<26 {
                let t=Double(i)/26+0.041,side:Double=i%2==0 ? -1:1
                let p=circuit.point(t,lane:side*(30+Double(i%3)*10))
                guard clear(p,9) else{continue}
                let cluster=SCNNode()
                for j in 0..<3 {
                    if let tree=SceneDressing.asset("AlpineFir",height:10+Float((i+j)%5)*1.2,maxWidth:6) {
                        let x=Float(j-1)*4.5,z=Float((i+j)%3-1)*2.8
                        tree.position=SCNVector3(x,ground(p+SIMD3(x,0,z))-ground(p)-0.2,z);tree.eulerAngles.y=Float(i+j)*2.4
                        cluster.addChildNode(tree)
                    }
                }
                let bounds=cluster.boundingBox
                let batch=cluster.flattenedClone();batch.boundingBox=bounds;batch.name="trackside-forest";batch.position=SCNVector3(p.x,ground(p),p.z);root.addChildNode(batch)
            }
        }
        // Painted festival furniture gives technical turns a readable race identity.
        for i in 0..<24 {
            let t=Double(i)/24+0.008,side:Double=i%2==0 ? -1:1
            let p=circuit.point(t,lane:side*16.8)
            guard clear(p,2.4) else{continue}
            let cluster=SCNNode()
            if circuit.environment<2 || i%3==0 {
                box(cluster,SCNVector3(0.09,5.2,0.09),SCNVector3(0,2.6,0),steel)
                box(cluster,SCNVector3(1.15,3.3,0.06),SCNVector3(0.55,3.45,0),i%2==0 ? yellow:blue)
                box(cluster,SCNVector3(1.17,0.16,0.07),SCNVector3(0.55,2.35,0.01),steel)
                box(cluster,SCNVector3(0.7,0.7,0.1),SCNVector3(0.55,4.2,0.01),material(0xE8E8DC))
            } else {
                box(cluster,SCNVector3(3.2,0.8,0.7),SCNVector3(0,0.4,0),stone)
                for x:Float in [-1,0,1] {box(cluster,SCNVector3(0.4,0.63,0.04),SCNVector3(x,0.43,0.38),yellow)}
            }
            let bounds=cluster.boundingBox
                let batch=cluster.flattenedClone();batch.boundingBox=bounds;batch.name="trackside-marker";batch.position=SCNVector3(p.x,ground(p),p.z);batch.eulerAngles.y=circuit.heading(t) + .pi/2;root.addChildNode(batch)
        }
        return root
    }
}
