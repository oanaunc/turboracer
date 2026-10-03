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
    static func paint(_ color: UInt32, finish: PaintFinish = .metallic) -> SCNMaterial {
        let m=material(color); m.name="BodyPaint"; m.metalness.contents=0.25; m.roughness.contents=0.26
        m.clearCoat.contents=0.85; m.clearCoatRoughness.contents=0.12
        switch finish {
        case .metallic:
            // Fine metallic flake under the clear coat.
            m.normal.contents=flake;m.normal.intensity=0.18;m.normal.wrapS = .repeat;m.normal.wrapT = .repeat
            m.normal.contentsTransform=SCNMatrix4MakeScale(6,6,1);m.metalness.contents=0.45;m.roughness.contents=0.3
        case .pearl:
            m.metalness.contents=0.55;m.roughness.contents=0.18;m.clearCoat.contents=1;m.clearCoatRoughness.contents=0.05
        case .matte:
            m.metalness.contents=0.1;m.roughness.contents=0.62;m.clearCoat.contents=0
        }
        return m
    }
    private static let flake:UIImage = UIGraphicsImageRenderer(size:CGSize(width:256,height:256)).image { ctx in
        UIColor(red:0.5,green:0.5,blue:1,alpha:1).setFill();ctx.fill(CGRect(x:0,y:0,width:256,height:256))
        var s:UInt32=9
        func r() -> CGFloat {s=s &* 1664525 &+ 1013904223;return CGFloat(s>>8)/CGFloat(1<<24)}
        for _ in 0..<5200 {UIColor(red:0.2+r()*0.6,green:0.2+r()*0.6,blue:1,alpha:1).setFill();ctx.fill(CGRect(x:r()*256,y:r()*256,width:1.4,height:1.4))}
    }
    /// White race roundel with a black number, transparent outside the disc.
    private static func roundel(_ number:Int) -> UIImage {
        UIGraphicsImageRenderer(size:CGSize(width:128,height:128)).image { ctx in
            UIColor.white.setFill();ctx.cgContext.fillEllipse(in:CGRect(x:4,y:4,width:120,height:120))
            let text=NSAttributedString(string:"\(number)",attributes:[.font:UIFont.systemFont(ofSize:68,weight:.black),.foregroundColor:UIColor.black])
            let size=text.size();text.draw(at:CGPoint(x:64-size.width/2,y:64-size.height/2))
        }
    }
    /// Aero kits fitted from the body's bounds: sport adds splitter, skirts
    /// and diffuser; race adds a swan-neck wing, dive planes and roundels.
    private static func fitKit(_ kit:Int,car:Car,to root:SCNNode) {
        guard kit>0 else {return}
        let b=root.boundingBox, w=b.max.x-b.min.x, l=b.max.z-b.min.z, h=b.max.y-b.min.y
        let carbon=surface("carbon"), accent=material(kit==2 ? 0xE8C547 : 0x1A1F26)
        func add(_ size:SCNVector3,_ p:SCNVector3,_ m:SCNMaterial,_ name:String) {
            let g=SCNBox(width:CGFloat(size.x),height:CGFloat(size.y),length:CGFloat(size.z),chamferRadius:CGFloat(min(size.x,size.y,size.z)*0.3))
            g.materials=[m];let n=SCNNode(geometry:g);n.position=p;n.name=name;root.addChildNode(n)
        }
        add(SCNVector3(w*0.92,0.035,0.34),SCNVector3(0,b.min.y+0.11,b.max.z-0.08),carbon,"kit-splitter")
        for side:Float in [-1,1] {
            add(SCNVector3(0.07,0.07,l*0.46),SCNVector3(side*(w/2-0.02),b.min.y+0.2,(b.min.z+b.max.z)/2),carbon,"kit-skirt")
        }
        for x:Float in [-0.45,-0.15,0.15,0.45] {add(SCNVector3(0.025,0.14,0.32),SCNVector3(x*w*0.6,b.min.y+0.16,b.min.z+0.1),carbon,"kit-diffuser")}
        if kit==2 {
            let top=b.min.y+h*0.86
            add(SCNVector3(w*0.98,0.05,0.42),SCNVector3(0,top+0.2,b.min.z+0.32),carbon,"kit-wing")
            for side:Float in [-1,1] {
                add(SCNVector3(0.03,0.36,0.46),SCNVector3(side*w*0.49,top+0.12,b.min.z+0.32),accent,"kit-endplate")
                add(SCNVector3(0.05,0.3,0.1),SCNVector3(side*w*0.27,top+0.03,b.min.z+0.36),carbon,"kit-swan-neck")
                add(SCNVector3(0.22,0.025,0.16),SCNVector3(side*(w/2-0.06),b.min.y+0.38,b.max.z-0.3),carbon,"kit-dive-plane")
                let disc=SCNPlane(width:0.62,height:0.62);let m=SCNMaterial();m.lightingModel = .physicallyBased;m.diffuse.contents=roundel(car.id+7)
                m.roughness.contents=0.35;m.clearCoat.contents=0.8;GLBAsset.configureCutout(m,cutoff:0.5);disc.materials=[m]
                let n=SCNNode(geometry:disc);n.name="kit-roundel";n.position=SCNVector3(side*(w/2+0.012),b.min.y+h*0.42,(b.min.z+b.max.z)/2+0.05)
                n.eulerAngles.y=side*Float.pi/2;root.addChildNode(n)
            }
        }
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
                    if m.name?.hasPrefix("Paint 1") == true || m.name?.hasPrefix("LuxuryBodyPaint") == true {let body=paint(car.color,finish:car.finish);if design=="LuxurySedan" || design=="SportsCoupe" {body.metalness.contents=0.45;body.roughness.contents=0.3;body.clearCoat.contents=0.6;body.clearCoatRoughness.contents=0.16};return body}
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
            if model==nil && design=="Roadster" {asset.childNode(withName:"BodyRoofPanel",recursively:true)?.isHidden=true}
            if model==nil && design=="Hyper" && car.kit<2 {
                let wing=SCNNode(geometry:SCNBox(width:2.05,height:0.08,length:0.4,chamferRadius:0.035));wing.position=SCNVector3(0,1.1,-1.8);wing.geometry?.materials=[surface("carbon")];root.addChildNode(wing)
                for x:Float in [-0.7,0.7] {let support=SCNNode(geometry:SCNBox(width:0.07,height:0.3,length:0.14,chamferRadius:0.02));support.position=SCNVector3(x,0.96,-1.8);support.geometry?.materials=[material(0x18202A)];root.addChildNode(support)}
            }
            if model==nil {fitKit(car.kit,car:car,to:root)}
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
