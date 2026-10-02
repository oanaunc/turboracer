import SceneKit
import UIKit

@MainActor enum ArchitectureArt {
    /// A closed triangular prism: both gables and the underside are real faces.
    /// The roof rests on the wall plate; no rotated/intersecting slabs or air gap.
    static func pitchedRoof(width:Float,depth:Float,rise:Float,wall:SCNMaterial,cover:SCNMaterial) -> SCNNode {
        let x=width/2,z=depth/2
        let a=SIMD3<Float>(-x,0,-z),b=SIMD3<Float>(x,0,-z),c=SIMD3<Float>(0,rise,-z)
        let d=SIMD3<Float>(-x,0,z),e=SIMD3<Float>(x,0,z),f=SIMD3<Float>(0,rise,z)
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uv:[CGPoint]=[]
        var roofIndices:[Int32]=[],wallIndices:[Int32]=[]
        func tri(_ p:SIMD3<Float>,_ q:SIMD3<Float>,_ r:SIMD3<Float>,roof:Bool) {
            let start=Int32(vertices.count),n=simd_normalize(simd_cross(q-p,r-p))
            for v in [p,q,r] {
                vertices.append(vector(v));normals.append(vector(n))
                // Tile courses run along the ridge, with metre-correct slope length.
                uv.append(roof ? CGPoint(x:Double(v.z)/2.5,y:Double(hypot(v.x,v.y-rise))/2.5):CGPoint(x:Double(v.x)/3,y:Double(v.y)/3))
            }
            if roof {roofIndices += [start,start+1,start+2]}else{wallIndices += [start,start+1,start+2]}
        }
        tri(a,d,f,roof:true);tri(a,f,c,roof:true)
        tri(c,f,e,roof:true);tri(c,e,b,roof:true)
        tri(a,c,b,roof:false);tri(d,e,f,roof:false)
        tri(a,b,e,roof:false);tri(a,e,d,roof:false)
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:roofIndices,primitiveType:.triangles),SCNGeometryElement(indices:wallIndices,primitiveType:.triangles)])
        g.materials=[cover,wall];let root=SCNNode(geometry:g);root.name="closed-pitched-roof"
        let ridge=SCNCylinder(radius:0.14,height:CGFloat(depth+0.12));ridge.radialSegmentCount=8;ridge.materials=[cover]
        let cap=SCNNode(geometry:ridge);cap.position.y=rise;cap.eulerAngles.x = .pi/2;root.addChildNode(cap)
        return root
    }

    private static var villas:[Int:SCNNode]=[:]
    static func villa(variant:Int) -> SCNNode {
        let design=variant%3
        if let template=villas[design] {return template.clone()}
        let root=SCNNode()
        let plaster=SurfaceLibrary.surface("stucco",tint:UIColor(hex:[0xF1E7CF,0xDDD5C4,0xE6BA8E][design]))
        let stone=SurfaceLibrary.surface("ridge-rock",tint:UIColor(hex:0xC4BBA9))
        let tile=SurfaceLibrary.surface("terracotta"),trim=material(0xE6DDC8)
        let frame=material(0x283D3B),shutter=material([0x426B61,0x506774,0x686E4E][design])
        let glass=material(0x203A43);glass.metalness.contents=0.35;glass.roughness.contents=0.2
        @discardableResult func box(_ size:SCNVector3,_ p:SCNVector3,_ m:SCNMaterial) -> SCNNode {
            let g=SCNBox(width:CGFloat(size.x),height:CGFloat(size.y),length:CGFloat(size.z),chamferRadius:0.035);g.materials=[m]
            let n=SCNNode(geometry:g);n.position=p;root.addChildNode(n);return n
        }
        let foundation=box(SCNVector3(13,0.8,10),SCNVector3(0,0.2,0),stone);foundation.name="building-foundation"
        box(SCNVector3(11.6,6.4,8.6),SCNVector3(0,3.6,0),plaster)
        box(SCNVector3(11.9,0.22,8.9),SCNVector3(0,3.5,0),trim)
        box(SCNVector3(12.2,0.24,9.2),SCNVector3(0,6.8,0),trim)
        let roof=pitchedRoof(width:12.7,depth:9.8,rise:2.4,wall:plaster,cover:tile);roof.position.y=6.88;root.addChildNode(roof)
        // Recessed glazing, frames, individual shutter louvers and stone sills.
        for side:Float in [-1,1] {for y:Float in [1.9,5.1] {for x:Float in [-3.7,0,3.7] {
            box(SCNVector3(1.85,2.05,0.2),SCNVector3(x,y,side*4.36),frame)
            box(SCNVector3(1.55,1.8,0.08),SCNVector3(x,y,side*4.48),glass)
            box(SCNVector3(0.055,1.85,0.1),SCNVector3(x,y,side*4.55),trim)
            box(SCNVector3(1.7,0.06,0.1),SCNVector3(x,y,side*4.55),trim)
            box(SCNVector3(2.15,0.16,0.55),SCNVector3(x,y-1.08,side*4.5),trim)
            for s:Float in [-1,1] {
                box(SCNVector3(0.58,2.1,0.11),SCNVector3(x+s*1.25,y,side*4.41),shutter)
                for l in 0..<8 {box(SCNVector3(0.53,0.055,0.13),SCNVector3(x+s*1.25,y-0.83+Float(l)*0.24,side*4.51),frame)}
            }
        }}}
        for side:Float in [-1,1] {for y:Float in [1.9,5.1] {
            box(SCNVector3(0.12,1.95,1.6),SCNVector3(side*5.86,y,0),frame)
            box(SCNVector3(0.07,1.7,1.35),SCNVector3(side*5.95,y,0),glass)
        }}
        box(SCNVector3(8,0.22,1.75),SCNVector3(0,3.9,5.1),trim)
        for x in stride(from:Float(-3.8),through:3.8,by:0.45) {box(SCNVector3(0.04,0.85,0.04),SCNVector3(x,4.4,5.9),frame)}
        box(SCNVector3(8,0.065,0.07),SCNVector3(0,4.85,5.9),frame)
        for x:Float in [-3.8,3.8] {box(SCNVector3(0.2,3.8,0.2),SCNVector3(x,1.9,5.6),trim)}
        box(SCNVector3(0.8,2.7,0.9),SCNVector3(3.2,8.3,-1.8),plaster)
        box(SCNVector3(1.15,0.2,1.25),SCNVector3(3.2,9.7,-1.8),tile)
        // A contained courtyard gives the building a grounded footprint.
        box(SCNVector3(15,0.18,14),SCNVector3(0,0.03,1),stone)
        for x:Float in [-7.2,7.2] {box(SCNVector3(0.35,0.9,13.4),SCNVector3(x,0.45,1),plaster)}
        box(SCNVector3(14.5,0.9,0.35),SCNVector3(0,0.45,-5.7),plaster)
        let bounds=root.boundingBox
        foundation.removeFromParentNode()
        let batched=root.flattenedClone();batched.addChildNode(foundation);batched.boundingBox=bounds;batched.name="coastal-villa"
        villas[design]=batched;return batched.clone()
    }
}
