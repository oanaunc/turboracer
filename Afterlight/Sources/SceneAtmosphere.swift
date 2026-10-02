import SceneKit
import UIKit

@MainActor enum SceneAtmosphere {
    static func memoryChip() -> SCNNode {
        let root=SCNNode();root.name="memory-chip"
        let graphite=material(0x152C3A);graphite.metalness.contents=0.8;graphite.roughness.contents=0.28
        let edge=material(0x9CB1BB);edge.metalness.contents=0.9;edge.roughness.contents=0.22
        let gold=material(0xFFB84B);gold.metalness.contents=0.7
        let cyan=material(0x46E5FF,glow:true)
        let outline=UIBezierPath();outline.move(to:CGPoint(x:-0.58,y:-0.7))
        for p in [CGPoint(x:0.58,y:-0.7),CGPoint(x:0.58,y:0.38),CGPoint(x:0.26,y:0.7),CGPoint(x:-0.58,y:0.7)] {outline.addLine(to:p)}
        outline.close()
        let shell=SCNShape(path:outline,extrusionDepth:0.2);shell.chamferRadius=0.04;shell.materials=[graphite,graphite,edge,edge,edge]
        root.addChildNode(SCNNode(geometry:shell))
        func detail(_ w:CGFloat,_ h:CGFloat,_ d:CGFloat,_ x:Float,_ y:Float,_ z:Float,_ m:SCNMaterial) {
            let box=SCNBox(width:w,height:h,length:d,chamferRadius:0.012);box.materials=[m]
            let node=SCNNode(geometry:box);node.position=SCNVector3(x,y,z);root.addChildNode(node)
        }
        // Both faces stay readable as the cartridge turns above the road.
        for face:Float in [-1,1] {
            detail(0.74,0.77,0.035,0,0.02,face*0.12,edge)
            detail(0.66,0.69,0.045,0,0.02,face*0.145,graphite)
            for i in 0..<3 {detail(0.075,0.43-Double(i)*0.09,0.025,Float(i-1)*0.17,0.05,face*0.178,cyan)}
            for i in 0..<5 {detail(0.115,0.21,0.025,Float(i-2)*0.19,-0.57,face*0.12,gold)}
        }
        let chip=root.flattenedClone();chip.name="memory-chip";return chip
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
        let m=material(0x187C91);m.metalness.contents=0.18;m.roughness.contents=0.23
        m.normal.contents=SurfaceLibrary.image("water-normal");m.normal.wrapS = .repeat;m.normal.wrapT = .repeat;m.normal.contentsTransform=SCNMatrix4MakeScale(110,110,1);m.normal.intensity=0.5
        m.shaderModifiers=[.geometry:"""
        #pragma varyings
        float2 seaPosition;
        #pragma body
        out.seaPosition=_geometry.position.xy;
        """,.surface:"""
        #pragma body
        float shore=smoothstep(290.0,415.0,in.seaPosition.x);
        float wave=sin(in.seaPosition.y*0.26+scn_frame.time*0.7+sin(in.seaPosition.x*0.08));
        _surface.diffuse.rgb=mix(float3(0.022,0.13,0.23),float3(0.08,0.48,0.49),shore)*(0.94+wave*0.06);
        """]
        plane.materials=[m];let node=SCNNode(geometry:plane);node.eulerAngles.x = -.pi/2;node.position=SCNVector3(-580,-0.3,0);return node
    }
}
