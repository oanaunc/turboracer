import XCTest
import SceneKit
import CryptoKit
import ModelIO
import SceneKit.ModelIO
import ObjectiveC
import CoreText
@testable import Afterlight

/// Explicit, opt-in build tool. Exports the actual Apple scene geometry; never
/// writes private licensed artwork into tracked source or changes player saves.
@MainActor final class AndroidExportTests: XCTestCase {
    func testExportAndroidScenes() throws {
        guard ProcessInfo.processInfo.environment["AFTERLIGHT_EXPORT_ANDROID"] == "1" else { throw XCTSkip("Offline Android asset export is opt-in") }
        // SceneKit's flattened meshes are GPU-only and expose no vertex
        // sources. Keep their original hierarchy during this opt-in export.
        let flattened=class_getInstanceMethod(SCNNode.self,#selector(SCNNode.flattenedClone))!
        let unflattened=class_getInstanceMethod(SCNNode.self,#selector(SCNNode.afterlightExportUnflattenedClone))!
        method_exchangeImplementations(flattened,unflattened)
        defer {method_exchangeImplementations(flattened,unflattened)}
        let out = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("AndroidScenes")
        let writer = try AndroidSceneWriter(out)
        for car in Car.all {
            try autoreleasepool {
                let scene = SCNScene(); let node = RaceEngine.makeCar(car); node.name="player"; scene.rootNode.addChildNode(node)
                let b=node.boundingBox
                try writer.scene(scene, name:"car-\(car.id)", extra:["halfWidth":Double(b.max.x-b.min.x)/2,"halfLength":Double(b.max.z-b.min.z)/2])
            }
        }
        try writer.scene(SceneDressing.studio(),name:"studio")
        for c in Circuit.all {
            try autoreleasepool {
                let engine=RaceEngine(circuit:c,mode:.sprint,car:Car.all[0],upgrade:0,sensitivity:1,haptics:false)
                // Dynamic vehicles, particles and chips are instantiated separately.
                for node in engine.scene.rootNode.childNodes where node === engine.player || node === engine.camera || node.name == "vehicle-contact-shadow" {node.removeFromParentNode()}
                engine.scene.rootNode.enumerateChildNodes {n,_ in if n.name=="memory-chip" {n.name="chip"} }
                let points=(0..<1024).map {i -> [Float] in let p=c.point(Double(i)/1024);return [p.x,p.z]}
                try writer.scene(engine.scene,name:"route-\(c.id)",extra:["length":c.length,"points":points,"cameraExposure":c.look.exposure])
                engine.stop()
            }
        }
        try writer.finish()
        print("ANDROID_SCENE_EXPORT="+out.path)
    }
}

private extension SCNNode {
    @objc func afterlightExportUnflattenedClone() -> SCNNode {clone()}
}

@MainActor private final class AndroidSceneWriter {
    let out:URL
    var geometries:[String:Any]=[:], materials:[String:Any]=[:]
    var geometryCache:[ObjectIdentifier:String]=[:],materialCache:[ObjectIdentifier:String]=[:],imageCache:[ObjectIdentifier:String]=[:]
    // Retain objects so object identifiers cannot be reused between route exports.
    var retained:[AnyObject]=[]
    init(_ out:URL) throws {self.out=out;try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)}
    func hash(_ data:Data)->String {SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()}
    func blob(_ data:Data,_ ext:String) throws -> String {
        let name=hash(data)+"."+ext,url=out.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath:url.path) {try data.write(to:url)}
        return name
    }
    func matrix(_ m:SCNMatrix4)->[Float] {[m.m11,m.m12,m.m13,m.m14,m.m21,m.m22,m.m23,m.m24,m.m31,m.m32,m.m33,m.m34,m.m41,m.m42,m.m43,m.m44]}
    func property(_ p:SCNMaterialProperty) throws -> [String:Any] {
        var value:[String:Any]=["intensity":p.intensity,"transform":matrix(p.contentsTransform),"repeatS":p.wrapS == .repeat,"repeatT":p.wrapT == .repeat,"channel":p.textureComponents.rawValue,"uv":p.mappingChannel]
        if let color=p.contents as? UIColor {var r:CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0;color.getRed(&r,green:&g,blue:&b,alpha:&a);value["color"]=[r,g,b,a]}
        else if let number=p.contents as? NSNumber {value["value"]=number}
        else if let image=p.contents as? UIImage,let cg=image.cgImage {
            let key=ObjectIdentifier(cg)
            if let cached=imageCache[key] {value["image"]=cached}
            else if let png=image.pngData() {let file=try blob(png,"png");imageCache[key]=file;retained.append(cg);value["image"]=file}
        } else if let url=p.contents as? URL {value["image"]=try blob(Data(contentsOf:url),url.pathExtension)}
        return value
    }
    func material(_ m:SCNMaterial) throws -> String {
        let key=ObjectIdentifier(m);if let cached=materialCache[key] {return cached}
        let id="m\(materials.count)";materialCache[key]=id;retained.append(m)
        var d:[String:Any]=["name":m.name ?? "","unlit":m.lightingModel == .constant,"doubleSided":m.isDoubleSided,"opacity":m.transparency,"depthWrite":m.writesToDepthBuffer,"depthTest":m.readsFromDepthBuffer,"blend":m.blendMode.rawValue]
        for (name,p) in [("diffuse",m.diffuse),("normal",m.normal),("roughness",m.roughness),("metalness",m.metalness),("emission",m.emission),("ao",m.ambientOcclusion),("multiply",m.multiply),("clearcoat",m.clearCoat),("clearcoatRoughness",m.clearCoatRoughness)] {d[name]=try property(p)}
        if let surface=m.shaderModifiers?[.surface],surface.contains("discard_fragment") {
            let part=surface.components(separatedBy:" < ").dropFirst().first ?? "0.18"
            d["alphaTest"]=Double(part.prefix {"0123456789.".contains($0)}) ?? 0.18
        }
        if m.name=="Triplanar landscape" {
            for name in ["cliffColor","cliffNormal","soilColor"] {if let p=m.value(forKey:name) as? SCNMaterialProperty {d[name]=try property(p)}}
            for name in ["hasGrass","isDesert","hasSnow"] {if let value=m.value(forKey:name) as? NSNumber {d[name]=value}}
        }
        materials[id]=d;return id
    }
    func geometry(_ original:SCNGeometry) throws -> String {
        let key=ObjectIdentifier(original);if let cached=geometryCache[key] {return cached}
        let id="g\(geometries.count)";geometryCache[key]=id;retained.append(original)
        let g:SCNGeometry
        if original is SCNFloor {
            let plane=SCNPlane(width:4000,height:4000);plane.materials=original.materials
            let node=SCNNode(geometry:plane);node.eulerAngles.x = -.pi/2
            g=node.flattenedClone().geometry ?? plane
        } else if original.sources.isEmpty {
            g=SCNGeometry(mdlMesh:MDLMesh(scnGeometry:original));g.materials=original.materials
        } else {g=original}
        retained.append(g)
        var attrs:[String:Any]=[:],uv=0
        for s in g.sources {
            let name:String
            switch s.semantic {case .vertex:name="position";case .normal:name="normal";case .texcoord:name=uv==0 ? "uv":"uv1";uv+=1;case .color:name="color";case .tangent:name="tangent";default:continue}
            var values=[Float]();values.reserveCapacity(s.vectorCount*s.componentsPerVector)
            s.data.withUnsafeBytes {raw in
                for i in 0..<s.vectorCount {for j in 0..<s.componentsPerVector {
                    let offset=s.dataOffset+i*s.dataStride+j*s.bytesPerComponent
                    var n:Float=0
                    if s.usesFloatComponents {if s.bytesPerComponent==4 {n=raw.loadUnaligned(fromByteOffset:offset,as:Float.self)} else if s.bytesPerComponent==8 {n=Float(raw.loadUnaligned(fromByteOffset:offset,as:Double.self))}}
                    else if s.bytesPerComponent==1 {n=Float(raw.loadUnaligned(fromByteOffset:offset,as:UInt8.self))/255}
                    else if s.bytesPerComponent==2 {n=Float(raw.loadUnaligned(fromByteOffset:offset,as:UInt16.self))}
                    values.append(n)
                }}
            }
            let data=values.withUnsafeBytes{Data($0)}
            attrs[name]=["file":try blob(data,"bin"),"size":s.componentsPerVector]
        }
        var indices=[UInt32](),groups:[[String:Any]]=[]
        for (i,e) in g.elements.enumerated() {
            let data=e.data
            var list=[UInt32]()
            data.withUnsafeBytes {raw in for j in 0..<(data.count/max(1,e.bytesPerIndex)) {let offset=j*e.bytesPerIndex
                let n:UInt32=e.bytesPerIndex==4 ? raw.loadUnaligned(fromByteOffset:offset,as:UInt32.self):e.bytesPerIndex==2 ? UInt32(raw.loadUnaligned(fromByteOffset:offset,as:UInt16.self)):UInt32(raw.loadUnaligned(fromByteOffset:offset,as:UInt8.self));list.append(n)
            }}
            var triangles=[UInt32]()
            if e.primitiveType == .triangles {triangles=Array(list.prefix(e.primitiveCount*3))}
            else if e.primitiveType == .triangleStrip && list.count>=3 {for j in 0..<(list.count-2) {triangles += j%2==0 ? [list[j],list[j+1],list[j+2]]:[list[j+1],list[j],list[j+2]]}}
            groups.append(["start":indices.count,"count":triangles.count,"material":i%max(1,g.materials.count)])
            indices+=triangles
        }
        var definition:[String:Any]=["kind":String(describing:type(of:original)),"attributes":attrs,"index":try blob(indices.withUnsafeBytes{Data($0)},"bin"),"groups":groups,"materials":try g.materials.map{try material($0)}]
        // SceneKit's built-in primitives expose unit meshes; their dimensions
        // are applied by its renderer. Preserve these explicit parameters.
        if let text=original as? SCNText {
            let string=text.string as? String ?? "",font=text.font ?? UIFont.systemFont(ofSize:1)
            let ctFont=CTFontCreateWithName(font.fontName as CFString,font.pointSize,nil)
            let line=CTLineCreateWithAttributedString(NSAttributedString(string:string,attributes:[.font:font]))
            var path=""
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                let count=CTRunGetGlyphCount(run);var glyphs=[CGGlyph](repeating:0,count:count),positions=[CGPoint](repeating:.zero,count:count)
                CTRunGetGlyphs(run,CFRange(location:0,length:0),&glyphs);CTRunGetPositions(run,CFRange(location:0,length:0),&positions)
                for i in 0..<count {guard let outline=CTFontCreatePathForGlyph(ctFont,glyphs[i],nil) else {continue};let offset=positions[i]
                    outline.applyWithBlock {element in
                        let e=element.pointee
                        func xy(_ index:Int)->String {let p=e.points[index];return "\(p.x+offset.x),\(p.y+offset.y)"}
                        switch e.type {case .moveToPoint:path+="M"+xy(0);case .addLineToPoint:path+="L"+xy(0);case .addQuadCurveToPoint:path+="Q"+xy(0)+" "+xy(1);case .addCurveToPoint:path+="C"+xy(0)+" "+xy(1)+" "+xy(2);case .closeSubpath:path+="Z";@unknown default:break}
                    }
                }
            }
            definition["primitive"]=["type":"text","svg":"<svg xmlns=\"http://www.w3.org/2000/svg\"><path fill=\"white\" fill-rule=\"nonzero\" d=\"\(path)\"/></svg>","depth":text.extrusionDepth]
        }
        else if let b=original as? SCNBox {definition["primitive"]=["type":"box","width":b.width,"height":b.height,"depth":b.length,"radius":b.chamferRadius]}
        else if let p=original as? SCNPlane {definition["primitive"]=["type":"plane","width":p.width,"height":p.height]}
        else if let c=original as? SCNCylinder {definition["primitive"]=["type":"cylinder","top":c.radius,"bottom":c.radius,"height":c.height,"segments":c.radialSegmentCount]}
        else if let c=original as? SCNCone {definition["primitive"]=["type":"cylinder","top":c.topRadius,"bottom":c.bottomRadius,"height":c.height,"segments":c.radialSegmentCount]}
        else if let s=original as? SCNSphere {definition["primitive"]=["type":"sphere","radius":s.radius,"segments":s.segmentCount]}
        else if let t=original as? SCNTorus {definition["primitive"]=["type":"torus","ring":t.ringRadius,"pipe":t.pipeRadius,"ringSegments":t.ringSegmentCount,"pipeSegments":t.pipeSegmentCount]}
        else if let c=original as? SCNCapsule {definition["primitive"]=["type":"capsule","radius":c.capRadius,"height":c.height,"segments":c.radialSegmentCount]}
        else if original is SCNFloor {definition["primitive"]=["type":"floor"]}
        geometries[id]=definition
        return id
    }
    func node(_ n:SCNNode) throws -> [String:Any] {
        var d:[String:Any]=["name":n.name ?? "","matrix":matrix(SCNMatrix4Mult(SCNMatrix4Invert(n.pivot),n.transform)),"visible":!n.isHidden,"shadow":n.castsShadow,"order":n.renderingOrder,"children":try n.childNodes.map{try node($0)}]
        if let g=n.geometry {d["geometry"]=try geometry(g)}
        if let l=n.light {d["light"]=["type":l.type.rawValue,"color":try property({let p=SCNMaterial().diffuse;p.contents=l.color;return p}()),"intensity":l.intensity,"shadow":l.castsShadow,"inner":l.spotInnerAngle,"outer":l.spotOuterAngle,"near":l.attenuationStartDistance,"far":l.attenuationEndDistance]}
        return d
    }
    func scene(_ scene:SCNScene,name:String,extra:[String:Any]=[:]) throws {
        var d=extra;d["root"]=try node(scene.rootNode);d["background"]=try property(scene.background);d["environment"]=try property(scene.lightingEnvironment)
        d["fog"]=try property({let p=SCNMaterial().diffuse;p.contents=scene.fogColor;return p}());d["fogNear"]=scene.fogStartDistance;d["fogFar"]=scene.fogEndDistance
        try JSONSerialization.data(withJSONObject:d,options:[.sortedKeys]).write(to:out.appendingPathComponent(name+".json"))
        print("Exported \(name): \(geometries.count) geometries, \(materials.count) materials")
    }
    func finish() throws {try JSONSerialization.data(withJSONObject:["geometries":geometries,"materials":materials],options:[.sortedKeys]).write(to:out.appendingPathComponent("library.json"))}
}
