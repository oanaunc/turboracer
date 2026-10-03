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
    /// Large centre call-out: takedowns, jumps, near misses, overtakes.
    /// Gearbox state for the tachometer, mirroring the engine sound.
    @Published var gear = 1; @Published var rpm = 900.0
    @Published var stunt = ""; @Published var takedowns = 0; @Published var shockwave = false
    private(set) var stuntCount = 0; private var stuntTimer = 0.0; private var stuntCredits = 0
    let ramps: [Ramp]; private(set) var air = AirState(); private var rivalAir: [AirState] = []
    private var rivalLanes: [Double] = [-4,0,4]; private var rivalTargets: [Double] = [-4,0,4]
    private(set) var rivalWreck: [Double] = [0,0,0]; private var nearMissReady: [Bool] = [true,true,true]
    private var lastPosition = 4; private var announcedFinalLap = false
    private var lastNitroRelease = -10.0; private var shockwaveArmed = false
    private(set) var collisionCount = 0
    var steering = 0.0; var braking = false; var drifting = false
    /// Double-tapping nitro with at least half a tank fires a shockwave boost.
    var nitroHeld = false {
        didSet {
            guard nitroHeld != oldValue else { return }
            if nitroHeld { shockwaveArmed = elapsed-lastNitroRelease < 0.35 && nitro >= 0.5 } else { lastNitroRelease = elapsed; shockwaveArmed = false }
        }
    }
    let circuit: Circuit; let mode: RaceMode; let car: Car; let upgrade: Int
    let rivalCars:[Car]
    let sensitivity: Double; let haptics: Bool; private let audio: CarAudio
    let scene = SCNScene(); private let world = SCNNode(); private let roadFurniture = SCNNode(); private let trackLength: Double; let camera = SCNNode(); let player: SCNNode
    private let playerCollider:VehicleCollider
    private var effects:RaceEffects?
    /// Wheel pivots found once; walking every car hierarchy per frame was costly.
    private var wheels:[SCNNode]=[]
    private var rivalColliders:[VehicleCollider]=[]
    private var vehicleShadows:[SCNNode]=[]
    private var rivals: [SCNNode] = []; private var rivalProgress = [-0.008,-0.016,-0.024]
    private var sparks: [SCNNode] = []; private var sparkCollected = Set<Int>(); private var messageTimer = 0.0
    private var progress = 0.0; private var lane = 0.0; private var lateral = 0.0
    private var displayLink: CADisplayLink?; private var lastTime = 0.0
    private var nitroExhausted=false
    private var boostCameraBlend=0.0
    private(set) var simulationFrames=0
    private(set) var boostFrameSamples=0
    private(set) var maxBoostFrameGap=0.0
    @MainActor private final class FrameDriver: NSObject {
        weak var engine: RaceEngine?
        init(_ engine:RaceEngine) {self.engine=engine}
        @objc func frame(_ link:CADisplayLink) {
            guard let engine else {link.invalidate();return}
            engine.tick(at:link.timestamp)
        }
    }
    private var barrierCooldown = 0.0
    private var countdownTime = 0.0; private var driftFraction = 0.0; private var driftChain = 0.0; private var collisionCooldown = 0.0
    var routeProgress: Double { progress-floor(progress) }
    var totalLaps: Int { mode.laps }
    /// Elimination countdown and knockdown target shown in the HUD.
    @Published var eliminationClock = 20.0; @Published var eliminated = 0
    static let knockdownTarget = 3
    private var rivalOut: [Bool] = [false,false,false]; private var playerOut = false
    init(circuit: Circuit, mode: RaceMode, car: Car, upgrade: Int, sensitivity: Double, haptics: Bool, sounds: Bool = false) {
        rivalCars = !mode.hasRivals ? [] : mode == .duel ? [Car.champion(for:car,route:circuit.id)] : Car.rivals(for:car,route:circuit.id)
        ramps=Ramp.layout(for:circuit)
        self.circuit = circuit; self.trackLength = circuit.length; self.mode = mode; self.car = car; self.upgrade = upgrade
        self.sensitivity = sensitivity; self.haptics = haptics; audio = CarAudio(enabled:sounds); player = Self.makeCar(car);playerCollider=VehicleCollider(node:player)
        buildWorld(); scene.rootNode.addChildNode(player); camera.camera = SCNCamera()
        camera.camera?.projectionDirection = .horizontal; camera.camera?.fieldOfView = 72; camera.camera?.zFar = 1500
        camera.camera?.wantsHDR = true; camera.camera?.bloomIntensity = 0.12; camera.camera?.bloomThreshold = 1.1
        camera.camera?.exposureOffset = circuit.look.exposure; camera.camera?.wantsExposureAdaptation = false
        // Screen-space AO cost a full extra pass per frame on device; contact
        // shadows under each car give the grounding it provided.
        camera.camera?.screenSpaceAmbientOcclusionIntensity = 0
        scene.rootNode.addChildNode(camera)
        rivalAir=Array(repeating:AirState(),count:rivalCars.count)
        for rivalCar in rivalCars {let n=Self.makeCar(rivalCar);rivals.append(n);rivalColliders.append(VehicleCollider(node:n));scene.rootNode.addChildNode(n)}
        for vehicle in [player]+rivals {let shadow=SceneAtmosphere.contactShadow(for:vehicle);scene.rootNode.addChildNode(shadow);vehicleShadows.append(shadow)}
        effects=RaceEffects(car:player,camera:camera,parent:scene.rootNode,environment:circuit.environment)
        placeCars(); updateCamera(dt: 1)
    }
    func start() {
        guard displayLink == nil else { return }
        lastTime=CACurrentMediaTime()
        let link=CADisplayLink(target:FrameDriver(self),selector:#selector(FrameDriver.frame(_:)))
        link.preferredFrameRateRange=CAFrameRateRange(minimum:30,maximum:60,preferred:60)
        // Keep simulation running while UIKit is tracking a held touch, and
        // advance directly on the main thread without queuing a Task per frame.
        link.add(to:.main,forMode:.common);displayLink=link
    }
    func stop() { audio.stop(); effects?.stop(); displayLink?.invalidate(); displayLink = nil; steering = 0; braking = false; drifting = false; nitroHeld = false }
    func setPaused(_ value: Bool) { if value { audio.stop() }; paused = value; steering = 0; braking = false; drifting = false; nitroHeld = false; lastTime = CACurrentMediaTime() }
    private func tick(at timestamp:TimeInterval) {
        let gap=max(0,timestamp-lastTime);lastTime=timestamp
        if !paused && result==nil {simulationFrames += 1}
        #if DEBUG
        if nitroHeld && countdown==0 && !paused && result==nil {
            boostFrameSamples += 1;maxBoostFrameGap=max(maxBoostFrameGap,gap)
        }
        #endif
        advance(dt:min(0.1,gap))
    }
    func advance(dt:Double) {
        guard !paused, result == nil else { return }
        SCNTransaction.begin();SCNTransaction.animationDuration=0;SCNTransaction.disableActions=true
        defer {SCNTransaction.commit()}
        if countdown > 0 { countdownTime += dt; let next = max(0,3-Int(countdownTime)); if next != countdown { countdown = next; feedback() }; return }
        barrierCooldown=max(0,barrierCooldown-dt)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--stunt-review") {
            // Line up on the next ramp under nitro so captures show a jump.
            let ahead=ramps.min { ($0.progress-routeProgress+1).truncatingRemainder(dividingBy:1) < ($1.progress-routeProgress+1).truncatingRemainder(dividingBy:1) }
            steering=max(-0.8,min(0.8,(lane-(ahead?.lane ?? 0))*0.3));nitroHeld=nitro>0.2
        } else if ProcessInfo.processInfo.arguments.contains("--effects-review") {
            // Alternate nitro and a held drift so captures show every effect.
            let phase=Int(elapsed/3)%2;nitroHeld=phase==0;drifting=phase==1;steering=phase==1 ? (lane > 4 ? 0.6 : lane < -4 ? -0.6 : (sin(elapsed*1.4) >= 0 ? 0.55 : -0.55)) : max(-0.6,min(0.6,lane*0.08))
        }
        #endif
        elapsed += dt; messageTimer = max(0,messageTimer-dt); if messageTimer == 0 { sparkMessage = "" }; collisionCooldown = max(0,collisionCooldown-dt)
        let maxSpeed = car.speed + Double(upgrade)*3
        if !nitroHeld {nitroExhausted=false}
        if nitroHeld && nitro<=0.015 {nitroExhausted=true}
        boosting = nitroHeld && !nitroExhausted && !braking && !offRoad
        shockwave = boosting && shockwaveArmed
        stuntTimer=max(0,stuntTimer-dt); if stuntTimer==0 { stunt="" }
        nitro = max(0,min(1,nitro + dt*(boosting ? (shockwave ? -0.42 : -0.27) : drifting ? 0.10 : 0.035)))
        let desired = braking ? maxSpeed*0.30 : (offRoad && !air.airborne ? maxSpeed*0.52 : maxSpeed*(shockwave ? 1.6 : boosting ? 1.38 : 1))
        speed += (desired-speed)*min(1,dt*(braking ? 3 : 0.65))
        if speed > CarAudio.gearTop[gear]*0.97 && gear < 6 { gear += 1 } else if gear > 1 && speed < CarAudio.gearTop[gear-1]*0.7 { gear -= 1 }
        rpm = CarAudio.revs(speed:speed,gear:gear)
        audio.update(speed:speed,boost:boosting,drifting:drifting,steering:steering,offRoad:offRoad,braking:braking)
        // The car travels along local +Z; the rear camera looks toward +Z,
        // making its screen-right axis local -X. Authored lane normals use +X.
        lateral += (-steering*sensitivity*car.handling*(drifting ? 10 : 7)-lateral)*min(1,dt*5)
        let bend = Double(atan2(sin(circuit.heading(progress+0.002)-circuit.heading(progress)),cos(circuit.heading(progress+0.002)-circuit.heading(progress))))
        let outward = -min(2,max(-2,bend*65))*pow(speed/maxSpeed,2)
        lane = max(-12,min(12,lane+(lateral+outward)*dt))
        offRoad = abs(lane)>8.1 && !air.airborne
        let turnA = circuit.heading(progress), turnB = circuit.heading(progress+0.001)
        let curve = abs(Double(atan2(sin(turnB-turnA),cos(turnB-turnA))))
        if drifting && speed > 23 && abs(steering)>0.18 && !offRoad {
            driftChain += dt; combo = min(5,1+Int(driftChain/2)); driftFraction += dt*(24+curve*1000)*Double(combo)
            driftScore = Int(driftFraction)
        } else { driftChain = 0; combo = 1 }
        let previousProgress=progress
        progress += speed*dt/trackLength
        lap = min(totalLaps,Int(progress)+1)
        for i in rivals.indices {
            let gap=VehicleCollider.trackSeparation(rivalProgress[i],progress,length:trackLength)
            // Mild rubber banding keeps the pack in sight without stealing wins.
            let band=gap < -60 ? 1.06 : gap > 80 ? 0.96 : 1.0
            if rivalOut[i] { continue }
            var rivalSpeed = maxSpeed * ((mode == .duel ? 0.955 : 0.88 + Double(i)*0.023) + 0.025*sin(elapsed*0.6+Double(i)))*band
            if rivalWreck[i]>0 { rivalWreck[i]=max(0,rivalWreck[i]-dt); rivalSpeed *= rivalWreck[i]>0 ? 0.25 : 0.6 }
            let previousRival=rivalProgress[i]
            rivalProgress[i] += rivalSpeed*dt/trackLength
            // Rivals pick new racing lines every few seconds.
            if Int(elapsed*10)%Int(30+i*7)==0 { rivalTargets[i]=max(-6,min(6,4.5*sin(elapsed*0.37+Double(i)*2.1))) }
            rivalLanes[i] += max(-2.2*dt,min(2.2*dt,rivalTargets[i]-rivalLanes[i]))
            _=rivalAir[i].update(dt:dt,progress:rivalProgress[i],lane:rivalLanes[i],speed:rivalSpeed,ramps:ramps,trackLength:trackLength)
            let rivalLane = rivalLanes[i]
            let separation=VehicleCollider.trackSeparation(progress,rivalProgress[i],length:trackLength)
            // Keep the sweep continuous at half a lap; independent wrapping
            // of both endpoints would create a false crossing through the grid.
            let previous=separation-((progress-rivalProgress[i])-(previousProgress-previousRival))*trackLength
            let body=playerCollider.projected(yaw:lateral*0.022*(drifting ? 2:1)),other=rivalColliders[i]
            let verticalGap=abs(air.height-rivalAir[i].height)
            if rivalWreck[i]==0 && verticalGap<1.2 && body.sweptContact(other,previous:previous,current:separation,lateral:lane-rivalLane) {
                let contact=SCNVector3((player.position.x+rivals[i].position.x)/2,0.6,(player.position.z+rivals[i].position.z)/2)
                if elapsed > 3 && speed > 25 && previous < 0.5 && (boosting || speed > rivalSpeed*1.12) {
                    // Takedown: a fast hit wrecks the rival instead of slowing you.
                    rivalWreck[i]=2.6; takedowns += 1; nitro=min(1,nitro+0.3); stuntCredits += 60
                    call("TAKEDOWN!"); audio.play("takedown",volume:0.9); effects?.impact(at:contact,strength:1); speed *= 0.95; feedback()
                } else {
                    // Push clear of the complete body every frame; the cooldown only
                    // limits impact feedback and speed loss, never contact detection.
                    let side=lane >= rivalLane ? 1.0 : -1.0
                    lane=max(-12,min(12,rivalLane+side*(body.halfWidth+other.halfWidth+0.12)))
                    lateral=side*max(1,abs(lateral)*0.4)
                    if collisionCooldown == 0 {collisionCount += 1;audio.play("impact",volume:0.7);effects?.impact(at:contact,strength:0.8);speed=min(speed*0.76,rivalSpeed*0.92);collisionCooldown=0.5;feedback()}
                }
                nearMissReady[i]=false
            } else if previous<0 && separation>=0 && rivalWreck[i]==0 {
                // Passing a rival closely without contact earns nitro.
                if nearMissReady[i] && abs(lane-rivalLane) < body.halfWidth+other.halfWidth+1.3 { nitro=min(1,nitro+0.08); stuntCredits += 15; call("NEAR MISS"); audio.play("whoosh",volume:0.6) }
                nearMissReady[i]=true
            } else if abs(separation)>20 { nearMissReady[i]=true }
        }
        let landing=air.update(dt:dt,progress:progress,lane:lane,speed:speed,ramps:ramps,trackLength:trackLength)
        if case .jump(let time,let barrel)=landing {
            if barrel { nitro=min(1,nitro+0.3); stuntCredits += 80; call("BARREL ROLL") }
            else if time>0.45 { nitro=min(1,nitro+0.2); stuntCredits += 40; call(time>0.9 ? "BIG AIR" : "JUMP") }
            effects?.impact(at:SCNVector3(player.position.x,0.2,player.position.z),strength:0.45); audio.play("land",volume:0.8); feedback()
        }
        // Lane coordinates are road-normal metres on every authored route.
        let width=playerCollider.projected(yaw:lateral*0.022*(drifting ? 2:1)).halfWidth
        let barrierLimit=max(6,10.8-width-0.35)
        if abs(lane)>barrierLimit {
            lane=lane<0 ? -barrierLimit:barrierLimit;lateral=0
            if barrierCooldown==0 {audio.play("impact",volume:0.5);let edge=circuit.point(progress,lane:lane<0 ? -10.6:10.6);effects?.impact(at:SCNVector3(edge.x,0.7,edge.z),strength:0.55);speed=max(min(speed,maxSpeed*0.45),speed*0.85);barrierCooldown=0.4;feedback()}
        }
        position = 1+rivalProgress.indices.filter { !rivalOut[$0] && rivalProgress[$0]>progress }.count
        if mode == .elimination { updateElimination(dt:dt) }
        if mode == .knockdown && takedowns >= Self.knockdownTarget { finish(); return }
        if mode.hasRivals && position < lastPosition && elapsed > 2 { call(position==1 ? "TAKING THE LEAD" : "OVERTAKE · P\(position)") }
        lastPosition=position
        if totalLaps>1 && lap==totalLaps && !announcedFinalLap { announcedFinalLap=true; call("FINAL LAP") }
        for i in sparks.indices where !sparkCollected.contains(i) {
            let location = Double(i+1)/13
            let distance = abs((progress-floor(progress))-location)*trackLength
            let sparkLane = Double((i%3)-1)*5
            sparks[i].eulerAngles.y += Float(dt*1.6)
            if distance < 4.5 && abs(lane-sparkLane) < 2.3 {
                audio.collect(); effects?.collect(at:sparks[i].position); sparkCollected.insert(i); sparks[i].isHidden=true; collected += 1; nitro=min(1,nitro+0.12)
                sparkMessage = "MEMORY CHIP +35 • NITRO RESTORED"; messageTimer=2; feedback()
            }
        }
        if wheels.isEmpty { for vehicle in [player]+rivals { vehicle.enumerateChildNodes { node,_ in if node.name=="rolling-wheel" {wheels.append(node)} } } }
        let spin=Float(speed*dt/0.465)
        for wheel in wheels { wheel.eulerAngles.x += spin }
        placeCars(); updateCamera(dt: dt)
        effects?.update(dt:dt,car:player,camera:camera,speed:speed,maxSpeed:maxSpeed,boosting:boosting,shockwave:shockwave,drifting:drifting,steering:steering,offRoad:offRoad)
        if progress >= Double(totalLaps) { finish() }
    }
    private func finish() {
        guard result == nil else { return }
        let stars: Int
        switch mode {
        case .circuit,.elimination: stars = playerOut ? 0 : max(0,4-position)
        case .duel: stars = position == 1 ? 3 : 0
        case .knockdown: stars = min(3,takedowns)
        case .sprint: let target = trackLength / (car.speed*0.83); stars = elapsed < target ? 3 : elapsed < target*1.16 ? 2 : elapsed < target*1.4 ? 1 : 0
        case .drift: stars = driftScore >= 1600 ? 3 : driftScore >= 850 ? 2 : driftScore >= 300 ? 1 : 0
        }
        let reward = 150 + stars*180 + min(400,driftScore/8) + collected*35 + stuntCredits
        result = RaceResult(position: [.circuit,.elimination,.duel].contains(mode) ? position : stars == 3 ? 1 : 2, time: elapsed, drift: driftScore, credits: reward, stars: stars, collected: collected, takedowns: takedowns, stunts: stuntCount)
        feedback(); stop()
    }
    /// Every 20 seconds the last-placed car leaves the race. Losing all
    /// rivals is a win; being last when the clock runs out ends the event.
    private func updateElimination(dt:Double) {
        eliminationClock -= dt
        guard eliminationClock <= 0 else { return }
        eliminationClock = 20
        let alive = rivalProgress.indices.filter { !rivalOut[$0] }
        let lastRival = alive.min { rivalProgress[$0] < rivalProgress[$1] }
        if let lastRival, rivalProgress[lastRival] < progress {
            rivalOut[lastRival] = true; eliminated += 1; rivals[lastRival].isHidden = true; vehicleShadows[lastRival+1].isHidden = true
            call("\(rivalCars[lastRival].name) ELIMINATED")
            if alive.count == 1 { position = 1; finish() }
        } else {
            playerOut = true; call("ELIMINATED"); finish()
        }
    }
    #if DEBUG
    /// Review hook: end the event immediately with sample statistics.
    func debugFinish() { elapsed=84.2; collected=9; takedowns=2; stuntCount=6; stuntCredits=180; position=1; finish() }
    #endif
    private func call(_ text:String) { stunt=text; stuntTimer=1.4; stuntCount += 1 }
    private func feedback() { if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    private func placeCars() {
        defer {placeShadows()}
        player.position = vector(circuit.point(progress,lane: lane)); player.position.y += Float(air.height)
        player.eulerAngles = SCNVector3(air.airborne ? Float(-air.velocity*0.012) : air.ramp != nil ? -0.13 : 0, circuit.heading(progress)+Float(lateral*0.022*(drifting ? 2 : 1)), Float(air.roll))
        for i in rivals.indices {
            rivals[i].position = vector(circuit.point(rivalProgress[i],lane: rivalLanes[i])); rivals[i].position.y += Float(rivalAir[i].height)
            let heading=circuit.heading(rivalProgress[i])
            if rivalWreck[i]>0 {
                // Wrecked rivals tumble and spin out, then recover.
                let t=Float(2.6-rivalWreck[i])
                rivals[i].position.y += max(0,2.2*sin(min(Float.pi,t*2.2)))
                rivals[i].eulerAngles = SCNVector3(t*3.1, heading+t*4.5, t*5.2)
            } else { rivals[i].eulerAngles = SCNVector3(rivalAir[i].ramp != nil ? -0.13 : 0, heading, Float(rivalAir[i].roll)) }
        }
    }
    private func placeShadows() {
        for (vehicle,shadow) in zip([player]+rivals,vehicleShadows) {shadow.position=SCNVector3(vehicle.position.x,0.13,vehicle.position.z);shadow.eulerAngles=SCNVector3(-.pi/2,0,-vehicle.eulerAngles.y)}
    }
    private var chaseHeading:Float?
    private func updateCamera(dt: Double) {
        let p = circuit.point(progress,lane: lane); let heading = circuit.heading(progress)
        var smooth=chaseHeading ?? heading
        let difference=atan2(sin(heading-smooth),cos(heading-smooth));smooth += difference*Float(min(1,dt*8));chaseHeading=smooth
        boostCameraBlend += ((boosting ? 1.0:0.0)-boostCameraBlend)*(1-exp(-dt*7))
        let distance=Float(8.3+1.2*boostCameraBlend)
        let lift=Float(air.height)
        let target = SCNVector3(p.x-sin(smooth)*distance, 2.8+lift*0.75, p.z-cos(smooth)*distance)
        camera.position = target
        let ahead = SIMD3<Float>(p.x+sin(heading)*5,1.0,p.z+cos(heading)*5)
        camera.look(at: SCNVector3(ahead.x,0.6+lift*0.85,ahead.z), up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,-1)); camera.camera?.fieldOfView = 68+8*boostCameraBlend
    }
    static func makeCar(_ car: Car,model:String?=nil) -> SCNNode {
        if let model=SurfaceLibrary.grandTourer(car,model:model) { VehicleCollider.attach(to:model);return model }
        let root = SCNNode(); let paint = SurfaceLibrary.paint(car.color)
        func box(_ w: CGFloat,_ h: CGFloat,_ l: CGFloat,_ x: Float,_ y: Float,_ z: Float,_ mat: SCNMaterial,_ bevel: CGFloat = 0.12) {
            let g = SCNBox(width:w,height:h,length:l,chamferRadius:bevel); g.materials=[mat]; let n=SCNNode(geometry:g); n.position=SCNVector3(x,y,z); root.addChildNode(n)
        }
        let dark = material(0x091626); let chrome = material(0xD8E8EF)
        let widths: [Float] = [1,0.96,1.06,1.02,1.08,0.97]
        let lengths: [Float] = [1,0.91,1.07,1.03,1.10,1.04]
        let width = widths[car.id%6], length = lengths[car.id%6]
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
        let roofY: Float=car.id%6==4 ? 1.26 : 1.42
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
        if car.id%6>=3 { box(0.15,0.10,1.1,-0.66,0.86,-1.55,dark); box(0.15,0.10,1.1,0.66,0.86,-1.55,dark) }
        if car.id%6==5 { box(0.06,0.6,1.4,0,1.0,-1.6,paint) }
        VehicleCollider.attach(to:root);return root
    }
    private func buildWorld() {
        scene.background.contents = Self.skyImage(circuit)
        let daylight=(circuit.environment==0 && circuit.route != 4) || (circuit.environment==3 && circuit.route<3)
        if circuit.environment != 1, let sky=Bundle.main.url(forResource:daylight ? "daylight-sky":"coast-sky",withExtension:"hdr") { scene.background.contents=sky }
        scene.lightingEnvironment.contents = circuit.environment==1 ? Self.skyImage(circuit) : Bundle.main.url(forResource:"coast-light",withExtension:"hdr"); scene.lightingEnvironment.intensity = circuit.environment == 1 ? 0.8 : 0.65
        scene.fogColor = UIColor(hex:circuit.look.fog); scene.fogStartDistance = circuit.environment==1 ? 140:160; scene.fogEndDistance = circuit.environment==1 ? 820:900; scene.fogDensityExponent = 1.6
        let ambient=SCNNode(); ambient.light=SCNLight(); ambient.light?.type = .ambient; ambient.light?.color=UIColor(hex:0xCDDCEA); ambient.light?.intensity=160; scene.rootNode.addChildNode(ambient)
        let sun=SCNNode(); sun.light=SCNLight(); sun.light?.type = .directional; sun.light?.color=UIColor(hex:circuit.look.sun); sun.light?.intensity=circuit.environment == 1 ? 700 : 1400; sun.light?.castsShadow=true; sun.light?.shadowMapSize=CGSize(width:2048,height:2048); sun.light?.shadowMode = .forward; sun.light?.shadowBias=0.03; sun.light?.shadowCascadeCount=2; sun.light?.shadowSampleCount=4; sun.light?.shadowRadius=2.5; sun.light?.maximumShadowDistance=130; sun.light?.orthographicScale=75; sun.light?.shadowColor=UIColor(white:0,alpha:0.55); sun.eulerAngles=SCNVector3(-0.4-Float(circuit.route)*0.12,-0.5+Float(circuit.route)*0.65,0); scene.rootNode.addChildNode(sun)
        let distantFloor=SCNFloor();distantFloor.materials=[RouteScenery.ground(circuit)];let distantLand=SCNNode(geometry:distantFloor);distantLand.position.y = -4;world.addChildNode(distantLand)
        world.addChildNode(RouteScenery.landmarks(circuit)); world.addChildNode(SceneDressing.terrain(circuit)); world.addChildNode(SceneDressing.promenade(circuit));world.addChildNode(SceneDressing.undergrowth(circuit));world.addChildNode(TracksideArt.dress(circuit))
        let roadMat=SurfaceLibrary.surface("asphalt"), stripe=material(0xDDDCD1), aqua=material(0x47CFFF,glow:true)
        if circuit.environment==1 {roadMat.roughness.contents=0.28;roadMat.normal.intensity=0.35}
        roadMat.multiply.contents=GroundCover.wear;roadMat.multiply.wrapS = .repeat;roadMat.multiply.wrapT = .repeat
        roadMat.multiply.contentsTransform=SCNMatrix4MakeScale(1/3.6,0.125,1);roadMat.multiply.mipFilter = .linear
        let road=(0..<240).map {circuit.point(Double($0)/240)}
        world.addChildNode(NatureDressing.dress(circuit) { p in
            guard self.circuit.environment>=2 else {return -0.03}
            let nearest=road.reduce(Float.greatestFiniteMagnitude) {min($0,hypot($1.x-p.x,$1.z-p.z))}
            let relief=max(0,min(1,(nearest-19)/65))*RouteScenery.terrainRelief(p.x,p.z,circuit:self.circuit)
            return -0.04+relief*(1.8+sin(p.x*0.03)*cos(p.z*0.025)*1.7)
        })
        world.addChildNode(GroundCover.tufts(circuit) { p in
            guard self.circuit.environment>=2 else {return -0.03}
            let nearest=road.reduce(Float.greatestFiniteMagnitude) {min($0,hypot($1.x-p.x,$1.z-p.z))}
            let relief=max(0,min(1,(nearest-19)/65))*RouteScenery.terrainRelief(p.x,p.z,circuit:self.circuit)
            return -0.04+relief*(1.8+sin(p.x*0.03)*cos(p.z*0.025)*1.7)
        })
        buildRoadSurface(roadMat)
        for i in 0..<12 {
            let n=SceneAtmosphere.memoryChip();n.eulerAngles.z = -0.12
            let p=circuit.point(Double(i+1)/13,lane:Double(i%3-1)*5); n.position=SCNVector3(p.x,1.65,p.z)
            sparks.append(n); scene.rootNode.addChildNode(n)
        }
        addAtmosphere()
        let count=240
        for i in 0..<count {
            let t=Double(i)/Double(count), a=circuit.point(t), b=circuit.point(Double(i+1)/Double(count))
            let distance=CGFloat(sqrt(pow(b.x-a.x,2)+pow(b.z-a.z,2)))
            let heading=atan2(b.x-a.x,b.z-a.z)
            // Continuous UV-mapped road replaces overlapping rectangular road slabs.
            for side in [-1.0,1.0] {
                if i%2==0 { let mark=SCNNode(geometry:SCNBox(width:0.12,height:0.02,length:distance*0.65,chamferRadius:0)); mark.geometry?.materials=[stripe]; let p=circuit.point(t,lane:side*3); mark.position=SCNVector3(p.x,0.12,p.z); mark.eulerAngles.y=heading; roadFurniture.addChildNode(mark) }
            }
            if i%6==0 { scenery(t,index:i) }
        }
        // Checkered finish and luminous gantry.
        for x in 0..<18 { for z in 0..<4 { let g=SCNBox(width:1,height:0.03,length:1,chamferRadius:0); g.materials=[material((x+z)%2==0 ? 0xF1EFE5 : 0x121621)]; let n=SCNNode(geometry:g); let p=circuit.point(Double(z)/circuit.length,lane:Double(x)-8.5); n.position=SCNVector3(p.x,0.14,p.z); n.eulerAngles.y=circuit.heading(0); world.addChildNode(n) } }
        let gate=SCNNode(); gate.position=vector(circuit.point(0)); gate.eulerAngles.y=circuit.heading(0)
        for x: Float in [-10,10] { let n=SCNNode(geometry:SCNBox(width:0.6,height:8,length:0.6,chamferRadius:0.1)); n.geometry?.materials=[aqua]; n.position=SCNVector3(x,4,0); gate.addChildNode(n) }
        let banner=SCNNode(geometry:SCNBox(width:21,height:1.5,length:0.4,chamferRadius:0.1)); banner.geometry?.materials=[material(0x171A30)]; banner.position=SCNVector3(0,8,0); gate.addChildNode(banner)
        let text=SCNText(string:"AFTERLIGHT",extrusionDepth:0.015); text.font=UIFont.boldSystemFont(ofSize:1); text.flatness=0.2; text.materials=[aqua]; let label=SCNNode(geometry:text); label.scale=SCNVector3(1.15,1.15,1.15); label.position=SCNVector3(-4,7.5,-0.25); label.eulerAngles.y = .pi; gate.addChildNode(label); world.addChildNode(gate)
        for ramp in ramps { world.addChildNode(RampArt.node(ramp,circuit:circuit)) }
        world.addChildNode(roadFurniture.flattenedClone())
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
        // Continuous pavement follows the actual outer curve. Rectangular
        // curb segments left bright gaps on bends and looked like neon blocks.
        func ribbon(_ inner:Double,_ outer:Double,_ height:Float,_ material:SCNMaterial) {
            var points:[SCNVector3]=[],coordinates:[CGPoint]=[]
            for i in 0...count {
                let t=Double(i)/Double(count)
                for lane in [inner,outer] {let p=circuit.point(t,lane:lane);points.append(SCNVector3(p.x,height,p.z));coordinates.append(CGPoint(x:lane/2,y:t*circuit.length/2))}
            }
            let g=SCNGeometry(sources:[SCNGeometrySource(vertices:points),SCNGeometrySource(normals:Array(repeating:SCNVector3(0,1,0),count:points.count)),SCNGeometrySource(textureCoordinates:coordinates)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
            material.isDoubleSided=true;g.materials=[material];world.addChildNode(SCNNode(geometry:g))
        }
        let pavement=SurfaceLibrary.surface("stucco",tint:UIColor(hex:0x9C9B93));pavement.roughness.contents=0.9
        let edgePaint=material(0xE8E4D7)
        for side in [-1.0,1.0] {
            ribbon(side*8.72,side*8.85,0.122,edgePaint)
            ribbon(side*9.05,side*9.65,0.17,GroundCover.kerb)
            ribbon(side*9.65,side*(circuit.environment==1 ? 14:11.7),0.15,pavement)
        }
        // Roadside safety barriers are metal rather than luminous boundary walls.
        let metal=material(0x9FAAAF);metal.metalness.contents=0.75;metal.roughness.contents=0.4
        for i in stride(from:0,to:count,by:4) {
            let t=Double(i)/Double(count), next=Double(i+4)/Double(count)
            for side in [-1.0,1.0] {
                let a=circuit.point(t,lane:side*10.8),b=circuit.point(next,lane:side*10.8)
                let rail=SCNNode(geometry:SCNBox(width:0.12,height:0.36,length:CGFloat(simd_length(b-a)),chamferRadius:0.035));rail.geometry?.materials=[metal];rail.position=SCNVector3((a.x+b.x)/2,0.85,(a.z+b.z)/2);rail.eulerAngles.y=atan2(b.x-a.x,b.z-a.z);roadFurniture.addChildNode(rail)
                let post=SCNNode(geometry:SCNBox(width:0.09,height:0.9,length:0.09,chamferRadius:0.01));post.geometry?.materials=[metal];post.position=SCNVector3(a.x,0.45,a.z);roadFurniture.addChildNode(post)
            }
        }
    }
    private func addAtmosphere() {
        // Surrounding world gives each region its own recognizable silhouette.
        if circuit.environment==0 {
            world.addChildNode(SceneAtmosphere.sea())
            for i in 0..<9 { let yacht=SCNNode(geometry:SCNBox(width:3,height:1,length:10,chamferRadius:0.9)); yacht.geometry?.materials=[material(0xE9DCD3)]; yacht.position=SCNVector3(-180-Float(i)*18,0.5,Float(i*25-100)); yacht.eulerAngles.y=Float(i)*0.2; world.addChildNode(yacht) }
        }
        if circuit.environment==1 {world.addChildNode(SceneAtmosphere.skyline(circuit))}
        let ridgeCount=circuit.environment==1 ? 0:circuit.environment==0 ? 7:12
        for i in 0..<ridgeCount {
            // Keep the coast open to the sea; interlock broad inland ridges.
            let angle=circuit.environment==0 ? -Float.pi*0.40+Float(i)*Float.pi*0.8/Float(ridgeCount-1):Float(i)*2 * .pi/Float(ridgeCount)
            let distance:Float=570+Float(i%3)*55
            let radius:Float=205+Float(i%3)*15
            let h:Float=circuit.environment==0 ? 55+Float(i%4)*17 : circuit.environment==1 ? 65+Float(i%3)*18:145+Float(i%4)*35
            let n=SurfaceLibrary.hill(radius:radius,height:h,seed:i+circuit.id*13,vegetated:circuit.environment==0 || circuit.look.ground=="grass",desert:circuit.environment==2,snow:circuit.look.ground=="snow")
            n.position=SCNVector3(cos(angle)*distance,-1.5,sin(angle)*distance);n.eulerAngles.y=angle+Float.pi/2;world.addChildNode(n)
        }
        let motes=SCNParticleSystem(); motes.birthRate=circuit.look.ground=="snow" ? 70 : circuit.environment==1 && circuit.route != 2 ? 70 : 12; motes.particleLifeSpan=6; motes.particleSize=circuit.environment==1 ? 0.035 : 0.08; motes.particleColor=UIColor(hex:circuit.environment==1 ? 0x8EADD3 : 0xFFEBC3); motes.particleVelocity=circuit.environment==1 ? 18 : 0.4; motes.spreadingAngle=10; motes.emitterShape=SCNBox(width:260,height:1,length:260,chamferRadius:0); motes.acceleration=SCNVector3(0,circuit.environment==1 ? -12 : 0.2,0); motes.blendMode = .additive
        let emitter=SCNNode(); emitter.position=SCNVector3(0,circuit.environment==1 ? 30 : 1,0); emitter.addParticleSystem(motes); scene.rootNode.addChildNode(emitter)
        for side: Float in [-0.7,0.7] {
            let exhaust=SCNNode(); exhaust.position=SCNVector3(side,0.4,-2.3)
            let particles=SCNParticleSystem(); particles.birthRate=7; particles.particleLifeSpan=0.5; particles.particleSize=0.045; particles.particleColor=UIColor(white:0.55,alpha:0.18); particles.particleVelocity=0.8; particles.spreadingAngle=20; particles.blendMode = .alpha; exhaust.addParticleSystem(particles); player.addChildNode(exhaust)
        }
    }
    private func scenery(_ t: Double,index: Int) {
        for side in [-1.0,1.0] {
            let p=circuit.point(t,lane:side*(22+Double(index%4)*6))
            if circuit.environment==0 {
                if p.x < -153 || (index/6)%circuit.look.density != 0 || !RouteScenery.allowsScenery(p,radius:5,circuit:circuit) {continue}
                let palm=circuit.look.vegetation==2 ? (SceneDressing.asset("island_tree_01",height:8) ?? SceneDressing.palm()) : SceneDressing.palm(); palm.position=SCNVector3(p.x,0,p.z);palm.eulerAngles.y=Float(index)*0.73;palm.scale.y *= 0.8+Float(index%4)*0.1;world.addChildNode(palm)
            } else if circuit.environment==1 {
                if (index/6)%circuit.look.density != 0 {continue}
                let n=SceneDressing.tower(height:Float(circuit.route==2 ? 12+index%7 : circuit.route==3 ? 24+index%37 : 12+index%20),seed:index+circuit.route*18)
                n.eulerAngles.y=circuit.heading(t)-Float(side) * .pi/2
                let b=n.boundingBox
                // Include entrance steps, balconies and every descendant in the footprint.
                var extent:Float=0
                for x in [b.min.x,b.max.x] {for z in [b.min.z,b.max.z] {
                    let corner=n.convertPosition(SCNVector3(x,0,z),to:nil)
                    extent=max(extent,hypot(corner.x,corner.z))
                }}
                for offset in stride(from:Double(extent)+18,through:Double(extent)+(extent>24 ? 170:85),by:extent>24 ? 8:4) {
                    let position=circuit.point(t,lane:side*offset)
                    let clear=(0..<480).allSatisfy {step in let road=circuit.point(Double(step)/480);return hypot(road.x-position.x,road.z-position.z)>11+extent+3}
                    if clear && RouteScenery.allowsScenery(position,radius:extent,circuit:circuit) {n.position=SCNVector3(position.x,-0.12,position.z);n.name="roadside-building";world.addChildNode(n);SceneDressing.foundation(for:n,in:world);break}
                }
            } else {
                if circuit.environment==3 && (index/6)%circuit.look.density==0 && RouteScenery.allowsScenery(p,radius:4,circuit:circuit),let pine=SceneDressing.asset("AlpineFir",height:12+Float(index%4)*2,maxWidth:8) ?? SceneDressing.asset("pine_sapling_small",height:8+Float(index%4)) {pine.position=SCNVector3(p.x,0,p.z);world.addChildNode(pine)}
                // Alpine farmhouses from BlenderKit, kept clear of the whole circuit.
                if circuit.environment==3 && index%24==12, let house=SceneDressing.asset("CountryHouse",height:8.1) {
                    let spot=circuit.point(t,lane:side*46);house.eulerAngles.y=circuit.heading(t)+(side>0 ? .pi : 0)
                    let clear=(0..<480).allSatisfy {step in let road=circuit.point(Double(step)/480);return hypot(road.x-spot.x,road.z-spot.z)>11+18}
                    if clear && RouteScenery.allowsScenery(spot,radius:17,circuit:circuit) {house.position=SCNVector3(spot.x,-0.1,spot.z);house.name="roadside-building";world.addChildNode(house)}
                }
                let h=Float(4+index%(circuit.route==1 ? 4:8))
                // Sculpted ridge outcrops: the cliff scan flattened into slabs at this footprint.
                let rock=SurfaceLibrary.hill(radius:11+Float(index%3)*2,height:h,seed:index+circuit.id*31,vegetated:circuit.environment==3 && index%2==0,desert:circuit.environment==2,snow:circuit.look.ground=="snow"); let rockPoint=circuit.point(t,lane:side*38)
                rock.position=SCNVector3(rockPoint.x,0,rockPoint.z);rock.eulerAngles.y=Float(index)
                let radius:Float=18 * sqrt(2)/2
                let clear=(0..<480).allSatisfy {step in let road=circuit.point(Double(step)/480);return hypot(road.x-rockPoint.x,road.z-rockPoint.z)>11+radius+3}
                if clear && RouteScenery.allowsScenery(rockPoint,radius:radius,circuit:circuit) {rock.name="roadside-rock";world.addChildNode(rock)}

            }
            if index%12==0 {
                let fixture=SCNNode(),steel=material(0x35464D)
                steel.metalness.contents=0.65;steel.roughness.contents=0.35
                let post=SCNNode(geometry:SCNCylinder(radius:0.085,height:7.2));post.geometry?.materials=[steel];post.position.y=3.6;fixture.addChildNode(post)
                let arm=SCNNode(geometry:SCNBox(width:1.7,height:0.1,length:0.1,chamferRadius:0.035));arm.geometry?.materials=[steel];arm.position=SCNVector3(-Float(side)*0.78,7.12,0);fixture.addChildNode(arm)
                let head=SCNNode(geometry:SCNBox(width:0.8,height:0.09,length:0.28,chamferRadius:0.06));head.geometry?.materials=[steel];head.position=SCNVector3(-Float(side)*1.4,7.1,0);fixture.addChildNode(head)
                let lens=SCNNode(geometry:SCNBox(width:0.65,height:0.012,length:0.21,chamferRadius:0.01));lens.geometry?.materials=[material(0xDCEBF1,glow:true)];lens.position=head.position;lens.position.y-=0.05;fixture.addChildNode(lens)
                let q=circuit.point(t,lane:side*11.5);fixture.position=SCNVector3(q.x,0,q.z);fixture.eulerAngles.y=circuit.heading(t);world.addChildNode(fixture)
                // Real omni lights per lamp doubled the city's lighting cost; the
                // emissive lens and bloom carry the street-lamp look instead.
            }
        }
    }
    static func skyImage(_ circuit: Circuit) -> UIImage {
        if let sky=SurfaceLibrary.image(circuit.environment==1 ? "sky-night" : "sky-coast") { return sky }
        return UIGraphicsImageRenderer(size:CGSize(width:512,height:512)).image { ctx in
            let colors=[UIColor(hex:circuit.environment==1 ? 0x090F28 : 0x547F9E).cgColor,UIColor(hex:circuit.environment==1 ? 0x293662 : 0xC8D3D5).cgColor,UIColor(hex:circuit.environment==1 ? 0xB6687D : 0xEFC3A3).cgColor]
            let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:[0,0.65,1])!
            ctx.cgContext.drawLinearGradient(gradient,start:.zero,end:CGPoint(x:0,y:512),options:[])
            UIColor(hex:0xFFE2B2).setFill(); ctx.cgContext.fillEllipse(in:CGRect(x:330,y:290,width:100,height:100))
        }
    }
}

