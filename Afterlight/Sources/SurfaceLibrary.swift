import SceneKit
import UIKit

/// Original, bundled PBR surfaces. Meter-based UVs keep grain scale consistent.
@MainActor enum SurfaceLibrary {
    private static var images: [String: UIImage] = [:]
    static func image(_ name: String) -> UIImage? {
        if let image = images[name] { return image }
        guard let url = Bundle.main.url(forResource:name,withExtension:"png") ?? Bundle.main.url(forResource:name,withExtension:"jpg"), let image=UIImage(contentsOfFile:url.path) else { return nil }
        images[name]=image; return image
    }
    static func surface(_ name: String, tint: UIColor = .white) -> SCNMaterial {
        let m=SCNMaterial(); m.lightingModel = .physicallyBased
        let textureName=name=="grass" ? "terrain-grass":name
        m.diffuse.contents=image(name=="asphalt" ? "asphalt-art" : textureName) ?? image(name) ?? tint; m.diffuse.intensity=1; m.multiply.contents=tint
        m.normal.contents=image(textureName+"-normal"); m.normal.intensity=0.6
        m.roughness.contents=image(textureName+"-roughness") ?? 0.85; m.metalness.contents=0
        for channel in [m.diffuse,m.normal,m.roughness] { channel.wrapS = .repeat; channel.wrapT = .repeat; channel.minificationFilter = .linear; channel.magnificationFilter = .linear; channel.mipFilter = .linear; channel.maxAnisotropy=16 }
        return m
    }
    static func paint(_ color: UInt32) -> SCNMaterial {
        let m=material(color); m.name="BodyPaint"; m.metalness.contents=0.25; m.roughness.contents=0.26
        m.clearCoat.contents=0.85; m.clearCoatRoughness.contents=0.12
        return m
    }
    private static var tourers: [String:SCNNode] = [:]
    private static var platforms:[String:SCNNode]=[:]
    static func grandTourer(_ car: Car,model:String?=nil) -> SCNNode? {
        let design = model ?? car.modelName
        if platforms[design]==nil {platforms[design]=GLBAsset.load(design) ?? GLBAsset.load(design=="ConceptGT" ? "Hyper":"Concept")}
        let key="\(design)-\(car.id)"
        if tourers[key] == nil, let asset=platforms[design]?.clone() {
            let root=SCNNode();let bounds=asset.boundingBox;asset.position=SCNVector3(-(bounds.min.x+bounds.max.x)/2,-bounds.min.y,-(bounds.min.z+bounds.max.z)/2);root.addChildNode(asset)
            asset.enumerateChildNodes { node,_ in
                if node.name?.contains("Emblem") == true {node.isHidden=true}
                guard let geometry=node.geometry else{return}
                node.geometry=geometry.copy() as? SCNGeometry
                node.geometry?.materials=geometry.materials.map {original in
                    let m=original.copy() as! SCNMaterial
                    if m.name?.hasPrefix("Paint 1") == true || m.name?.hasPrefix("LuxuryBodyPaint") == true {let body=paint(car.color);if design=="LuxurySedan" || design=="SportsCoupe" {body.metalness.contents=0.45;body.roughness.contents=0.3;body.clearCoat.contents=0.6;body.clearCoatRoughness.contents=0.16};return body}
                    if m.name=="Glass" {m.diffuse.contents=UIColor(hex:0x142B38);m.multiply.contents=UIColor.white;m.transparency=0.96;m.metalness.contents=0.05;m.roughness.contents=0.08}
                    return m
                }
            }
            var wheels:[SCNNode]=[]
            asset.enumerateChildNodes { n,_ in if ["WheelFrontL","WheelFrontR","WheelRearL","WheelRearR"].contains(n.name ?? "") {wheels.append(n)} }
            for wheel in wheels {
                guard let parent=wheel.parent else{continue}
                let pivot=SCNNode();pivot.name="rolling-wheel";pivot.position=wheel.position
                wheel.position=SCNVector3Zero;wheel.removeFromParentNode();pivot.addChildNode(wheel);parent.addChildNode(pivot)
            }
            if model==nil && car.id==3 {asset.childNode(withName:"BodyRoofPanel",recursively:true)?.isHidden=true}
            if model==nil && car.id>=4 {
                let wing=SCNNode(geometry:SCNBox(width:2.05,height:0.08,length:0.4,chamferRadius:0.035));wing.position=SCNVector3(0,1.1,-1.8);wing.geometry?.materials=[surface("carbon")];root.addChildNode(wing)
                for x:Float in [-0.7,0.7] {let support=SCNNode(geometry:SCNBox(width:0.07,height:0.3,length:0.14,chamferRadius:0.02));support.position=SCNVector3(x,0.96,-1.8);support.geometry?.materials=[material(0x18202A)];root.addChildNode(support)}
            }
            tourers[key]=root
        }
        return tourers[key]?.clone()
    }
    static func rock(radius: Float, height: Float, seed: Int, desert: Bool, snow:Bool=false) -> SCNNode {
        let sides=18, rings=10
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uv:[CGPoint]=[],indices:[Int32]=[]
        for ring in 0...rings { let phi=Float(ring)/Float(rings) * .pi
            for side in 0...sides { let theta=Float(side)/Float(sides)*2 * .pi
                let noise=1+0.14*sin(theta*3+Float(seed))+0.12*cos(phi*5+theta*2)
                let x=sin(phi)*cos(theta),z=sin(phi)*sin(theta),y=cos(phi)
                vertices.append(SCNVector3(x*radius*noise,y*height*0.5,z*radius*noise)); normals.append(SCNVector3(x,y,z)); uv.append(CGPoint(x:Double(side)/Double(sides)*3,y:Double(ring)/Double(rings)*3))
            }
        }
        for ring in 0..<rings { for side in 0..<sides { let a=Int32(ring*(sides+1)+side),b=a+1,c=a+Int32(sides+1),d=c+1;indices += [a,b,c,b,d,c] } }
        let split=(rings/3)*sides*6
        let elements=snow ? [SCNGeometryElement(indices:Array(indices.dropFirst(split)),primitiveType:.triangles),SCNGeometryElement(indices:Array(indices.prefix(split)),primitiveType:.triangles)] : [SCNGeometryElement(indices:indices,primitiveType:.triangles)]
        let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:elements)
        let m=surface("rock"); if desert {m.multiply.contents=UIColor(hex:0xC19B7E)};m.isDoubleSided=true
        let ice=material(0xD6E1E4);ice.roughness.contents=0.92;ice.normal.contents=image("sand-normal");geometry.materials=snow ? [m,ice] : [m]
        return SCNNode(geometry:geometry)
    }
}

extension SurfaceLibrary {
    static func hill(radius:Float,height:Float,seed:Int,vegetated:Bool,desert:Bool,snow:Bool=false) -> SCNNode {
        LandscapeArt.ridge(radius:radius,height:height,seed:seed,vegetated:vegetated,desert:desert,snow:snow)
    }
}
