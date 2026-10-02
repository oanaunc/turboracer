import SceneKit

/// Simple body volumes keep contact predictable while the arcade controller
/// drives the cars along the circuit. Visual meshes never become triangle colliders.
struct VehicleCollider {
    let halfWidth: Double
    let halfLength: Double
    init(node: SCNNode) {
        let bounds=node.boundingBox
        halfWidth=Double(bounds.max.x-bounds.min.x)/2
        halfLength=Double(bounds.max.z-bounds.min.z)/2
    }
    private init(halfWidth:Double,halfLength:Double) {self.halfWidth=halfWidth;self.halfLength=halfLength}
    func projected(yaw:Double) -> VehicleCollider {
        let c=abs(cos(yaw)),s=abs(sin(yaw))
        return VehicleCollider(halfWidth:halfWidth*c+halfLength*s,halfLength:halfLength*c+halfWidth*s)
    }
    func overlaps(_ other: VehicleCollider, longitudinal: Double, lateral: Double) -> Bool {
        abs(longitudinal)<halfLength+other.halfLength && abs(lateral)<halfWidth+other.halfWidth
    }
    func sweptContact(_ other: VehicleCollider, previous: Double, current: Double, lateral: Double) -> Bool {
        guard abs(lateral)<halfWidth+other.halfWidth else {return false}
        let reach=halfLength+other.halfLength
        return min(previous,current)<reach && max(previous,current) > -reach
    }
    static func trackSeparation(_ first:Double,_ second:Double,length:Double) -> Double {
        var delta=(first-second).truncatingRemainder(dividingBy:1)
        if delta>0.5 {delta-=1};if delta < -0.5 {delta+=1}
        return delta*length
    }
    static func attach(to node:SCNNode) {
        let bounds=node.boundingBox
        let size=SCNBox(width:CGFloat(bounds.max.x-bounds.min.x),height:CGFloat(bounds.max.y-bounds.min.y),length:CGFloat(bounds.max.z-bounds.min.z),chamferRadius:0)
        let center=SCNMatrix4MakeTranslation((bounds.min.x+bounds.max.x)/2,(bounds.min.y+bounds.max.y)/2,(bounds.min.z+bounds.max.z)/2)
        let shape=SCNPhysicsShape(shapes:[SCNPhysicsShape(geometry:size,options:nil)],transforms:[NSValue(scnMatrix4:center)])
        node.physicsBody=SCNPhysicsBody(type:.kinematic,shape:shape)
        // The controller resolves body contact once, avoiding a second solver
        // fighting the circuit-constrained transforms.
        node.physicsBody?.categoryBitMask=1;node.physicsBody?.collisionBitMask=0
        node.name="race-car-\(node.name ?? "vehicle")"
    }
}
