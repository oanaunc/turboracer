import SceneKit
import UIKit

/// Speed and impact effects layered onto the player car and chase camera:
/// nitro flames, drift smoke, skid marks, contact sparks, speed streaks,
/// camera shake and district colour grading. All textures are generated.
@MainActor final class RaceEffects {
    private let flames:[SCNParticleSystem]
    private let smoke:[SCNParticleSystem]
    private let streaks:SCNParticleSystem
    private let sparkBurst:SCNParticleSystem
    private let sparkEmitter=SCNNode()
    private let pickupBurst:SCNParticleSystem
    private let pickupEmitter=SCNNode()
    private var marks:[SCNNode]=[]
    private var nextMark=0
    private var markTimer=0.0
    private var shake=0.0
    private let rearTrack:Float
    private let rearAxle:Float
    private let tailZ:Float
    private let grade:(saturation:CGFloat,contrast:CGFloat,vignette:CGFloat)

    private static let softDot:UIImage=UIGraphicsImageRenderer(size:CGSize(width:64,height:64)).image { context in
        let colors=[UIColor.white.cgColor,UIColor(white:1,alpha:0.6).cgColor,UIColor.clear.cgColor]
        let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:[0,0.4,1])!
        context.cgContext.drawRadialGradient(gradient,startCenter:CGPoint(x:32,y:32),startRadius:0,endCenter:CGPoint(x:32,y:32),endRadius:32,options:[])
    }
    private static let skid:UIImage=UIGraphicsImageRenderer(size:CGSize(width:32,height:128)).image { context in
        // Rubber deposit with soft edges and tread banding.
        for y in stride(from:0,to:128,by:4) {
            UIColor(white:0.02,alpha:y%8==0 ? 0.62:0.48).setFill()
            context.fill(CGRect(x:4,y:y,width:24,height:4))
        }
        UIColor(white:0.02,alpha:0.22).setFill();context.fill(CGRect(x:0,y:0,width:4,height:128));context.fill(CGRect(x:28,y:0,width:4,height:128))
    }

    init(car:SCNNode,camera:SCNNode,parent:SCNNode,environment:Int) {
        let b=car.boundingBox
        tailZ=b.min.z+0.05;rearTrack=(b.max.x-b.min.x)*0.36;rearAxle=b.min.z+(b.max.z-b.min.z)*0.2
        grade=[(1.1,0.04,0.4),(1.15,0.06,0.6),(1.08,0.05,0.48),(1.03,0.03,0.42)][max(0,min(3,environment))]

        var flameSystems:[SCNParticleSystem]=[]
        for side:Float in [-0.45,0.45] {
            let core=SCNParticleSystem()
            core.particleImage=Self.softDot;core.blendMode = .additive;core.birthRate=0;core.particleLifeSpan=0.16;core.particleLifeSpanVariation=0.05
            core.particleSize=0.32;core.particleSizeVariation=0.08;core.particleVelocity=9;core.particleVelocityVariation=2;core.spreadingAngle=6
            core.emittingDirection=SCNVector3(0,0,-1);core.isAffectedByGravity=false;core.isLightingEnabled=false
            core.particleColor=UIColor(red:0.45,green:0.8,blue:1,alpha:1)
            let ramp=SCNParticlePropertyController(animation:{
                let a=CAKeyframeAnimation();a.values=[UIColor(red:0.6,green:0.9,blue:1,alpha:1),UIColor(red:1,green:0.55,blue:0.18,alpha:0.9),UIColor(red:0.9,green:0.2,blue:0.05,alpha:0)];a.keyTimes=[0,0.35,1];return a
            }())
            let shrink=SCNParticlePropertyController(animation:{
                let a=CAKeyframeAnimation();a.values=[1.0,0.7,0.2];a.keyTimes=[0,0.5,1];return a
            }())
            core.propertyControllers=[.color:ramp,.size:shrink]
            let node=SCNNode();node.position=SCNVector3(side,0.42,tailZ);node.addParticleSystem(core);car.addChildNode(node)
            flameSystems.append(core)
        }
        flames=flameSystems

        var smokeSystems:[SCNParticleSystem]=[]
        for side:Float in [-1,1] {
            let s=SCNParticleSystem()
            s.particleImage=Self.softDot;s.blendMode = .alpha;s.birthRate=0;s.particleLifeSpan=1.6;s.particleLifeSpanVariation=0.4
            s.particleSize=0.7;s.particleSizeVariation=0.3;s.particleVelocity=1.4;s.particleVelocityVariation=0.8;s.spreadingAngle=55
            s.emittingDirection=SCNVector3(0,0.4,-1);s.acceleration=SCNVector3(0,0.6,0);s.isLightingEnabled=false
            s.particleColor=UIColor(white:0.92,alpha:0.6)
            let grow=SCNParticlePropertyController(animation:{
                let a=CAKeyframeAnimation();a.values=[0.6,2.2,3.6];a.keyTimes=[0,0.4,1];return a
            }())
            s.propertyControllers=[.size:grow]
            // Smoke stays in the world so it trails behind the moving car.
            s.particleDiesOnCollision=false
            let node=SCNNode();node.position=SCNVector3(side*rearTrack,0.25,rearAxle);node.addParticleSystem(s);car.addChildNode(node)
            smokeSystems.append(s)
        }
        smoke=smokeSystems

        streaks=SCNParticleSystem()
        streaks.particleImage=Self.softDot;streaks.blendMode = .additive;streaks.birthRate=0;streaks.particleLifeSpan=0.35
        streaks.particleSize=0.03;streaks.stretchFactor=0.09;streaks.particleVelocity=70;streaks.particleVelocityVariation=20
        streaks.emittingDirection=SCNVector3(0,0,1);streaks.spreadingAngle=0;streaks.isLightingEnabled=false
        streaks.emitterShape=SCNTube(innerRadius:2.6,outerRadius:5.5,height:1);streaks.birthLocation = .volume
        streaks.particleColor=UIColor(white:1,alpha:0.5);streaks.isLocal=true
        let streakNode=SCNNode();streakNode.position=SCNVector3(0,0,-30);streakNode.eulerAngles.x = .pi/2;streakNode.addParticleSystem(streaks);camera.addChildNode(streakNode)

        sparkBurst=SCNParticleSystem()
        sparkBurst.particleImage=Self.softDot;sparkBurst.blendMode = .additive;sparkBurst.birthRate=0;sparkBurst.loops=true
        sparkBurst.particleLifeSpan=0.45;sparkBurst.particleLifeSpanVariation=0.2;sparkBurst.particleSize=0.06;sparkBurst.stretchFactor=0.04
        sparkBurst.particleVelocity=9;sparkBurst.particleVelocityVariation=5;sparkBurst.spreadingAngle=75;sparkBurst.emittingDirection=SCNVector3(0,1,0)
        sparkBurst.isAffectedByGravity=true;sparkBurst.acceleration=SCNVector3(0,-14,0);sparkBurst.isLightingEnabled=false
        sparkBurst.particleColor=UIColor(red:1,green:0.75,blue:0.3,alpha:1)
        sparkEmitter.addParticleSystem(sparkBurst);parent.addChildNode(sparkEmitter)

        pickupBurst=SCNParticleSystem()
        pickupBurst.particleImage=Self.softDot;pickupBurst.blendMode = .additive;pickupBurst.birthRate=0;pickupBurst.loops=true
        pickupBurst.particleLifeSpan=0.6;pickupBurst.particleLifeSpanVariation=0.2;pickupBurst.particleSize=0.12;pickupBurst.particleSizeVariation=0.06
        pickupBurst.particleVelocity=7;pickupBurst.particleVelocityVariation=3;pickupBurst.spreadingAngle=180;pickupBurst.isLightingEnabled=false
        pickupBurst.particleColor=UIColor(red:0.45,green:0.97,blue:1,alpha:1);pickupBurst.dampingFactor=2.5
        pickupEmitter.addParticleSystem(pickupBurst);parent.addChildNode(pickupEmitter)

        let markMaterial=SCNMaterial();markMaterial.lightingModel = .constant;markMaterial.diffuse.contents=Self.skid
        markMaterial.writesToDepthBuffer=false;markMaterial.blendMode = .alpha;markMaterial.isDoubleSided=true
        let plane=SCNPlane(width:0.3,height:1.8);plane.materials=[markMaterial]
        for _ in 0..<220 {
            // The plane lies flat in a child so the holder only needs yaw.
            let flat=SCNNode(geometry:plane);flat.eulerAngles.x = -.pi/2;flat.castsShadow=false;flat.renderingOrder=5
            let n=SCNNode();n.addChildNode(flat);n.isHidden=true;parent.addChildNode(n);marks.append(n)
        }

        if let lens=camera.camera {
            lens.saturation=grade.saturation;lens.contrast=grade.contrast
            lens.vignettingPower=0.9;lens.vignettingIntensity=grade.vignette
            // SceneKit motion blur smears the chased car itself; speed is
            // conveyed by streaks, field of view and colour fringing instead.
            lens.motionBlurIntensity=0
            lens.bloomIntensity=environment==1 ? 0.55:0.3;lens.bloomThreshold=environment==1 ? 0.75:0.95;lens.bloomBlurRadius=10
        }
    }

    /// Called once per simulation frame after the car is placed.
    func update(dt:Double,car:SCNNode,camera:SCNNode,speed:Double,maxSpeed:Double,boosting:Bool,shockwave:Bool=false,drifting:Bool,steering:Double,offRoad:Bool) {
        let pace=max(0,min(1.4,speed/max(1,maxSpeed)))
        for f in flames {f.birthRate=boosting ? (shockwave ? 220:140):0;f.particleSize=shockwave ? 0.45:0.32;f.particleColor=shockwave ? UIColor(red:0.85,green:0.5,blue:1,alpha:1):UIColor(red:0.45,green:0.8,blue:1,alpha:1)}
        let sliding=drifting && abs(steering)>0.15 && speed>20
        let smokeRate:CGFloat=sliding ? 60 : offRoad && speed>15 ? 30 : 0
        for s in smoke {s.birthRate=smokeRate;s.particleColor=offRoad && !sliding ? UIColor(red:0.66,green:0.56,blue:0.42,alpha:0.6) : UIColor(white:0.92,alpha:0.6)}
        streaks.birthRate=CGFloat(boosting ? 260 : pace>0.92 ? 60 : 0)

        if sliding && !offRoad {
            markTimer += dt*speed
            if markTimer>1.6 {
                markTimer=0
                for side:Float in [-1,1] {
                    let p=car.convertPosition(SCNVector3(side*rearTrack,0,rearAxle),to:nil)
                    let mark=marks[nextMark];nextMark=(nextMark+1)%marks.count
                    mark.position=SCNVector3(p.x,0.118,p.z);mark.eulerAngles=SCNVector3(0,car.eulerAngles.y,0);mark.isHidden=false
                }
            }
        }

        if let lens=camera.camera {
            lens.colorFringeStrength=boosting ? 0.6:0;lens.colorFringeIntensity=boosting ? 0.5:0
            lens.vignettingIntensity=grade.vignette+(boosting ? 0.25:0)
        }
        if shake>0 {
            shake=max(0,shake-dt*2.6)
            let t=CACurrentMediaTime()*47
            let amount=Float(shake*shake)*0.28
            camera.position.x += Float(sin(t))*amount;camera.position.y += Float(cos(t*1.3))*amount*0.7
        }
    }

    /// Sparks at a contact point plus a short camera shake.
    func impact(at point:SCNVector3,strength:Double) {
        sparkEmitter.position=point
        sparkBurst.birthRate=0
        sparkBurst.reset()
        sparkBurst.birthRate=400
        DispatchQueue.main.asyncAfter(deadline:.now()+0.08) { [sparkBurst] in sparkBurst.birthRate=0 }
        shake=max(shake,min(1,strength))
    }
    /// Cyan burst where a memory chip is collected.
    func collect(at point:SCNVector3) {
        pickupEmitter.position=point
        pickupBurst.reset();pickupBurst.birthRate=900
        DispatchQueue.main.asyncAfter(deadline:.now()+0.06) { [pickupBurst] in pickupBurst.birthRate=0 }
    }
    func stop() {
        for f in flames {f.birthRate=0};for s in smoke {s.birthRate=0};streaks.birthRate=0;sparkBurst.birthRate=0
    }
}
