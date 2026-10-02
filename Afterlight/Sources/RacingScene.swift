import SceneKit
import UIKit
import SwiftUI

extension UIColor {
    convenience init(hex: UInt32) { self.init(red: CGFloat((hex>>16)&255)/255, green: CGFloat((hex>>8)&255)/255, blue: CGFloat(hex&255)/255, alpha: 1) }
}
func vector(_ p: SIMD3<Float>) -> SCNVector3 { SCNVector3(p.x,p.y,p.z) }
func material(_ color: UInt32, glow: Bool = false) -> SCNMaterial {
    let m = SCNMaterial(); m.diffuse.contents = UIColor(hex: color); m.lightingModel = .physicallyBased; m.roughness.contents = 0.7; m.metalness.contents = 0.0
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
        camera.camera?.projectionDirection = .horizontal; camera.camera?.fieldOfView = 72; camera.camera?.zFar = 1500
        camera.camera?.wantsHDR = true; camera.camera?.bloomIntensity = 0.12; camera.camera?.bloomThreshold = 1.1
        camera.camera?.exposureOffset = -0.15; camera.camera?.wantsExposureAdaptation = false
        camera.camera?.screenSpaceAmbientOcclusionIntensity = 0.65; camera.camera?.screenSpaceAmbientOcclusionRadius = 2.2
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
        for vehicle in [player]+rivals {
            vehicle.enumerateChildNodes { node,_ in if node.name=="rolling-wheel" {node.eulerAngles.x += Float(speed*dt/0.465)} }
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
    private var chaseHeading:Float?
    private func updateCamera(dt: Double) {
        let p = circuit.point(progress,lane: lane); let heading = circuit.heading(progress)
        var smooth=chaseHeading ?? heading
        let difference=atan2(sin(heading-smooth),cos(heading-smooth));smooth += difference*Float(min(1,dt*8));chaseHeading=smooth
        let distance: Float = boosting ? 10.5 : 9.5
        let target = SCNVector3(p.x-sin(smooth)*distance, 4.3, p.z-cos(smooth)*distance)
        camera.position = target
        let ahead = SIMD3<Float>(p.x+sin(heading)*5,1.0,p.z+cos(heading)*5)
        camera.look(at: SCNVector3(ahead.x,0.6,ahead.z), up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,-1)); camera.camera?.fieldOfView = boosting ? 78 : 72
    }
    static func makeCar(_ car: Car) -> SCNNode {
        if let model=SurfaceLibrary.grandTourer(car) { return model }
        let root = SCNNode(); let paint = SurfaceLibrary.paint(car.color)
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
            let g=SCNCylinder(radius:0.46,height:0.32); g.materials=[SurfaceLibrary.surface("rubber")]
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
        if circuit.id != 1, let sky=Bundle.main.url(forResource:"coast-sky",withExtension:"hdr") { scene.background.contents=sky }
        scene.lightingEnvironment.contents = circuit.id==1 ? Self.skyImage(circuit) : Bundle.main.url(forResource:"coast-light",withExtension:"hdr"); scene.lightingEnvironment.intensity = circuit.id == 1 ? 0.8 : 0.65
        scene.fogColor = UIColor(hex:circuit.sky); scene.fogStartDistance = 260; scene.fogEndDistance = 900
        let ambient=SCNNode(); ambient.light=SCNLight(); ambient.light?.type = .ambient; ambient.light?.color=UIColor(hex:0xCDDCEA); ambient.light?.intensity=circuit.id == 1 ? 350 : 220; scene.rootNode.addChildNode(ambient)
        let sun=SCNNode(); sun.light=SCNLight(); sun.light?.type = .directional; sun.light?.color=UIColor(hex:0xFFD4AD); sun.light?.intensity=circuit.id == 1 ? 700 : 1100; sun.light?.castsShadow=true; sun.light?.shadowMapSize=CGSize(width:2048,height:2048); sun.light?.shadowMode = .deferred; sun.light?.shadowSampleCount=8; sun.light?.shadowRadius=3; sun.light?.maximumShadowDistance=90; sun.light?.orthographicScale=75; sun.light?.shadowColor=UIColor(white:0,alpha:0.35); sun.eulerAngles=SCNVector3(-0.65,-0.5,0); scene.rootNode.addChildNode(sun)
        let distantFloor=SCNFloor();distantFloor.materials=[SurfaceLibrary.surface(circuit.id==2 ? "sand" : "grass")];let distantLand=SCNNode(geometry:distantFloor);distantLand.position.y = -4;world.addChildNode(distantLand)
        world.addChildNode(SceneDressing.terrain(circuit)); world.addChildNode(SceneDressing.promenade(circuit))
        let roadMat=SurfaceLibrary.surface("asphalt"), stripe=material(0xDDDCD1), pink=material(0xC56C55), aqua=material(0xBEC4C4)
        if circuit.id==1 { pink.emission.contents=UIColor(hex:0xDB568C); aqua.emission.contents=UIColor(hex:0x69CFC1) }
        if circuit.id==1 {roadMat.roughness.contents=0.28;roadMat.normal.intensity=0.35}
        buildRoadSurface(roadMat)
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
            // Continuous UV-mapped road replaces overlapping rectangular road slabs.
            for side in [-1.0,1.0] {
                let edge=circuit.point(t,lane:side*9.1); let rail=SCNNode(geometry:SCNBox(width:0.36,height:0.10,length:distance+0.1,chamferRadius:0.02)); rail.geometry?.materials=[side<0 ? pink : aqua]; rail.position=SCNVector3(edge.x,0.17,edge.z); rail.eulerAngles.y=heading; world.addChildNode(rail)
                if i%2==0 { let mark=SCNNode(geometry:SCNBox(width:0.12,height:0.02,length:distance*0.65,chamferRadius:0)); mark.geometry?.materials=[stripe]; let p=circuit.point(t,lane:side*3); mark.position=SCNVector3(p.x,0.12,p.z); mark.eulerAngles.y=heading; world.addChildNode(mark) }
            }
            if i%6==0 { scenery(t,index:i) }
        }
        // Checkered finish and luminous gantry.
        for x in 0..<18 { for z in 0..<4 { let g=SCNBox(width:1,height:0.03,length:1,chamferRadius:0); g.materials=[material((x+z)%2==0 ? 0xF1EFE5 : 0x121621)]; let n=SCNNode(geometry:g); let p=circuit.point(Double(z)/circuit.length,lane:Double(x)-8.5); n.position=SCNVector3(p.x,0.14,p.z); n.eulerAngles.y=circuit.heading(0); world.addChildNode(n) } }
        let gate=SCNNode(); gate.position=vector(circuit.point(0)); gate.eulerAngles.y=circuit.heading(0)
        for x: Float in [-10,10] { let n=SCNNode(geometry:SCNBox(width:0.6,height:8,length:0.6,chamferRadius:0.1)); n.geometry?.materials=[aqua]; n.position=SCNVector3(x,4,0); gate.addChildNode(n) }
        let banner=SCNNode(geometry:SCNBox(width:21,height:1.5,length:0.4,chamferRadius:0.1)); banner.geometry?.materials=[material(0x171A30)]; banner.position=SCNVector3(0,8,0); gate.addChildNode(banner)
        let text=SCNText(string:"AFTERLIGHT",extrusionDepth:0.015); text.font=UIFont.boldSystemFont(ofSize:1); text.flatness=0.2; text.materials=[aqua]; let label=SCNNode(geometry:text); label.scale=SCNVector3(1.15,1.15,1.15); label.position=SCNVector3(-4,7.5,-0.25); label.eulerAngles.y = .pi; gate.addChildNode(label); world.addChildNode(gate)
        scene.rootNode.addChildNode(world)
    }
    private func buildRoadSurface(_ mat:SCNMaterial) {
        let count=480
        var vertices:[SCNVector3]=[],uv:[CGPoint]=[],indices:[Int32]=[]
        var meters=0.0; var previous=circuit.point(0)
        for i in 0...count {
            let t=Double(i)/Double(count), center=circuit.point(t)
            meters += Double(simd_length(center-previous)); previous=center
            for lane in [-9.0,9.0] { let p=circuit.point(t,lane:lane); vertices.append(SCNVector3(p.x,0.105,p.z)); uv.append(CGPoint(x:(lane+9)/5,y:meters/5)) }
            if i<count { let a=Int32(i*2); indices += [a,a+1,a+2,a+1,a+3,a+2] }
        }
        let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:Array(repeating:SCNVector3(0,1,0),count:vertices.count)),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        mat.isDoubleSided=true; geometry.materials=[mat]; world.addChildNode(SCNNode(geometry:geometry))
        // Roadside safety barriers are metal rather than luminous boundary walls.
        let metal=material(0x9FAAAF);metal.metalness.contents=0.75;metal.roughness.contents=0.4
        for i in stride(from:0,to:count,by:4) {
            let t=Double(i)/Double(count), next=Double(i+4)/Double(count)
            for side in [-1.0,1.0] {
                let a=circuit.point(t,lane:side*10.8),b=circuit.point(next,lane:side*10.8)
                let rail=SCNNode(geometry:SCNBox(width:0.12,height:0.36,length:CGFloat(simd_length(b-a)),chamferRadius:0.035));rail.geometry?.materials=[metal];rail.position=SCNVector3((a.x+b.x)/2,0.85,(a.z+b.z)/2);rail.eulerAngles.y=atan2(b.x-a.x,b.z-a.z);world.addChildNode(rail)
                let post=SCNNode(geometry:SCNBox(width:0.09,height:0.9,length:0.09,chamferRadius:0.01));post.geometry?.materials=[metal];post.position=SCNVector3(a.x,0.45,a.z);world.addChildNode(post)
            }
        }
    }
    private func addAtmosphere() {
        // Surrounding world gives each region its own recognizable silhouette.
        if circuit.id==0 {
            let water=SCNPlane(width:1400,height:1400); let m=material(0x28758B); m.metalness.contents=0.35; m.roughness.contents=0.16; m.normal.contents=SurfaceLibrary.image("water-normal"); m.normal.wrapS = .repeat; m.normal.wrapT = .repeat; m.normal.contentsTransform=SCNMatrix4MakeScale(80,80,1); water.materials=[m]
            let n=SCNNode(geometry:water); n.eulerAngles.x = -.pi/2; n.position=SCNVector3(-580,-0.30,0); world.addChildNode(n)
            for i in 0..<9 { let yacht=SCNNode(geometry:SCNBox(width:3,height:1,length:10,chamferRadius:0.9)); yacht.geometry?.materials=[material(0xE9DCD3)]; yacht.position=SCNVector3(-180-Float(i)*18,0.5,Float(i*25-100)); yacht.eulerAngles.y=Float(i)*0.2; world.addChildNode(yacht) }
        }
        for i in 0..<22 {
            let angle=Float(i)*2 * .pi/22; let radius: Float=420+Float(i%4)*35
            let h: CGFloat=CGFloat(circuit.id==0 ? 12+i%6*5 : 45+i%6*14)
            let n=SceneDressing.asset("coastal_cliff_01",height:Float(h),maxWidth:100) ?? SurfaceLibrary.hill(radius:circuit.id==0 ? 95 : 80,height:Float(h),seed:i,vegetated:circuit.id==0,desert:circuit.id==2); n.position=SCNVector3(sin(angle)*radius,-0.1,cos(angle)*radius); world.addChildNode(n)
        }
        let motes=SCNParticleSystem(); motes.birthRate=circuit.id==1 ? 100 : 30; motes.particleLifeSpan=6; motes.particleSize=circuit.id==1 ? 0.035 : 0.08; motes.particleColor=UIColor(hex:circuit.id==1 ? 0x8EADD3 : 0xFFEBC3); motes.particleVelocity=circuit.id==1 ? 18 : 0.4; motes.spreadingAngle=10; motes.emitterShape=SCNBox(width:260,height:1,length:260,chamferRadius:0); motes.acceleration=SCNVector3(0,circuit.id==1 ? -12 : 0.2,0); motes.blendMode = .additive
        let emitter=SCNNode(); emitter.position=SCNVector3(0,circuit.id==1 ? 30 : 1,0); emitter.addParticleSystem(motes); scene.rootNode.addChildNode(emitter)
        for side: Float in [-0.7,0.7] {
            let exhaust=SCNNode(); exhaust.position=SCNVector3(side,0.4,-2.3)
            let particles=SCNParticleSystem(); particles.birthRate=7; particles.particleLifeSpan=0.5; particles.particleSize=0.045; particles.particleColor=UIColor(white:0.55,alpha:0.18); particles.particleVelocity=0.8; particles.spreadingAngle=20; particles.blendMode = .alpha; exhaust.addParticleSystem(particles); player.addChildNode(exhaust)
        }
    }
    private func scenery(_ t: Double,index: Int) {
        for side in [-1.0,1.0] {
            let p=circuit.point(t,lane:side*(22+Double(index%4)*6))
            if circuit.id==0 {
                if index%3==0,let tree=SceneDressing.asset("island_tree_01",height:8) {tree.position=SCNVector3(p.x+Float(side)*14,0,p.z);world.addChildNode(tree)}
                let palm=SceneDressing.palm(); palm.position=SCNVector3(p.x,0,p.z);palm.eulerAngles.y=Float(index)*0.73;palm.scale.y *= 0.8+Float(index%4)*0.1;world.addChildNode(palm)
            } else if circuit.id==1 {
                let n=SceneDressing.tower(height:Float(12+index%37),seed:index);n.position=SCNVector3(p.x,0,p.z);n.eulerAngles.y=circuit.heading(t)+Float(side) * .pi/2;world.addChildNode(n)
            } else {
                if circuit.id==3,let pine=SceneDressing.asset("pine_sapling_small",height:8+Float(index%4)) {pine.position=SCNVector3(p.x,0,p.z);world.addChildNode(pine)}
                let h=CGFloat(15+index%23); let rock=SceneDressing.asset("coastal_cliff_01",height:Float(h),maxWidth:18) ?? SurfaceLibrary.hill(radius:12,height:Float(h),seed:index,vegetated:false,desert:circuit.id==2,snow:circuit.id==3); let rockPoint=circuit.point(t,lane:side*38)
                rock.position=SCNVector3(rockPoint.x,0,rockPoint.z);rock.eulerAngles.y=Float(index)
                let radius:Float=18 * sqrt(2)/2
                let clear=(0..<480).allSatisfy {step in let road=circuit.point(Double(step)/480);return hypot(road.x-rockPoint.x,road.z-rockPoint.z)>11+radius+3}
                if clear {rock.name="roadside-rock";world.addChildNode(rock)}

            }
            if index%12==0 { let post=SCNNode(geometry:SCNCylinder(radius:0.12,height:6)); post.geometry?.materials=[material(0x68819A)]; let q=circuit.point(t,lane:side*11); post.position=SCNVector3(q.x,3,q.z); world.addChildNode(post)
                let lamp=SCNNode(geometry:SCNSphere(radius:0.3)); lamp.geometry?.materials=[material(0xFFCD95,glow:true)]; lamp.position=SCNVector3(q.x,6,q.z); world.addChildNode(lamp)
                if circuit.id==1 && index%24==0 {let light=SCNNode();light.light=SCNLight();light.light?.type = .omni;light.light?.intensity=180;light.light?.color=UIColor(hex:0xFFD7A2);light.light?.attenuationStartDistance=2;light.light?.attenuationEndDistance=22;light.position=lamp.position;scene.rootNode.addChildNode(light)}
            }
        }
    }
    static func skyImage(_ circuit: Circuit) -> UIImage {
        if let sky=SurfaceLibrary.image(circuit.id==1 ? "sky-night" : "sky-coast") { return sky }
        return UIGraphicsImageRenderer(size:CGSize(width:512,height:512)).image { ctx in
            let colors=[UIColor(hex:circuit.id==1 ? 0x090F28 : 0x547F9E).cgColor,UIColor(hex:circuit.id==1 ? 0x293662 : 0xC8D3D5).cgColor,UIColor(hex:circuit.id==1 ? 0xB6687D : 0xEFC3A3).cgColor]
            let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:[0,0.65,1])!
            ctx.cgContext.drawLinearGradient(gradient,start:.zero,end:CGPoint(x:0,y:512),options:[])
            UIColor(hex:0xFFE2B2).setFill(); ctx.cgContext.fillEllipse(in:CGRect(x:330,y:290,width:100,height:100))
        }
    }
}

