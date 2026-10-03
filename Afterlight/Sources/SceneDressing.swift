import SceneKit
import UIKit

@MainActor enum SceneDressing {
    static func terrain(_ circuit:Circuit) -> SCNNode {
        let root=SCNNode(), steps=96
        let track=(0..<120).map { circuit.point(Double($0)/120) }
        var vertices:[SCNVector3]=[], uv:[CGPoint]=[],indices:[Int32]=[]
        let left:Float=circuit.environment==0 ? -170 : -500, right:Float=500
        for row in 0...steps { for col in 0...steps {
            let x=left+(right-left)*Float(col)/Float(steps), z = -500+1000*Float(row)/Float(steps)
            let nearest=track.map { hypot($0.x-x,$0.z-z) }.min() ?? 0
            let relief=max(0,min(1,(nearest-19)/65))*RouteScenery.terrainRelief(x,z,circuit:circuit)
            let h:Float = circuit.environment<2 ? -0.04 : -0.04+relief*(1.8+sin(x*0.03)*cos(z*0.025)*1.7)
            vertices.append(SCNVector3(x,h,z));uv.append(CGPoint(x:Double(x)/12,y:Double(z)/12))
        } }
        for row in 0..<steps { for col in 0..<steps { let a=Int32(row*(steps+1)+col),b=a+1,c=a+Int32(steps+1),d=c+1;indices += [a,c,b,b,c,d] } }
        var normals=Array(repeating:SIMD3<Float>.zero,count:vertices.count)
        for i in stride(from:0,to:indices.count,by:3) {
            let a=Int(indices[i]),b=Int(indices[i+1]),c=Int(indices[i+2])
            func point(_ index:Int)->SIMD3<Float> {let v=vertices[index];return SIMD3(v.x,v.y,v.z)}
            let n=simd_cross(point(b)-point(a),point(c)-point(a));normals[a] += n;normals[b] += n;normals[c] += n
        }
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals.map {vector(simd_normalize($0))}),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        let ground=circuit.look.ground=="grass" ? LandscapeArt.terrainMaterial(vegetated:true,desert:false,snow:false):RouteScenery.ground(circuit)
        ground.isDoubleSided=false
        g.materials=[ground];root.addChildNode(SCNNode(geometry:g))
        if circuit.environment==0 {
            let beach=SCNPlane(width:24,height:1000);let sand=SurfaceLibrary.surface("sand");sand.diffuse.contentsTransform=SCNMatrix4MakeScale(2,80,1);sand.normal.contentsTransform=sand.diffuse.contentsTransform;beach.materials=[sand]
            let n=SCNNode(geometry:beach);n.eulerAngles.x = -.pi/2;n.position=SCNVector3(-166,0.01,0);root.addChildNode(n)
        }
        return root
    }
    static func promenade(_ circuit:Circuit) -> SCNNode {
        let root=SCNNode()
        guard circuit.environment==0 else { return root }
        let count=[24,12,12,18,10][circuit.route]
        for i in 0..<count {
            let t=Double(i)/Double(count)+0.035
            // Modern villas and a beach hotel from BlenderKit alternate with the Riviera villas.
            let building=(i%3==1 ? asset("ModernVilla",height:5.4) : i%7==3 ? asset("ModernBlock",height:16) : nil) ?? ArchitectureArt.villa(variant:i)
            building.eulerAngles.y=circuit.heading(t)+Float.pi/2
            let b=building.boundingBox
            var extent:Float=0
            for x in [b.min.x,b.max.x] {for z in [b.min.z,b.max.z] {let corner=building.convertPosition(SCNVector3(x,0,z),to:nil);extent=max(extent,hypot(corner.x,corner.z))}}
            for offset in stride(from:Double(extent)+23,through:Double(extent)+90,by:4) {
                let q=circuit.point(t,lane:-offset)
                if q.x-extent > -154 && RouteScenery.allowsScenery(q,radius:extent,circuit:circuit) && (0..<480).allSatisfy({step in let road=circuit.point(Double(step)/480);return hypot(road.x-q.x,road.z-q.z)>14+extent}) {
                    building.position=SCNVector3(q.x,0,q.z);building.name="roadside-building";root.addChildNode(building)
                    // Imported houses get the same sealed plinth as the authored villas.
                    if building.childNodes.first?.name != "villa" && building.childNode(withName:"building-foundation",recursively:true)==nil {foundation(for:building,in:root);building.position.y = -0.05}
                    break
                }
            }
        }
        // Layer low rocks along the shore instead of a single flat terrain edge.
        for i in 0..<36 {
            let rock=SurfaceLibrary.rock(radius:2.2+Float(i%3)*0.7,height:2.2+Float(i%4)*0.6,seed:i,desert:false);rock.eulerAngles.y=Float(i)*1.7
            rock.position=SCNVector3(-174+Float(i%3),0,Float(i)*24-430);root.addChildNode(rock)
        }
        return root
    }
    static func undergrowth(_ circuit:Circuit) -> SCNNode {
        let root=SCNNode()
        guard circuit.environment==0 || circuit.environment==3 else {return root}
        let road=(0..<480).map {circuit.point(Double($0)/480)}
        for i in 0..<52 {
            let t=Double(i)/52+0.007
            let side:Double=i%2==0 ? -1:1
            let p=circuit.point(t,lane:side*(15.5+Double(i%4)*2.2))
            let radius:Float=2.5
            guard (circuit.environment != 0 || p.x-radius > -153),RouteScenery.allowsScenery(p,radius:radius,circuit:circuit),road.allSatisfy({hypot($0.x-p.x,$0.z-p.z)>13.5+radius}) else {continue}
            if let shrub=asset("CoastalShrub",height:1.4+Float(i%4)*0.30,maxWidth:4) {
                shrub.position=SCNVector3(p.x,-0.05,p.z);shrub.eulerAngles.y=Float(i)*2.39
                shrub.name="roadside-shrub";root.addChildNode(shrub)
            }
        }
        return root
    }
    /// Imported architecture can contain basement ramps, open undersides and
    /// recessed entrances. A sealed plinth bridges those voids to the level
    /// urban terrain, instead of relying on the lowest isolated vertex.
    static func foundation(for building:SCNNode,in parent:SCNNode) {
        let b=building.boundingBox
        let width=(b.max.x-b.min.x)*building.scale.x
        let depth=(b.max.z-b.min.z)*building.scale.z
        let height=(b.max.y-b.min.y)*building.scale.y
        building.position.y = -height*0.14
        let top:Float=0.38
        let geometry=SCNBox(width:CGFloat(width+0.12),height:CGFloat(top+1.5),length:CGFloat(depth+0.12),chamferRadius:0.015)
        let stone=SurfaceLibrary.surface("stucco",tint:UIColor(hex:0xB9B4A7));stone.roughness.contents=0.95
        geometry.materials=[stone]
        let podium=SCNNode(geometry:geometry);podium.name="building-foundation"
        let center=building.convertPosition(SCNVector3((b.min.x+b.max.x)/2,0,(b.min.z+b.max.z)/2),to:parent)
        podium.position=SCNVector3(center.x,(top-1.5)/2,center.z);podium.eulerAngles.y=building.eulerAngles.y
        parent.addChildNode(podium)
    }

    static func tower(height:Float,seed:Int) -> SCNNode {
        let authored=["CityBank","CityOffice","CityTerrace","CityBrick","CityApartment"]
        let fallback=["CityCorner","CityMidrise","CityLandmark"]
        let choice=abs(seed/6)
        // Tall residential towers and modern blocks from BlenderKit mix with the
        // street-scale buildings; taller requests favour the towers.
        let towers:[(String,Float)]=[("TowerHorizon",60.8),("TowerVista",60.8),("TowerPulse",60.6),("BrutalistBlock",38),("ModernBlock",21.7)]
        if height>22 || choice%3==1, let pick=Optional(towers[choice%towers.count]), let building=asset(pick.0,height:pick.1*(0.55+Float(choice%4)*0.08)) {
            building.enumerateChildNodes { node,_ in
                guard let g=node.geometry else {return}
                node.geometry=g.copy() as? SCNGeometry
                node.geometry?.materials=g.materials.map {original in
                    let m=original.copy() as! SCNMaterial
                    // Lit windows at night: glazing glows faintly warm or cool.
                    if m.name?.hasPrefix("Glazing") == true {m.emission.contents=UIColor(hex:seed%2==0 ? 0x5C7FA0:0xB89260);m.emission.intensity=0.35}
                    return m
                }
            }
            return building
        }
        if let building=asset(authored[choice%authored.count],height:max(12,min(32,height))) ?? asset(fallback[choice%fallback.count],height:max(12,min(32,height))) {
            building.enumerateChildNodes { node,_ in
                guard let g=node.geometry else {return}
                node.geometry=g.copy() as? SCNGeometry
                node.geometry?.materials=g.materials.map {original in
                    let m=original.copy() as! SCNMaterial
                    if m.name?.contains("FakeInterior") == true {m.emission.contents=m.diffuse.contents;m.emission.intensity=0.24}
                    if m.name?.contains("Glazing") == true {m.emission.contents=UIColor(hex:seed%2==0 ? 0xA3C3D3:0xC9AD7C);m.emission.intensity=0.10}
                    return m
                }
            }
            return building
        }
        let root=SCNNode(),frame=material(0x677E8B),concrete=SurfaceLibrary.surface("stucco")
        let glass=material(seed%2==0 ? 0x182F46:0x253446);glass.metalness.contents=0.75;glass.roughness.contents=0.16
        func box(_ size:SCNVector3,_ p:SCNVector3,_ m:SCNMaterial) {
            let g=SCNBox(width:CGFloat(size.x),height:CGFloat(size.y),length:CGFloat(size.z),chamferRadius:0.06);g.materials=[m];let n=SCNNode(geometry:g);n.position=p;root.addChildNode(n)
        }
        let levels=Int(height/3)
        box(SCNVector3(13,3,14),SCNVector3(0,1.5,0),concrete)
        box(SCNVector3(10,height,10),SCNVector3(0,height/2+3,0),glass)
        for level in 0...levels {
            let y=Float(level)*3+3
            box(SCNVector3(10.7,0.2,10.7),SCNVector3(0,y,0),frame)
            for x:Float in [-4,-2,0,2,4] {
                for side:Float in [-1,1] {
                    box(SCNVector3(0.08,2.8,0.1),SCNVector3(x,y+1.5,side*5.06),frame)
                    if (level+Int(x)+seed)%4==0 {box(SCNVector3(1.8,1.8,0.015),SCNVector3(x+0.95,y+1.4,side*5.08),material(0xD6AC71,glow:true))}
                }
            }
        }
        box(SCNVector3(11,0.4,11),SCNVector3(0,Float(levels)*3+3.3,0),frame)
        box(SCNVector3(3,1.4,3),SCNVector3(0,Float(levels)*3+4.2,0),frame)
        return root.flattenedClone()
    }
    static func studio() -> SCNScene {
        if let architecture=GLBAsset.load("FestivalGarage") {return festivalStudio(architecture)}
        let scene=SCNScene();scene.background.contents=UIColor(hex:0x12202C)
        scene.lightingEnvironment.contents=Bundle.main.url(forResource:"studio-light",withExtension:"hdr");scene.lightingEnvironment.intensity=0.65
        let stone=SurfaceLibrary.surface("stucco",tint:UIColor(hex:0x87857D));stone.multiply.contents=UIColor(hex:0x394B58);stone.roughness.contents=0.3
        let wood=SurfaceLibrary.surface("stucco"), charcoal=material(0x152431), bronze=material(0x3B586C)
        wood.multiply.contents=UIColor(hex:0x354D5A);wood.roughness.contents=0.8
        bronze.metalness.contents=0.8;bronze.roughness.contents=0.3
        @discardableResult func box(_ size:SCNVector3,_ p:SCNVector3,_ m:SCNMaterial,bevel:CGFloat=0) -> SCNNode {
            let g=SCNBox(width:CGFloat(size.x),height:CGFloat(size.y),length:CGFloat(size.z),chamferRadius:bevel);g.materials=[m]
            let n=SCNNode(geometry:g);n.position=p;scene.rootNode.addChildNode(n);return n
        }
        // An enclosed architectural showroom: tiled floor, timber gallery wall,
        // recessed illuminated ceiling and a glass frontage facing the city.
        for x in -6...6 {for z in -6...5 {
            box(SCNVector3(1.98,0.08,1.98),SCNVector3(Float(x)*2,-0.05,Float(z)*2),stone,bevel:0.012)
        }}
        box(SCNVector3(26,0.2,24),SCNVector3(0,-0.2,-1),charcoal)
        box(SCNVector3(26,5.8,0.24),SCNVector3(0,2.9,-10),wood)
        box(SCNVector3(0.22,5.8,24),SCNVector3(-12,2.9,1),wood)
        box(SCNVector3(26,0.2,24),SCNVector3(0,5.8,1),charcoal)
        for x:Float in [-10,-5,0,5,10] {box(SCNVector3(0.32,5.5,0.5),SCNVector3(x,2.8,-9.5),charcoal);box(SCNVector3(0.35,0.2,20),SCNVector3(x,5.45,0),bronze)}
        for y:Float in [1,2,3,4] {box(SCNVector3(12,0.07,0.1),SCNVector3(0,y,-9.6),bronze)}
        let glazing=material(0x263D47);glazing.transparency=0.22;glazing.metalness.contents=0.65;glazing.roughness.contents=0.08
        for z in stride(from:Float(-9),through:9,by:3) {
            box(SCNVector3(0.03,5.5,2.9),SCNVector3(11.9,2.8,z),glazing)
            box(SCNVector3(0.16,5.8,0.08),SCNVector3(11.8,2.9,z-1.5),bronze)
        }
        // Large luminous softboxes are visible architecture and reflected in paint.
        for x:Float in [-5,0,5] {for z:Float in [-5,2] {
            box(SCNVector3(3.3,0.12,2),SCNVector3(x,5.64,z),material(0xCEF0FF,glow:true))
            box(SCNVector3(3.55,0.08,2.25),SCNVector3(x,5.73,z),bronze)
        }}
        for x:Float in [-6,6] {
            box(SCNVector3(0.04,0.02,15),SCNVector3(x,0.005,-1),bronze)
            box(SCNVector3(3.8,0.16,1.5),SCNVector3(x,0.65,-7.5),wood,bevel:0.07)
            for leg:Float in [-1.4,1.4] {box(SCNVector3(0.08,0.6,1.1),SCNVector3(x+leg,0.3,-7.5),bronze)}
        }
        for x:Float in [-8,8] {
            if let ac=asset("CityAC",height:0.7) {ac.position=SCNVector3(x,4.6,-9.4);scene.rootNode.addChildNode(ac)}
            let pot=SCNCylinder(radius:0.5,height:0.8);pot.materials=[charcoal];let planter=SCNNode(geometry:pot);planter.position=SCNVector3(x,0.4,-6.5);scene.rootNode.addChildNode(planter)
            if let tree=asset("pine_sapling_small",height:3) {tree.position=SCNVector3(x,0.65,-6.5);scene.rootNode.addChildNode(tree)}
        }
        let sign=SCNText(string:"AFTERLIGHT",extrusionDepth:0.015);sign.font=UIFont.systemFont(ofSize:1,weight:.light);sign.flatness=0.1;sign.materials=[material(0xE7DBC0,glow:true)]
        let logo=SCNNode(geometry:sign);logo.scale=SCNVector3(0.55,0.55,0.55);logo.position=SCNVector3(-2,2.1,-9.6);scene.rootNode.addChildNode(logo)
        for i in 0..<7 {
            let building=tower(height:12+Float(i%3)*8,seed:i);building.position=SCNVector3(25+Float(i%2)*9,-0.5,Float(i)*8-25);scene.rootNode.addChildNode(building)
        }
        for (p,power) in [(SCNVector3(-3,5,4),CGFloat(500)),(SCNVector3(5,4,-5),CGFloat(300))] {
            let n=SCNNode();n.light=SCNLight();n.light?.type = .spot;n.light?.spotInnerAngle=55;n.light?.spotOuterAngle=100;n.light?.intensity=power;n.light?.color=UIColor(hex:0xDBEDFF);n.light?.castsShadow=true;n.light?.shadowRadius=4;n.light?.shadowMapSize=CGSize(width:2048,height:2048);n.light?.shadowColor=UIColor(white:0,alpha:0.45);n.position=p;n.look(at:SCNVector3(0,0,0));scene.rootNode.addChildNode(n)
        }
        return scene
    }

    private static func festivalStudio(_ architecture:SCNNode) -> SCNScene {
        let scene=SCNScene();scene.background.contents=UIColor(hex:0x172330)
        scene.rootNode.addChildNode(architecture)
        scene.lightingEnvironment.contents=Bundle.main.url(forResource:"studio-light",withExtension:"hdr")
        scene.lightingEnvironment.intensity=0.32
        let steel=material(0x182633);steel.metalness.contents=0.75;steel.roughness.contents=0.38
        func box(_ size:SCNVector3,_ position:SCNVector3,_ m:SCNMaterial) {
            let geometry=SCNBox(width:CGFloat(size.x),height:CGFloat(size.y),length:CGFloat(size.z),chamferRadius:0.015)
            geometry.materials=[m];let node=SCNNode(geometry:geometry);node.position=position;scene.rootNode.addChildNode(node)
        }
        // Display-bay markings and suspended fixtures give the workshop a
        // motorsport identity while the authored walls retain their texture.
        for x:Float in [-2.1,2.1] {
            box(SCNVector3(0.07,0.012,7),SCNVector3(x,0.014,0),material(0xFFD52A))
            box(SCNVector3(0.05,0.08,7),SCNVector3(x,6.4,0),material(0xC7E7F2,glow:true))
            box(SCNVector3(0.18,0.12,7.2),SCNVector3(x,6.48,0),steel)
        }
        for z:Float in [-3.5,3.5] {box(SCNVector3(4.2,0.012,0.07),SCNVector3(0,0.014,z),material(0xFFD52A))}
        for x:Float in [-7.5,7.5] {
            box(SCNVector3(0.06,4.2,0.08),SCNVector3(x,2.7,-8.85),material(0x47CFFF,glow:true))
            // Tool cabinets, individually modeled drawers and black worktops.
            box(SCNVector3(2.2,1.1,0.85),SCNVector3(x,0.55,-7.7),material(0x16577B))
            box(SCNVector3(2.3,0.08,0.95),SCNVector3(x,1.13,-7.7),steel)
            for y:Float in [0.22,0.48,0.74,1] {box(SCNVector3(1.95,0.025,0.04),SCNVector3(x,y,-7.25),steel)}
        }
        // Deep blue epoxy service bay and a graphic pit-wall backdrop give the
        // workshop a contemporary motorsport identity while retaining its texture.
        let epoxy=material(0x233C50);epoxy.roughness.contents=0.28;epoxy.metalness.contents=0.18
        box(SCNVector3(6.8,0.022,8.4),SCNVector3(0,-0.006,0),epoxy)
        for x:Float in [-3.45,3.45] {
            box(SCNVector3(0.065,0.016,8.5),SCNVector3(x,0.014,0),material(0xFFD52A))
            for z:Float in [-3.8,-3.4,-3.0,3.0,3.4,3.8] {
                box(SCNVector3(0.6,0.018,0.14),SCNVector3(x,0.017,z),material(0xFFD52A))
            }
        }
        let wall=material(0x103148);wall.roughness.contents=0.62
        box(SCNVector3(4.2,2.7,0.07),SCNVector3(0,2.7,-8.82),wall)
        box(SCNVector3(4.2,0.05,0.08),SCNVector3(0,1.34,-8.75),material(0x47CFFF,glow:true))
        let text=SCNText(string:"AFTERLIGHT / MOTORWORKS",extrusionDepth:0.005)
        text.font=UIFont.systemFont(ofSize:1,weight:.bold);text.flatness=0.15;text.materials=[material(0xCBE7F1,glow:true)]
        let sign=SCNNode(geometry:text);sign.scale=SCNVector3(0.14,0.14,0.14);sign.position=SCNVector3(-1.8,2.7,-8.72);scene.rootNode.addChildNode(sign)
        for (position,power,color) in [(SCNVector3(-5,5.5,3),CGFloat(380),UInt32(0xE6EFF5)),(SCNVector3(4,5,-4),CGFloat(240),UInt32(0x83C8ED)),(SCNVector3(-7,3,-5),CGFloat(160),UInt32(0xFFD6A3))] {
            let node=SCNNode();let light=SCNLight();light.type = .spot;light.intensity=power;light.color=UIColor(hex:color)
            light.spotInnerAngle=45;light.spotOuterAngle=105;light.castsShadow=true;light.shadowRadius=5
            light.shadowMapSize=CGSize(width:2048,height:2048);light.shadowColor=UIColor(white:0,alpha:0.4)
            node.light=light;node.position=position;node.look(at:SCNVector3(0,0.5,0));scene.rootNode.addChildNode(node)
        }
        return scene
    }

}

