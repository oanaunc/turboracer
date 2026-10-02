import SceneKit
import UIKit
import SwiftUI

extension UIColor {
    convenience init(hex: UInt32) { self.init(red: CGFloat((hex>>16)&255)/255, green: CGFloat((hex>>8)&255)/255, blue: CGFloat(hex&255)/255, alpha: 1) }
}
func vector(_ p: SIMD3<Float>) -> SCNVector3 { SCNVector3(p.x,p.y,p.z) }
func material(_ color: UInt32, glow: Bool = false) -> SCNMaterial {
    let m = SCNMaterial(); m.diffuse.contents = UIColor(hex: color); m.lightingModel = .physicallyBased; m.roughness.contents = 0.38; m.metalness.contents = 0.3
    if glow { m.emission.contents = UIColor(hex: color) }
    return m
}
@MainActor final class RaceEngine: ObservableObject {
    @Published var speed = 0.0; @Published var lap = 1; @Published var position = 4
    @Published var elapsed = 0.0; @Published var driftScore = 0; @Published var nitro = 1.0
    @Published var countdown = 3; @Published var paused = false; @Published var result: RaceResult?
    @Published var collected = 0; @Published var sparkMessage = ""
    @Published var offRoad = false; @Published var boosting = false; @Published var combo = 1
    var steering = 0.0; var braking = false; var drifting = false; var nitroHeld = false
    let circuit: Circuit; let mode: RaceMode; let car: Car; let upgrade: Int
    let sensitivity: Double; let haptics: Bool; private let audio: CarAudio
    let scene = SCNScene(); private let world = SCNNode(); private let trackLength: Double; let camera = SCNNode(); let player: SCNNode
    private var rivals: [SCNNode] = []; private var rivalProgress = [-0.008,-0.016,-0.024]
    private var sparks: [SCNNode] = []; private var sparkCollected = Set<Int>(); private var messageTimer = 0.0
    private var progress = 0.0; private var lane = 0.0; private var lateral = 0.0
    private var timer: Timer?; private var lastTime = 0.0; private var startTime = 0.0
    private var countdownTime = 0.0; private var driftFraction = 0.0; private var driftChain = 0.0; private var collisionCooldown = 0.0
    var totalLaps: Int { mode == .circuit ? 2 : 1 }
    init(circuit: Circuit, mode: RaceMode, car: Car, upgrade: Int, sensitivity: Double, haptics: Bool, sounds: Bool = false) {
        self.circuit = circuit; self.trackLength = circuit.length; self.mode = mode; self.car = car; self.upgrade = upgrade
        self.sensitivity = sensitivity; self.haptics = haptics; audio = CarAudio(enabled:sounds); player = Self.makeCar(car)
        buildWorld(); scene.rootNode.addChildNode(player); camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 64; camera.camera?.zFar = 1500
        camera.camera?.wantsHDR = true; camera.camera?.bloomIntensity = 0.12; camera.camera?.bloomThreshold = 0.8
        scene.rootNode.addChildNode(camera)
        if mode == .circuit { for i in 0..<3 { let n = Self.makeCar(Car.all[(i+1)%6]); rivals.append(n); scene.rootNode.addChildNode(n) } }
        placeCars(); updateCamera(dt: 1)
    }
    func start() {
        guard timer == nil else { return }; startTime = CACurrentMediaTime(); lastTime = startTime
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
    }
    func stop() { audio.stop(); timer?.invalidate(); timer = nil; steering = 0; braking = false; drifting = false; nitroHeld = false }
    func setPaused(_ value: Bool) { if value { audio.stop() }; paused = value; steering = 0; braking = false; drifting = false; nitroHeld = false; lastTime = CACurrentMediaTime() }
    private func tick() {
        let now = CACurrentMediaTime(); let dt = min(0.1,now-lastTime); lastTime = now
        advance(dt:dt)
    }
    func advance(dt:Double) {
        guard !paused, result == nil else { return }
        if countdown > 0 { countdownTime += dt; let next = max(0,3-Int(countdownTime)); if next != countdown { countdown = next; feedback() }; return }
        elapsed += dt; messageTimer = max(0,messageTimer-dt); if messageTimer == 0 { sparkMessage = "" }; collisionCooldown = max(0,collisionCooldown-dt)
        let maxSpeed = car.speed + Double(upgrade)*3
        boosting = nitroHeld && nitro > 0.015 && !braking && !offRoad
        nitro = max(0,min(1,nitro + dt*(boosting ? -0.27 : drifting ? 0.10 : 0.035)))
        let desired = braking ? maxSpeed*0.30 : (offRoad ? maxSpeed*0.52 : maxSpeed*(boosting ? 1.38 : 1))
        speed += (desired-speed)*min(1,dt*(braking ? 3 : 0.65))
        audio.update(speed:speed,boost:boosting)
        lateral += (steering*sensitivity*car.handling*(drifting ? 10 : 7)-lateral)*min(1,dt*5)
        let bend = Double(atan2(sin(circuit.heading(progress+0.002)-circuit.heading(progress)),cos(circuit.heading(progress+0.002)-circuit.heading(progress))))
        let outward = min(2,max(-2,bend*65))*pow(speed/maxSpeed,2)
        lane = max(-12,min(12,lane+(lateral+outward)*dt))
        offRoad = abs(lane)>8.1
        let turnA = circuit.heading(progress), turnB = circuit.heading(progress+0.001)
        let curve = abs(Double(atan2(sin(turnB-turnA),cos(turnB-turnA))))
        if drifting && speed > 23 && abs(steering)>0.18 && !offRoad {
            driftChain += dt; combo = min(5,1+Int(driftChain/2)); driftFraction += dt*(24+curve*1000)*Double(combo)
            driftScore = Int(driftFraction)
        } else { driftChain = 0; combo = 1 }
        progress += speed*dt/trackLength
        lap = min(totalLaps,Int(progress)+1)
        for i in rivals.indices {
            let rivalSpeed = maxSpeed * (0.88 + Double(i)*0.023 + 0.025*sin(elapsed*0.6+Double(i)))
            rivalProgress[i] += rivalSpeed*dt/trackLength
            let rivalLane = Double(i-1)*4
            if abs(progress-rivalProgress[i])*trackLength < 4.5 && abs(lane-rivalLane)<2.1 && collisionCooldown == 0 {
                speed *= 0.72; collisionCooldown = 1; lane += lane >= rivalLane ? 1.8 : -1.8; feedback()
            }
        }
        position = 1+rivalProgress.filter { $0>progress }.count
        for i in sparks.indices where !sparkCollected.contains(i) {
            let location = Double(i+1)/13
            let distance = abs((progress-floor(progress))-location)*trackLength
            let sparkLane = Double((i%3)-1)*5
            sparks[i].eulerAngles.y += Float(dt*1.6)
            if distance < 4.5 && abs(lane-sparkLane) < 2.3 {
                audio.collect(); sparkCollected.insert(i); sparks[i].isHidden=true; collected += 1; nitro=min(1,nitro+0.12)
                sparkMessage = "MEMORY SPARK +35 • NITRO RESTORED"; messageTimer=2; feedback()
            }
        }
        placeCars(); updateCamera(dt: dt)
        if progress >= Double(totalLaps) { finish() }
    }
    private func finish() {
        let stars: Int
        switch mode {
        case .circuit: stars = max(0,4-position)
        case .sprint: let target = trackLength / (car.speed*0.83); stars = elapsed < target ? 3 : elapsed < target*1.16 ? 2 : elapsed < target*1.4 ? 1 : 0
        case .drift: stars = driftScore >= 1600 ? 3 : driftScore >= 850 ? 2 : driftScore >= 300 ? 1 : 0
        }
        let reward = 150 + stars*180 + min(400,driftScore/8) + collected*35
        result = RaceResult(position: mode == .circuit ? position : stars == 3 ? 1 : 2, time: elapsed, drift: driftScore, credits: reward, stars: stars, collected: collected)
        feedback(); stop()
    }
    private func feedback() { if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    private func placeCars() {
        player.position = vector(circuit.point(progress,lane: lane)); player.eulerAngles.y = circuit.heading(progress)+Float(lateral*0.022*(drifting ? 2 : 1))
        for i in rivals.indices { rivals[i].position = vector(circuit.point(rivalProgress[i],lane: Double(i-1)*4)); rivals[i].eulerAngles.y = circuit.heading(rivalProgress[i]) }
    }
    private func updateCamera(dt: Double) {
        let p = circuit.point(progress,lane: lane); let heading = circuit.heading(progress)
        let distance: Float = boosting ? 17 : 14
        let target = SCNVector3(p.x-sin(heading)*distance, 8, p.z-cos(heading)*distance)
        let blend = Float(min(1,dt*5)); camera.position = SCNVector3(camera.position.x+(target.x-camera.position.x)*blend,camera.position.y+(target.y-camera.position.y)*blend,camera.position.z+(target.z-camera.position.z)*blend)
        let ahead = SIMD3<Float>(p.x+sin(heading)*6,1.2,p.z+cos(heading)*6)
        camera.look(at: SCNVector3(ahead.x,1.2,ahead.z), up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,-1)); camera.camera?.fieldOfView = boosting ? 73 : 64
    }
    static func makeCar(_ car: Car) -> SCNNode {
        let root = SCNNode(); let paint = material(car.color); paint.metalness.contents = 0.75; paint.roughness.contents = 0.22
        func box(_ w: CGFloat,_ h: CGFloat,_ l: CGFloat,_ x: Float,_ y: Float,_ z: Float,_ mat: SCNMaterial,_ bevel: CGFloat = 0.12) {
            let g = SCNBox(width:w,height:h,length:l,chamferRadius:bevel); g.materials=[mat]; let n=SCNNode(geometry:g); n.position=SCNVector3(x,y,z); root.addChildNode(n)
        }
        let dark = material(0x091626); let chrome = material(0xD8E8EF)
        let widths: [Float] = [1,0.96,1.06,1.02,1.08,0.97]
        let lengths: [Float] = [1,0.91,1.07,1.03,1.10,1.04]
        let width = widths[car.id], length = lengths[car.id]
        let sections: [(Float,Float,Float)] = [(2.2,0.86,0.70),(1.55,1.02,0.84),(0.55,1.02,0.92),(-0.95,1.02,0.88),(-1.65,1.04,0.83),(-2.2,0.93,0.72)]
        var vertices: [SCNVector3] = []; var indices: [Int32] = []
        for (z,w,y) in sections {
            vertices += [SCNVector3(-w*width,0.38,z*length),SCNVector3(-w*width,y-0.13,z*length),SCNVector3(-w*0.88*width,y,z*length),SCNVector3(w*0.88*width,y,z*length),SCNVector3(w*width,y-0.13,z*length),SCNVector3(w*width,0.38,z*length)]
        }
        for ring in 0..<(sections.count-1) { for side in 0..<6 { let a=Int32(ring*6+side),b=Int32(ring*6+(side+1)%6),c=a+6,d=b+6; indices += [a,c,b,b,c,d] } }
        indices += [0,1,2,0,2,3,0,3,4,0,4,5,30,32,31,30,33,32,30,34,33,30,35,34]
        var expanded: [SCNVector3] = []; var normals: [SCNVector3] = []
        for i in stride(from:0,to:indices.count,by:3) {
            let a=vertices[Int(indices[i])], b=vertices[Int(indices[i+1])], c=vertices[Int(indices[i+2])]
            let u=SIMD3<Float>(b.x-a.x,b.y-a.y,b.z-a.z), v=SIMD3<Float>(c.x-a.x,c.y-a.y,c.z-a.z)
            let cross=SIMD3<Float>(u.y*v.z-u.z*v.y,u.z*v.x-u.x*v.z,u.x*v.y-u.y*v.x)
            let magnitude=max(0.001,sqrt(cross.x*cross.x+cross.y*cross.y+cross.z*cross.z))
            let normal=SCNVector3(cross.x/magnitude,cross.y/magnitude,cross.z/magnitude)
            expanded += [a,b,c]; normals += [normal,normal,normal]
        }
        let geo=SCNGeometry(sources:[SCNGeometrySource(vertices:expanded),SCNGeometrySource(normals:normals)],elements:[SCNGeometryElement(indices:Array(0..<Int32(expanded.count)),primitiveType:.triangles)]); paint.isDoubleSided=true; geo.materials=[paint]; root.addChildNode(SCNNode(geometry:geo))
        box(CGFloat(width)*2.15,0.12,CGFloat(length)*3.6,0,0.33,0,dark)

        // Angled glasshouse and sculpted roof, rather than a rectangular cabin.
        func quad(_ a:SCNVector3,_ b:SCNVector3,_ c:SCNVector3,_ d:SCNVector3,_ mat:SCNMaterial) {
            let u=SIMD3<Float>(b.x-a.x,b.y-a.y,b.z-a.z),v=SIMD3<Float>(c.x-a.x,c.y-a.y,c.z-a.z)
            let cross=SIMD3<Float>(u.y*v.z-u.z*v.y,u.z*v.x-u.x*v.z,u.x*v.y-u.y*v.x)
            let length=max(0.001,sqrt(cross.x*cross.x+cross.y*cross.y+cross.z*cross.z))
            let normal=SCNVector3(cross.x/length,cross.y/length,cross.z/length)
            let geo=SCNGeometry(sources:[SCNGeometrySource(vertices:[a,b,c,d]),SCNGeometrySource(normals:[normal,normal,normal,normal])],elements:[SCNGeometryElement(indices:[Int32(0),1,2,0,2,3],primitiveType:.triangles)])
            mat.isDoubleSided=true; geo.materials=[mat]; root.addChildNode(SCNNode(geometry:geo))
        }
        let glass=material(0x213B51); glass.metalness.contents=0.9; glass.roughness.contents=0.05
        let roofY: Float=car.id==4 ? 1.26 : 1.42
        let frontL=SCNVector3(-0.83,0.90,0.70),frontR=SCNVector3(0.83,0.90,0.70)
        let roofFL=SCNVector3(-0.66,roofY,0.06),roofFR=SCNVector3(0.66,roofY,0.06)
        let roofBL=SCNVector3(-0.67,roofY,-0.98),roofBR=SCNVector3(0.67,roofY,-0.98)
        let rearL=SCNVector3(-0.84,0.86,-1.63),rearR=SCNVector3(0.84,0.86,-1.63)
        quad(frontL,frontR,roofFR,roofFL,glass); quad(roofFL,roofFR,roofBR,roofBL,paint)
        quad(roofBL,roofBR,rearR,rearL,glass); quad(frontL,roofFL,roofBL,rearL,glass); quad(frontR,rearR,roofBR,roofFR,glass)
        for x:Float in [-1.12,1.12] { box(0.22,0.12,0.32,x,0.96,0.45,paint,0.04) }
        for x:Float in [-0.89,0.89] { box(0.05,0.12,2.1,x,0.85,-0.4,paint,0.02) }
        box(0.9,0.09,0.1,0,0.55,2.22,dark,0.02)
        box(2.16,0.15,0.32,0,1.1,-1.8,dark)
        box(0.12,0.38,0.12,-0.8,0.92,-1.8,dark); box(0.12,0.38,0.12,0.8,0.92,-1.8,dark)
        box(1.5,0.08,0.2,0,0.48,2.16,dark)
        for x: Float in [-0.7,0.7] {
            box(0.58,0.11,0.08,x,0.76,2.15,material(0xB3FFFF,glow:true),0.025)
            box(0.62,0.10,0.08,x,0.75,-2.15,material(0xFF335F,glow:true),0.025)
            box(0.14,0.012,1.0,x*0.42,0.91,1.09,dark,0.006)
        }
        for x: Float in [-1.05,1.05] { for z: Float in [-1.3,1.25] {
            let g=SCNCylinder(radius:0.46,height:0.32); g.materials=[material(0x10111A)]
            let n=SCNNode(geometry:g); n.eulerAngles.z = .pi/2; n.position=SCNVector3(x,0.46,z); root.addChildNode(n)
            let rim=SCNCylinder(radius:0.30,height:0.34); rim.materials=[chrome]; let r=SCNNode(geometry:rim); r.eulerAngles.z = .pi/2; r.position=n.position; root.addChildNode(r)
            for spoke in 0..<5 { let sg=SCNBox(width:0.36,height:0.04,length:0.55,chamferRadius:0.01); sg.materials=[dark]; let sn=SCNNode(geometry:sg); sn.position=n.position; sn.eulerAngles.x=Float(spoke) * .pi/5; root.addChildNode(sn) }
            let hub=SCNNode(geometry:SCNCylinder(radius:0.1,height:0.37)); hub.geometry?.materials=[paint]; hub.eulerAngles.z = .pi/2; hub.position=n.position; root.addChildNode(hub)
        } }
        if car.id>=3 { box(0.15,0.10,1.1,-0.66,0.86,-1.55,dark); box(0.15,0.10,1.1,0.66,0.86,-1.55,dark) }
        if car.id==5 { box(0.06,0.6,1.4,0,1.0,-1.6,paint) }
        return root
    }
    private func buildWorld() {
        scene.background.contents = Self.skyImage(circuit)
        scene.lightingEnvironment.contents = Self.skyImage(circuit); scene.lightingEnvironment.intensity = 0.65
        scene.fogColor = UIColor(hex:circuit.sky); scene.fogStartDistance = 170; scene.fogEndDistance = 520
        let ambient=SCNNode(); ambient.light=SCNLight(); ambient.light?.type = .ambient; ambient.light?.color=UIColor(hex:0xB2A6CF); ambient.light?.intensity=700; scene.rootNode.addChildNode(ambient)
        let sun=SCNNode(); sun.light=SCNLight(); sun.light?.type = .directional; sun.light?.color=UIColor(hex:0xFFD4AD); sun.light?.intensity=1100; sun.eulerAngles=SCNVector3(-0.8,-0.6,0); scene.rootNode.addChildNode(sun)
        let ground=SCNFloor(); ground.reflectivity=0.06; ground.materials=[material(circuit.ground)]; world.addChildNode(SCNNode(geometry:ground))
        let roadMat=material(0x202635), stripe=material(0xC6CDD0), pink=material(0xF970AE,glow:true), aqua=material(0x62E9DB,glow:true)
        for i in 0..<12 {
            let n=SCNNode(geometry:SCNTorus(ringRadius:0.85,pipeRadius:0.12)); n.geometry?.materials=[material(0xFFD76E,glow:true)]; n.eulerAngles.x = .pi/2
            let p=circuit.point(Double(i+1)/13,lane:Double(i%3-1)*5); n.position=SCNVector3(p.x,1.65,p.z)
            let core=SCNNode(geometry:SCNSphere(radius:0.28)); core.geometry?.materials=[material(0xFFF0B2,glow:true)]; n.addChildNode(core); sparks.append(n); scene.rootNode.addChildNode(n)
        }
        addAtmosphere()
        let count=240
        for i in 0..<count {
            let t=Double(i)/Double(count), a=circuit.point(t), b=circuit.point(Double(i+1)/Double(count))
            let distance=CGFloat(sqrt(pow(b.x-a.x,2)+pow(b.z-a.z,2)))
            let heading=atan2(b.x-a.x,b.z-a.z)
            let n=SCNNode(geometry:SCNBox(width:18,height:0.12,length:distance+0.6,chamferRadius:0)); n.geometry?.materials=[roadMat]; n.position=SCNVector3((a.x+b.x)/2,0.04,(a.z+b.z)/2); n.eulerAngles.y=heading; world.addChildNode(n)
            for side in [-1.0,1.0] {
                let edge=circuit.point(t,lane:side*9.1); let rail=SCNNode(geometry:SCNBox(width:0.20,height:0.24,length:distance+0.7,chamferRadius:0.04)); rail.geometry?.materials=[side<0 ? pink : aqua]; rail.position=SCNVector3(edge.x,0.25,edge.z); rail.eulerAngles.y=heading; world.addChildNode(rail)
                if i%2==0 { let mark=SCNNode(geometry:SCNBox(width:0.12,height:0.02,length:distance*0.65,chamferRadius:0)); mark.geometry?.materials=[stripe]; let p=circuit.point(t,lane:side*3); mark.position=SCNVector3(p.x,0.12,p.z); mark.eulerAngles.y=heading; world.addChildNode(mark) }
            }
            if i%6==0 { scenery(t,index:i) }
        }
        // Checkered finish and luminous gantry.
        for x in 0..<18 { for z in 0..<4 { let g=SCNBox(width:1,height:0.03,length:1,chamferRadius:0); g.materials=[material((x+z)%2==0 ? 0xF1EFE5 : 0x121621)]; let n=SCNNode(geometry:g); let p=circuit.point(Double(z)*0.001,lane:Double(x)-8.5); n.position=SCNVector3(p.x,0.14,p.z); n.eulerAngles.y=circuit.heading(0); world.addChildNode(n) } }
        let gate=SCNNode(); gate.position=vector(circuit.point(0)); gate.eulerAngles.y=circuit.heading(0)
        for x: Float in [-10,10] { let n=SCNNode(geometry:SCNBox(width:0.6,height:8,length:0.6,chamferRadius:0.1)); n.geometry?.materials=[aqua]; n.position=SCNVector3(x,4,0); gate.addChildNode(n) }
        let banner=SCNNode(geometry:SCNBox(width:21,height:1.5,length:0.4,chamferRadius:0.1)); banner.geometry?.materials=[material(0x171A30)]; banner.position=SCNVector3(0,8,0); gate.addChildNode(banner)
        let text=SCNText(string:"AFTERLIGHT",extrusionDepth:0.015); text.font=UIFont.boldSystemFont(ofSize:1); text.flatness=0.2; text.materials=[aqua]; let label=SCNNode(geometry:text); label.scale=SCNVector3(1.15,1.15,1.15); label.position=SCNVector3(-4,7.5,-0.25); label.eulerAngles.y = .pi; gate.addChildNode(label); world.addChildNode(gate)
        scene.rootNode.addChildNode(world.flattenedClone())
    }
    private func addAtmosphere() {
        // Surrounding world gives each region its own recognizable silhouette.
        if circuit.id==0 {
            let water=SCNPlane(width:850,height:850); let m=material(0x28758B); m.metalness.contents=0.85; m.roughness.contents=0.1; water.materials=[m]
            let n=SCNNode(geometry:water); n.eulerAngles.x = -.pi/2; n.position=SCNVector3(-400,-0.08,0); world.addChildNode(n)
            for i in 0..<9 { let yacht=SCNNode(geometry:SCNBox(width:3,height:1,length:10,chamferRadius:0.9)); yacht.geometry?.materials=[material(0xE9DCD3)]; yacht.position=SCNVector3(-180-Float(i)*18,0.5,Float(i*25-100)); yacht.eulerAngles.y=Float(i)*0.2; world.addChildNode(yacht) }
        }
        for i in 0..<22 {
            let angle=Float(i)*2 * .pi/22; let radius: Float=320+Float(i%4)*35
            let h: CGFloat=CGFloat(45+i%6*14)
            let g=SCNCone(topRadius:circuit.id==1 ? 10 : 0,bottomRadius:45,height:h); g.radialSegmentCount=5
            g.materials=[material(circuit.id==2 ? 0xA2656E : 0x596083)]; let n=SCNNode(geometry:g); n.position=SCNVector3(sin(angle)*radius,Float(h)/2-5,cos(angle)*radius); world.addChildNode(n)
        }
        let motes=SCNParticleSystem(); motes.birthRate=circuit.id==1 ? 100 : 30; motes.particleLifeSpan=6; motes.particleSize=circuit.id==1 ? 0.035 : 0.08; motes.particleColor=UIColor(hex:circuit.id==1 ? 0x8EADD3 : 0xFFEBC3); motes.particleVelocity=circuit.id==1 ? 18 : 0.4; motes.spreadingAngle=10; motes.emitterShape=SCNBox(width:260,height:1,length:260,chamferRadius:0); motes.acceleration=SCNVector3(0,circuit.id==1 ? -12 : 0.2,0); motes.blendMode = .additive
        let emitter=SCNNode(); emitter.position=SCNVector3(0,circuit.id==1 ? 30 : 1,0); emitter.addParticleSystem(motes); scene.rootNode.addChildNode(emitter)
        for side: Float in [-0.7,0.7] {
            let exhaust=SCNNode(); exhaust.position=SCNVector3(side,0.4,-2.3)
            let particles=SCNParticleSystem(); particles.birthRate=35; particles.particleLifeSpan=0.18; particles.particleSize=0.12; particles.particleColor=UIColor(hex:car.color); particles.particleVelocity=1.5; particles.spreadingAngle=12; particles.blendMode = .additive; exhaust.addParticleSystem(particles); player.addChildNode(exhaust)
        }
    }
    private func scenery(_ t: Double,index: Int) {
        for side in [-1.0,1.0] {
            let p=circuit.point(t,lane:side*(22+Double(index%4)*6))
            if circuit.id==0 {
                let trunk=SCNNode(geometry:SCNCylinder(radius:0.35,height:10)); trunk.geometry?.materials=[material(0x795563)]; trunk.position=SCNVector3(p.x,5,p.z); trunk.eulerAngles.z=Float(side*0.12); world.addChildNode(trunk)
                for leaf in 0..<6 { let vertices=[SCNVector3(0,0,0),SCNVector3(-0.85,0.35,2.4),SCNVector3(0,0.8,3.3),SCNVector3(0.85,0.35,2.4),SCNVector3(0,-1,6)]
                    let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:Array(repeating:SCNVector3(0,1,0),count:vertices.count))],elements:[SCNGeometryElement(indices:[Int32(0),1,2,0,2,3,1,4,2,2,4,3],primitiveType:.triangles)])
                    let leafMaterial=material(leaf%2==0 ? 0x409C8A : 0x347A79); leafMaterial.isDoubleSided=true; geometry.materials=[leafMaterial]
                    let frond=SCNNode(geometry:geometry); frond.position=SCNVector3(p.x,10,p.z); frond.eulerAngles.y=Float(leaf)*1.047; world.addChildNode(frond) }
            } else if circuit.id==1 {
                let height=CGFloat(12+index%37); let n=SCNNode(geometry:SCNBox(width:10,height:height,length:11,chamferRadius:0.4)); n.geometry?.materials=[material(index%2==0 ? 0x253554 : 0x312844)]; n.position=SCNVector3(p.x,Float(height)/2,p.z); world.addChildNode(n)
                for floor in 0..<Int(height/3) { let band=SCNNode(geometry:SCNBox(width:10.1,height:0.18,length:11.1,chamferRadius:0)); band.geometry?.materials=[material(index%2==0 ? 0x59E8D4 : 0xEC74B9,glow:true)]; band.position=SCNVector3(p.x,Float(floor*3+2),p.z); world.addChildNode(band) }
            } else {
                let h=CGFloat(15+index%23); let rock=SCNNode(geometry:SCNCone(topRadius:circuit.id==2 ? 5 : 0,bottomRadius:15,height:h)); rock.geometry?.materials=[material(circuit.id==2 ? 0xA56858 : 0x7A8D9E)]; rock.position=SCNVector3(p.x,Float(h)/2,p.z); rock.eulerAngles.y=Float(index); world.addChildNode(rock)
                if circuit.id==3 { let snow=SCNNode(geometry:SCNCone(topRadius:0,bottomRadius:6,height:h*0.4)); snow.geometry?.materials=[material(0xDDEDF0)]; snow.position=SCNVector3(p.x,Float(h)*0.8,p.z); world.addChildNode(snow) }
            }
            if index%12==0 { let post=SCNNode(geometry:SCNCylinder(radius:0.12,height:6)); post.geometry?.materials=[material(0x68819A)]; let q=circuit.point(t,lane:side*11); post.position=SCNVector3(q.x,3,q.z); world.addChildNode(post)
                let lamp=SCNNode(geometry:SCNSphere(radius:0.3)); lamp.geometry?.materials=[material(0xFFCD95,glow:true)]; lamp.position=SCNVector3(q.x,6,q.z); world.addChildNode(lamp)
            }
        }
    }
    static func skyImage(_ circuit: Circuit) -> UIImage {
        UIGraphicsImageRenderer(size:CGSize(width:512,height:512)).image { ctx in
            let colors=[UIColor(hex:circuit.sky).cgColor,UIColor(hex:circuit.id==1 ? 0x293662 : 0xC6798A).cgColor,UIColor(hex:0xFFC09B).cgColor]
            let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:[0,0.65,1])!
            ctx.cgContext.drawLinearGradient(gradient,start:.zero,end:CGPoint(x:0,y:512),options:[])
            UIColor(hex:0xFFE2B2).setFill(); ctx.cgContext.fillEllipse(in:CGRect(x:330,y:290,width:100,height:100))
        }
    }
}

