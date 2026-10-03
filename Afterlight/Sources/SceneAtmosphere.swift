import SceneKit
import UIKit

@MainActor enum SceneAtmosphere {
    /// Circuit-board face for the memory chip: navy substrate, glowing cyan
    /// traces with via pads and a bright central die. Drawn once and cached.
    private static let chipFace:(color:UIImage,glow:UIImage) = {
        let size=CGSize(width:256,height:256)
        func draw(glowOnly:Bool) -> UIImage {
            UIGraphicsImageRenderer(size:size).image { ctx in
                let c=ctx.cgContext
                (glowOnly ? UIColor.black : UIColor(hex:0x0B1F33)).setFill();c.fill(CGRect(origin:.zero,size:size))
                if !glowOnly {
                    UIColor(hex:0x143552).setStroke();c.setLineWidth(1)
                    for i in stride(from:8,to:256,by:16) {c.move(to:CGPoint(x:i,y:0));c.addLine(to:CGPoint(x:i,y:256));c.move(to:CGPoint(x:0,y:i));c.addLine(to:CGPoint(x:256,y:i))};c.strokePath()
                }
                let trace=glowOnly ? UIColor(hex:0x5FF4FF) : UIColor(hex:0x3FD8F2)
                trace.setStroke();trace.setFill();c.setLineWidth(5);c.setLineCap(.round);c.setLineJoin(.round)
                // Traces fan out from the die to the edge pins, with 45° jogs.
                var seed:UInt32=7
                func rnd(_ n:Int) -> Int {seed=seed &* 1103515245 &+ 12345;return Int((seed>>16)%UInt32(n))}
                for side in 0..<4 { for k in 0..<5 {
                    let o=CGFloat(70+k*29)
                    let (start,mid,end):(CGPoint,CGPoint,CGPoint)
                    switch side {
                    case 0: start=CGPoint(x:o,y:96);mid=CGPoint(x:o+CGFloat(rnd(3)-1)*14,y:52);end=CGPoint(x:mid.x,y:10)
                    case 1: start=CGPoint(x:o,y:160);mid=CGPoint(x:o+CGFloat(rnd(3)-1)*14,y:204);end=CGPoint(x:mid.x,y:246)
                    case 2: start=CGPoint(x:96,y:o);mid=CGPoint(x:52,y:o+CGFloat(rnd(3)-1)*14);end=CGPoint(x:10,y:mid.y)
                    default: start=CGPoint(x:160,y:o);mid=CGPoint(x:204,y:o+CGFloat(rnd(3)-1)*14);end=CGPoint(x:246,y:mid.y)
                    }
                    c.move(to:start);c.addLine(to:mid);c.addLine(to:end);c.strokePath()
                    c.fillEllipse(in:CGRect(x:end.x-6,y:end.y-6,width:12,height:12))
                }}
                // Central die with a bright frame.
                (glowOnly ? UIColor(hex:0xBFFBFF) : UIColor(hex:0x10283F)).setFill();c.fill(CGRect(x:92,y:92,width:72,height:72))
                trace.setStroke();c.setLineWidth(6);c.stroke(CGRect(x:92,y:92,width:72,height:72))
                if !glowOnly {
                    UIColor(hex:0xFFC35A).setFill()
                    for i in 0..<4 { c.fill(CGRect(x:104+i*13,y:104,width:8,height:48)) }
                }
            }
        }
        return (draw(glowOnly:false),draw(glowOnly:true))
    }()
    private static let beamImage:UIImage = UIGraphicsImageRenderer(size:CGSize(width:16,height:128)).image { ctx in
        let colors=[UIColor(red:0.35,green:0.95,blue:1,alpha:0).cgColor,UIColor(red:0.35,green:0.95,blue:1,alpha:0.55).cgColor]
        let g=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:[0,1])!
        ctx.cgContext.drawLinearGradient(g,start:.zero,end:CGPoint(x:0,y:128),options:[])
    }
    private static let haloImage:UIImage = UIGraphicsImageRenderer(size:CGSize(width:128,height:128)).image { ctx in
        let colors=[UIColor(red:0.4,green:0.95,blue:1,alpha:0.8).cgColor,UIColor(red:0.2,green:0.7,blue:1,alpha:0.25).cgColor,UIColor.clear.cgColor]
        let g=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:[0,0.35,1])!
        ctx.cgContext.drawRadialGradient(g,startCenter:CGPoint(x:64,y:64),startRadius:0,endCenter:CGPoint(x:64,y:64),endRadius:64,options:[])
    }
    /// The collectible: a glowing circuit chip in a faceted glass case with
    /// gold pins, two counter-rotating halo rings, a light beam and a ground glow.
    static func memoryChip() -> SCNNode {
        let root=SCNNode();root.name="memory-chip"
        let additive:(UIImage) -> SCNMaterial = { image in
            let m=SCNMaterial();m.lightingModel = .constant;m.diffuse.contents=image;m.blendMode = .add
            m.writesToDepthBuffer=false;m.isDoubleSided=true;return m
        }
        // Chip body: face texture on both large sides, brushed metal edges.
        let face=SCNMaterial();face.lightingModel = .physicallyBased;face.diffuse.contents=chipFace.color
        face.emission.contents=chipFace.glow;face.emission.intensity=1.4;face.metalness.contents=0.4;face.roughness.contents=0.3
        let edge=material(0xC9D6DD);edge.metalness.contents=1;edge.roughness.contents=0.18
        let body=SCNBox(width:0.95,height:0.95,length:0.12,chamferRadius:0.05)
        body.materials=[face,edge,face,edge,edge,edge]
        let chip=SCNNode(geometry:body);root.addChildNode(chip)
        let gold=material(0xFFC35A);gold.metalness.contents=1;gold.roughness.contents=0.25
        let pins=SCNNode()
        for side in 0..<4 { for k in 0..<5 {
            let pin=SCNNode(geometry:SCNBox(width:0.07,height:0.16,length:0.05,chamferRadius:0.01));pin.geometry?.materials=[gold]
            let o=Float(k-2)*0.16
            switch side {
            case 0: pin.position=SCNVector3(o,0.53,0)
            case 1: pin.position=SCNVector3(o,-0.53,0)
            case 2: pin.position=SCNVector3(-0.53,o,0);pin.eulerAngles.z = .pi/2
            default: pin.position=SCNVector3(0.53,o,0);pin.eulerAngles.z = .pi/2
            }
            pins.addChildNode(pin)
        }}
        root.addChildNode(pins.flattenedClone())
        // Faceted glass case: an octagonal capsule of clear, reflective glass.
        let glass=SCNMaterial();glass.lightingModel = .physicallyBased;glass.diffuse.contents=UIColor(red:0.55,green:0.9,blue:1,alpha:1)
        glass.metalness.contents=1;glass.roughness.contents=0.04;glass.transparency=0.22;glass.blendMode = .add;glass.writesToDepthBuffer=false
        glass.transparencyMode = .dualLayer;glass.isDoubleSided=true
        let caseShape=SCNCylinder(radius:0.86,height:0.34);caseShape.radialSegmentCount=8;caseShape.materials=[glass]
        let shell=SCNNode(geometry:caseShape);shell.eulerAngles.x = .pi/2;shell.eulerAngles.y = .pi/8;root.addChildNode(shell)
        // Counter-rotating halo rings.
        let ringMaterial=material(0x5FF4FF,glow:true);ringMaterial.emission.intensity=2
        for (index,tilt) in [Float(1.2),-0.75].enumerated() {
            let ring=SCNNode(geometry:SCNTorus(ringRadius:1.08+CGFloat(index)*0.14,pipeRadius:0.022));ring.geometry?.materials=[ringMaterial]
            ring.eulerAngles=SCNVector3(tilt,0,0.4)
            ring.runAction(.repeatForever(.rotateBy(x:0,y:index==0 ? 2 * .pi : -2 * .pi,z:0,duration:index==0 ? 2.4 : 3.6)))
            root.addChildNode(ring)
        }
        let beam=SCNCylinder(radius:0.32,height:7);beam.materials=[additive(beamImage)]
        let beamNode=SCNNode(geometry:beam);beamNode.position.y = -1.55+3.5;beamNode.castsShadow=false;root.addChildNode(beamNode)
        let halo=SCNPlane(width:2.6,height:2.6);halo.materials=[additive(haloImage)]
        let haloNode=SCNNode(geometry:halo);haloNode.eulerAngles.x = -.pi/2;haloNode.position.y = -1.5;haloNode.castsShadow=false;root.addChildNode(haloNode)
        root.enumerateHierarchy { node,_ in node.castsShadow=false }
        return root
    }
    private static let contact:UIImage = UIGraphicsImageRenderer(size:CGSize(width:128,height:128)).image { context in
        let colors=[UIColor(white:0,alpha:0.65).cgColor,UIColor(white:0,alpha:0.42).cgColor,UIColor.clear.cgColor]
        let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:[0,0.55,1])!
        context.cgContext.drawRadialGradient(gradient,startCenter:CGPoint(x:64,y:64),startRadius:0,endCenter:CGPoint(x:64,y:64),endRadius:64,options:[])
    }
    static func contactShadow(for car:SCNNode) -> SCNNode {
        let b=car.boundingBox
        let plane=SCNPlane(width:CGFloat(b.max.x-b.min.x)*1.4,height:CGFloat(b.max.z-b.min.z)*1.15)
        let m=SCNMaterial();m.lightingModel = .constant;m.diffuse.contents=contact;m.writesToDepthBuffer=false;m.blendMode = .alpha
        plane.materials=[m];let n=SCNNode(geometry:plane);n.eulerAngles.x = -.pi/2;n.position.y=0.13;n.castsShadow=false;n.name="vehicle-contact-shadow"
        return n
    }
    static func skyline(_ circuit:Circuit) -> SCNNode {
        let root=SCNNode()
        // Landmark skyscrapers break up the distant box skyline.
        for i in 0..<9 {
            guard let tower=SceneDressing.asset(i%2==0 ? "SkyscraperA":"SkyscraperB",height:140+Float(i%3)*35) else {break}
            let angle=Float(i)*2 * .pi/9+0.2,distance:Float=420+Float(i%3)*40
            tower.position=SCNVector3(sin(angle)*distance,-2,cos(angle)*distance);tower.eulerAngles.y=angle+Float(i)
            tower.enumerateHierarchy {n,_ in n.castsShadow=false
                n.geometry?.materials.forEach {m in if m.name?.hasPrefix("Glazing") == true {m.emission.contents=SurfaceLibrary.image("facade-emission");m.emission.intensity=0.6}}}
            root.addChildNode(tower)
        }
        for i in 0..<72 {
            let angle=Float(i)*2 * .pi/72,distance:Float=350+Float(i%5)*18
            let h:CGFloat=CGFloat(22+(i*37)%105),w:CGFloat=CGFloat(14+i%5*4)
            let m=SCNMaterial();m.lightingModel = .physicallyBased;m.diffuse.contents=SurfaceLibrary.image("facade-night")
            m.emission.contents=SurfaceLibrary.image("facade-emission");m.emission.intensity=0.55
            m.roughness.contents=0.5;m.metalness.contents=0.25
            for property in [m.diffuse,m.emission] {property.wrapS = .repeat;property.wrapT = .repeat;property.contentsTransform=SCNMatrix4MakeScale(Float(w/32),Float(h/32),1)}
            let g=SCNBox(width:w,height:h,length:w*0.8,chamferRadius:0);g.materials=[m]
            let n=SCNNode(geometry:g);n.position=SCNVector3(sin(angle)*distance,Float(h)/2-2,cos(angle)*distance);n.eulerAngles.y=angle;n.castsShadow=false;root.addChildNode(n)
        }
        return root
    }
    static func sea() -> SCNNode {
        let plane=SCNPlane(width:1400,height:1400);plane.widthSegmentCount=64;plane.heightSegmentCount=64
        let m=material(0x187C91);m.metalness.contents=0.02;m.roughness.contents=0.07
        m.normal.contents=SurfaceLibrary.image("water-normal");m.normal.wrapS = .repeat;m.normal.wrapT = .repeat;m.normal.contentsTransform=SCNMatrix4MakeScale(110,110,1);m.normal.intensity=0.65
        m.shaderModifiers=[.geometry:"""
        #pragma varyings
        float2 seaPosition;
        #pragma body
        out.seaPosition=_geometry.position.xy;
        """,.surface:"""
        #pragma body
        float2 p=in.seaPosition;
        float t=scn_frame.time;
        float shore=smoothstep(290.0,415.0,p.x);
        float swell=sin(p.y*0.21+t*0.9+sin(p.x*0.05))*0.5+sin(p.y*0.07-t*0.5+p.x*0.03)*0.5;
        float3 deep=float3(0.015,0.09,0.17), mid=float3(0.03,0.26,0.36), shallow=float3(0.12,0.55,0.55);
        float3 water=mix(deep,mid,smoothstep(0.0,0.6,shore));
        water=mix(water,shallow,smoothstep(0.6,1.0,shore))*(0.92+swell*0.08);
        // Breaking foam along the beach line, broken up by travelling crests.
        float edge=smoothstep(392.0,405.0,p.x)*(1.0-smoothstep(408.0,416.0,p.x));
        float crest=smoothstep(0.55,0.95,sin(p.y*0.45+t*1.6+p.x*0.6)*0.5+0.5);
        float foam=clamp(edge*(0.45+crest*0.7),0.0,1.0);
        _surface.diffuse.rgb=mix(water,float3(0.92,0.96,0.97),foam);
        _surface.roughness=mix(0.06,0.6,foam);
        """]
        plane.materials=[m];let node=SCNNode(geometry:plane);node.eulerAngles.x = -.pi/2;node.position=SCNVector3(-580,-0.3,0)
        // Scroll the wave normals so the surface moves and sparkles.
        node.runAction(.repeatForever(.customAction(duration:60) { _,elapsed in
            var transform=SCNMatrix4MakeScale(110,110,1);transform.m41=Float(elapsed)*0.35;transform.m42=Float(elapsed)*0.22
            m.normal.contentsTransform=transform
        }))
        node.castsShadow=false
        return node
    }

}