extension SceneDressing {
    private static var imported:[String:SCNNode]=[:]
    static func asset(_ name:String,height:Float,maxWidth:Float?=nil) -> SCNNode? {
        if imported[name]==nil {imported[name]=GLBAsset.load(name)}
        guard let template=imported[name] else{return nil}
        let model=template.clone();let bounds=model.boundingBox
        let span=bounds.max.y-bounds.min.y
        guard span>0 else{return nil}
        model.position=SCNVector3(-(bounds.min.x+bounds.max.x)/2,-bounds.min.y,-(bounds.min.z+bounds.max.z)/2)
        let root=SCNNode();root.addChildNode(model);let scale=height/span
        let horizontal=max(bounds.max.x-bounds.min.x,bounds.max.z-bounds.min.z)*scale
        let footprint=maxWidth.map {min(1,$0/max(horizontal,0.001))} ?? 1
        root.scale=SCNVector3(scale*footprint,scale*footprint,scale*footprint);return root
    }
    private static var palmTemplate:SCNNode?
    static func palm() -> SCNNode {
        if let asset=asset("RoyalPalm",height:11) ?? asset("CoastalPalm",height:11) {return asset}
        if let template=palmTemplate {return template.clone()}
        let root=SCNNode(), bark=SurfaceLibrary.surface("bark")
        for segment in 0..<8 {
            let cylinder=SCNCylinder(radius:CGFloat(0.28-Float(segment)*0.014),height:1.3);cylinder.radialSegmentCount=10;cylinder.materials=[bark]
            let n=SCNNode(geometry:cylinder);let y=Float(segment)*1.25+0.625;n.position=SCNVector3(y*y*0.008,y,0);n.eulerAngles.z = -y*0.012;root.addChildNode(n)
        }
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uv:[CGPoint]=[],indices:[Int32]=[]
        func triangle(_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ c:SIMD3<Float>) {
            var b=b,c=c;var normal=simd_normalize(simd_cross(b-a,c-a));if normal.y<0 {swap(&b,&c);normal = -normal}
            let base=Int32(vertices.count);vertices += [vector(a),vector(b),vector(c)];normals += [vector(normal),vector(normal),vector(normal)];uv += [CGPoint(x:0,y:0),CGPoint(x:1,y:0),CGPoint(x:0.5,y:1)];indices += [base,base+1,base+2]
        }
        for frond in 0..<9 {
            let angle=Float(frond)*2 * .pi/9;let forward=SIMD3<Float>(sin(angle),0,cos(angle)),side=SIMD3<Float>(cos(angle),0,-sin(angle))
            for leaf in 1..<19 {
                let d=Float(leaf)*0.26, base=SIMD3<Float>(0.78,10.0+sin(d*0.6)*0.6-d*d*0.065,0)+forward*d
                let width=(0.35+sin(Float(leaf)/19 * .pi)*0.55)
                for sign:Float in [-1,1] {
                    let tip=base+side*sign*width-forward*0.36+SIMD3<Float>(0,-0.22,0)
                    let left=base+forward*0.1,right=base-forward*0.1,crease=(base+tip)*0.5+SIMD3<Float>(0,0.06,0)
                    triangle(left,crease,tip);triangle(right,tip,crease);triangle(left,right,crease)
                }
            }
        }
        let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        let green=material(0x4E713E);green.roughness.contents=0.85;green.isDoubleSided=true;geometry.materials=[green];root.addChildNode(SCNNode(geometry:geometry));palmTemplate=root.flattenedClone();return palmTemplate!.clone()
    }
}