struct SceneSurface: UIViewRepresentable {
    @ObservedObject var engine:RaceEngine
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
        let v=SCNView();v.scene=engine.scene;v.pointOfView=engine.camera;v.isPlaying=true;v.preferredFramesPerSecond=60;v.antialiasingMode = .multisampling2X;v.backgroundColor = .black
        // Keep HUD text at native resolution while avoiding a 4x MSAA render
        // of the entire 3x Retina surface for the moving 3D world.
        v.contentScaleFactor=min(UIScreen.main.scale,1.8)
        v.isAccessibilityElement=true;v.accessibilityLabel="Three-dimensional racing circuit";v.accessibilityIdentifier="race-scene";v.delegate=context.coordinator;context.coordinator.view=v;return v
    }
    func updateUIView(_ uiView:SCNView,context:Context) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--nitro-review") {
            let sample:[String:Double]=["elapsed":engine.elapsed,"frames":Double(engine.simulationFrames),"boostSamples":Double(engine.boostFrameSamples),"maxBoostGap":engine.maxBoostFrameGap,"fov":Double(engine.camera.camera?.fieldOfView ?? 0)]
            if let data=try? JSONSerialization.data(withJSONObject:sample),let value=String(data:data,encoding:.utf8) {uiView.accessibilityValue=value}
        } else if ProcessInfo.processInfo.arguments.contains("--controls-review") {
            let center=engine.camera.convertPosition(vector(engine.circuit.point(engine.routeProgress)),from:nil)
            let player=engine.camera.convertPosition(engine.player.position,from:nil)
            uiView.accessibilityValue=String(format:"%.3f",player.x-center.x)
        }
        #endif
    }
    static func dismantleUIView(_ uiView:SCNView,coordinator:Coordinator) {uiView.isPlaying=false;uiView.scene=nil;uiView.delegate=nil}
}
struct CarShowroom: UIViewRepresentable {
    let car: Car
    var isActive=true
    /// Horizontal aim of the camera: positive values move the car left on screen.
    var focus:Float = -0.8
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
        // A full-screen race keeps its presenting SwiftUI view alive. Stop
        // the hidden showroom's renderer so it does not compete with racing.
        v.isPlaying=isActive
        guard context.coordinator.name != car.name else {return};context.coordinator.name=car.name;context.coordinator.ready=false;v.accessibilityIdentifier="showroom-loading"
        let s=SceneDressing.studio();let n=RaceEngine.makeCar(car);s.rootNode.addChildNode(n);let contact=SceneAtmosphere.contactShadow(for:n);contact.position.y=0.03;s.rootNode.addChildNode(contact);n.runAction(.repeatForever(.rotateBy(x:0,y:2 * .pi,z:0,duration:28)))
        let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.fieldOfView=36;camera.camera?.wantsHDR=true;camera.camera?.wantsExposureAdaptation=false;camera.camera?.screenSpaceAmbientOcclusionIntensity=0.65;camera.camera?.exposureOffset = -0.4;camera.position=SCNVector3(3.7,2.15,6.7);camera.look(at:SCNVector3(focus,0.65,0.6));s.rootNode.addChildNode(camera);v.scene=s;v.pointOfView=camera
    }
}