struct SceneSurface: UIViewRepresentable {
    let engine:RaceEngine
    final class Coordinator:NSObject,SCNSceneRendererDelegate {
        weak var view:SCNView?;var firstTime:TimeInterval?;var frames=0
        func renderer(_ renderer:SCNSceneRenderer,didRenderScene scene:SCNScene,atTime time:TimeInterval) {
            guard ProcessInfo.processInfo.arguments.contains("--visual-review") else {return}
            if firstTime==nil {firstTime=time};frames += 1
            if frames==120,let first=firstTime,time>first {
                let fps=Double(frames-1)/(time-first)
                DispatchQueue.main.async { [weak self] in self?.view?.accessibilityValue=String(format:"%.1f fps",fps) }
                frames=0;firstTime=nil
            }
        }
    }
    func makeCoordinator() -> Coordinator {Coordinator()}
    func makeUIView(context:Context) -> SCNView {
        let v=SCNView();v.scene=engine.scene;v.pointOfView=engine.camera;v.isPlaying=true;v.preferredFramesPerSecond=60;v.antialiasingMode = .multisampling4X;v.backgroundColor = .black
        v.isAccessibilityElement=true;v.accessibilityLabel="Three-dimensional racing circuit";v.accessibilityIdentifier="race-scene";v.delegate=context.coordinator;context.coordinator.view=v;return v
    }
    func updateUIView(_ uiView:SCNView,context:Context) {}
    static func dismantleUIView(_ uiView:SCNView,coordinator:Coordinator) {uiView.isPlaying=false;uiView.scene=nil;uiView.delegate=nil}
}
struct CarShowroom: UIViewRepresentable {
    let car: Car
    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        weak var view:SCNView?; var name="";var ready=false
        func renderer(_ renderer:SCNSceneRenderer,didRenderScene scene:SCNScene,atTime time:TimeInterval) {
            guard !ready else {return};ready=true
            DispatchQueue.main.async { [weak self] in guard let self=self else {return};self.view?.accessibilityIdentifier="showroom-ready-"+self.name }
        }
    }
    func makeCoordinator() -> Coordinator {Coordinator()}
    func makeUIView(context:Context) -> SCNView {
        let v=SCNView();v.backgroundColor = .clear;v.autoenablesDefaultLighting=false;v.antialiasingMode = .multisampling4X;v.isPlaying=true;v.preferredFramesPerSecond=30;v.isAccessibilityElement=true;v.accessibilityLabel="Interactive three-dimensional car showroom";context.coordinator.view=v;v.delegate=context.coordinator;return v
    }
    static func dismantleUIView(_ v:SCNView,coordinator:Coordinator) {v.isPlaying=false;v.scene=nil;v.delegate=nil}
    func updateUIView(_ v:SCNView,context:Context) {
        guard context.coordinator.name != car.name else {return};context.coordinator.name=car.name;context.coordinator.ready=false;v.accessibilityIdentifier="showroom-loading"
        let s=SceneDressing.studio();let n=RaceEngine.makeCar(car);s.rootNode.addChildNode(n);n.runAction(.repeatForever(.rotateBy(x:0,y:2 * .pi,z:0,duration:28)))
        let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.fieldOfView=36;camera.camera?.wantsHDR=true;camera.camera?.wantsExposureAdaptation=false;camera.camera?.screenSpaceAmbientOcclusionIntensity=0.65;camera.camera?.exposureOffset = -0.25;camera.position=SCNVector3(6.0,2.4,6.0);camera.look(at:SCNVector3(0,0.5,0));s.rootNode.addChildNode(camera);v.scene=s;v.pointOfView=camera
    }
}