struct SceneSurface: UIViewRepresentable {
    let engine: RaceEngine
    func makeUIView(context: Context) -> SCNView { let v=SCNView(); v.scene=engine.scene; v.pointOfView=engine.camera; v.isPlaying=true; v.preferredFramesPerSecond=60; v.antialiasingMode = .multisampling4X; v.backgroundColor = .black; return v }
    func updateUIView(_ uiView: SCNView,context: Context) {}
}
struct CarShowroom: UIViewRepresentable {
    let car: Car
    func makeUIView(context: Context) -> SCNView { let v=SCNView(); v.backgroundColor = .clear; v.autoenablesDefaultLighting=true; v.antialiasingMode = .multisampling4X; v.isPlaying=true; return v }
    func updateUIView(_ v: SCNView,context: Context) {
        guard v.accessibilityIdentifier != car.name else { return }; v.accessibilityIdentifier=car.name
        let s=SCNScene(); let n=RaceEngine.makeCar(car); s.rootNode.addChildNode(n); n.runAction(.repeatForever(.rotateBy(x:0,y:2 * .pi,z:0,duration:22)))
        let camera=SCNNode(); camera.camera=SCNCamera(); camera.camera?.fieldOfView=36; camera.position=SCNVector3(5,2.8,5); camera.look(at:SCNVector3(0,0.5,0)); s.rootNode.addChildNode(camera); v.scene=s; v.pointOfView=camera
    }
}
