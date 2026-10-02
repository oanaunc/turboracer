import SceneKit
import UIKit

/// A small native loader for the uncompressed glTF assets bundled with the game.
/// Preserves authored normals, UV sets, hierarchy and PBR textures instead of
/// reducing a professionally authored vehicle to a single flat material.
@MainActor enum GLBAsset {
    static func load(_ name: String) -> SCNNode? {
        let publicFile=Bundle.main.url(forResource:name,withExtension:"glb").flatMap {try? Data(contentsOf:$0)}
        guard let file=ArtVault.model(name) ?? publicFile,file.count>20 else{return nil}
        func uint(_ offset:Int)->Int {file.withUnsafeBytes{Int($0.loadUnaligned(fromByteOffset:offset,as:UInt32.self))}}
        let length=uint(12)
        guard let json=try? JSONSerialization.jsonObject(with:file.subdata(in:20..<20+length)) as? [String:Any] else{return nil}
        let start=28+length
        guard start<=file.count else{return nil}
        let binary=file.subdata(in:start..<file.count)
        let views=json["bufferViews"] as? [[String:Any]] ?? [],accessors=json["accessors"] as? [[String:Any]] ?? []
        let textures=json["textures"] as? [[String:Any]] ?? [],images=json["images"] as? [[String:Any]] ?? []
        var decoded:[Int:UIImage]=[:]
        func texture(_ info:Any?)->UIImage? {
            guard let info=info as? [String:Any],let index=info["index"] as? Int,index<textures.count,let source=textures[index]["source"] as? Int,source<images.count else{return nil}
            if let cached=decoded[source] {return cached}
            guard let view=images[source]["bufferView"] as? Int,view<views.count,let size=views[view]["byteLength"] as? Int else{return nil}
            let offset=views[view]["byteOffset"] as? Int ?? 0
            guard offset+size<=binary.count,let image=UIImage(data:binary.subdata(in:offset..<offset+size)) else{return nil}
            let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=false
            let rgba=UIGraphicsImageRenderer(size:image.size,format:format).image { _ in image.draw(in:CGRect(origin:.zero,size:image.size)) }
            decoded[source]=rgba;return rgba
        }
        func color(_ values:[Double])->UIColor {UIColor(red:values[0],green:values[1],blue:values[2],alpha:values.count>3 ? values[3]:1)}
        let materials=(json["materials"] as? [[String:Any]] ?? []).map { definition -> SCNMaterial in
            let m=SCNMaterial();m.name=definition["name"] as? String;m.lightingModel = .physicallyBased
            let p=definition["pbrMetallicRoughness"] as? [String:Any] ?? [:]
            let factor=p["baseColorFactor"] as? [Double] ?? [1,1,1,1]
            m.diffuse.contents=texture(p["baseColorTexture"]) ?? color(factor)
            if p["baseColorTexture"] != nil {m.multiply.contents=color(factor)}
            m.metalness.contents=p["metallicFactor"] as? Double ?? 1;m.roughness.contents=p["roughnessFactor"] as? Double ?? 1
            if let packed=texture(p["metallicRoughnessTexture"]) {m.metalness.contents=packed;m.metalness.textureComponents = .blue;m.roughness.contents=packed;m.roughness.textureComponents = .green}
            m.normal.contents=texture(definition["normalTexture"])
            m.ambientOcclusion.contents=texture(definition["occlusionTexture"]);m.ambientOcclusion.textureComponents = .red
            if let ao=definition["occlusionTexture"] as? [String:Any] {m.ambientOcclusion.mappingChannel=ao["texCoord"] as? Int ?? 0}
            let emissive=definition["emissiveFactor"] as? [Double] ?? [0,0,0];m.emission.contents=texture(definition["emissiveTexture"]) ?? color(emissive)
            for (property,key) in [(m.diffuse,"baseColorTexture"),(m.metalness,"metallicRoughnessTexture"),(m.roughness,"metallicRoughnessTexture"),(m.normal,"normalTexture"),(m.emission,"emissiveTexture"),(m.ambientOcclusion,"occlusionTexture")] {
                let info=(p[key] ?? definition[key]) as? [String:Any] ?? [:]
                let ext=info["extensions"] as? [String:Any] ?? [:],transform=ext["KHR_texture_transform"] as? [String:Any] ?? [:]
                let scale=transform["scale"] as? [Double] ?? [1,1]
                // SceneKit maps UIImage contents in the glTF image orientation.
                // Flipping V here cut away the atlas foliage and inverted vehicle textures.
                let matrix=SCNMatrix4MakeScale(Float(scale[0]),Float(scale[1]),1)
                property.contentsTransform=matrix;property.wrapS = .repeat;property.wrapT = .repeat
                property.mappingChannel=info["texCoord"] as? Int ?? 0
            }
            if let normal=definition["normalTexture"] as? [String:Any] {m.normal.intensity=normal["scale"] as? CGFloat ?? 1}
            m.isDoubleSided=definition["doubleSided"] as? Bool ?? false
            let alpha=m.name=="PalmAtlas" ? "MASK":(definition["alphaMode"] as? String ?? "OPAQUE")
            if alpha=="MASK" {let cutoff=definition["alphaCutoff"] as? Double ?? 0.5;m.shaderModifiers=[.fragment:"if (_surface.diffuse.a < \(cutoff)) discard_fragment();"];m.transparencyMode = .aOne}
            if alpha=="BLEND" {m.transparency=factor.count>3 ? factor[3]:1;m.writesToDepthBuffer=false;m.blendMode = .alpha}
            // Trademark-bearing plates and dashboard marks are replaced with plain trim.
            if m.name=="License" || m.name=="Dashboard" {m.diffuse.contents=UIColor(hex:0x111820);m.emission.contents=UIColor.black;m.multiply.contents=UIColor.white}
            return m
        }
        var vertexBuffers:[Int:Data]=[:]
        func source(_ index:Int,_ semantic:SCNGeometrySource.Semantic)->SCNGeometrySource? {
            let a=accessors[index];guard let v=a["bufferView"] as? Int,let count=a["count"] as? Int else{return nil}
            let components=a["type"] as? String=="VEC2" ? 2:3
            let viewOffset=views[v]["byteOffset"] as? Int ?? 0,viewLength=views[v]["byteLength"] as? Int ?? 0
            if vertexBuffers[v]==nil {vertexBuffers[v]=binary.subdata(in:viewOffset..<viewOffset+viewLength)}
            let offset=a["byteOffset"] as? Int ?? 0
            return SCNGeometrySource(data:vertexBuffers[v]!,semantic:semantic,vectorCount:count,usesFloatComponents:true,componentsPerVector:components,bytesPerComponent:4,dataOffset:offset,dataStride:views[v]["byteStride"] as? Int ?? components*4)
        }
        let meshes=(json["meshes"] as? [[String:Any]] ?? []).map { mesh -> SCNNode in
            let container=SCNNode()
            for p in mesh["primitives"] as? [[String:Any]] ?? [] {
                guard let attributes=p["attributes"] as? [String:Int],let position=attributes["POSITION"],let index=p["indices"] as? Int else{continue}
                var sources:[SCNGeometrySource]=[]
                for (key,semantic) in [("POSITION",SCNGeometrySource.Semantic.vertex),("NORMAL",.normal),("TEXCOORD_0",.texcoord),("TEXCOORD_1",.texcoord)] {if let i=attributes[key],let s=source(i,semantic) {sources.append(s)}}
                guard attributes["POSITION"]==position else{continue}
                let a=accessors[index];guard let view=a["bufferView"] as? Int,let count=a["count"] as? Int else{continue}
                let bytes=(a["componentType"] as? Int)==5125 ? 4:2,offset=(views[view]["byteOffset"] as? Int ?? 0)+(a["byteOffset"] as? Int ?? 0)
                let element=SCNGeometryElement(data:binary.subdata(in:offset..<offset+count*bytes),primitiveType:.triangles,primitiveCount:count/3,bytesPerIndex:bytes)
                let g=SCNGeometry(sources:sources,elements:[element]);if let material=p["material"] as? Int {g.materials=[materials[material]]}
                container.addChildNode(SCNNode(geometry:g))
            }
            return container
        }
        let definitions=json["nodes"] as? [[String:Any]] ?? []
        let nodes=definitions.map { d -> SCNNode in
            let n=(d["mesh"] as? Int).map{meshes[$0].clone()} ?? SCNNode();n.name=d["name"] as? String
            if let matrix=(d["matrix"] as? [NSNumber])?.map { $0.floatValue },matrix.count==16 {n.simdTransform=simd_float4x4(SIMD4(matrix[0],matrix[1],matrix[2],matrix[3]),SIMD4(matrix[4],matrix[5],matrix[6],matrix[7]),SIMD4(matrix[8],matrix[9],matrix[10],matrix[11]),SIMD4(matrix[12],matrix[13],matrix[14],matrix[15]))}
            else {if let v=(d["translation"] as? [NSNumber])?.map { $0.floatValue } {n.position=SCNVector3(v[0],v[1],v[2])};if let v=(d["scale"] as? [NSNumber])?.map { $0.floatValue } {n.scale=SCNVector3(v[0],v[1],v[2])};if let v=(d["rotation"] as? [NSNumber])?.map { $0.floatValue } {n.simdOrientation=simd_quatf(ix:v[0],iy:v[1],iz:v[2],r:v[3])}}
            return n
        }
        for (i,d) in definitions.enumerated() {for child in d["children"] as? [Int] ?? [] {nodes[i].addChildNode(nodes[child])}}
        let root=SCNNode();let sceneIndex=json["scene"] as? Int ?? 0;let scenes=json["scenes"] as? [[String:Any]] ?? []
        for index in scenes[sceneIndex]["nodes"] as? [Int] ?? [] {root.addChildNode(nodes[index])}
        return root
    }
}
