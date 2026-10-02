import XCTest
import SceneKit
@testable import Afterlight

final class EnvironmentArtTests:XCTestCase {
    @MainActor func testPitchedRoofHasClosedGablesAndOutwardFaces() throws {
        let roof=ArchitectureArt.pitchedRoof(width:12,depth:10,rise:3,wall:material(0xFFFFFF),cover:material(0xBC643A))
        let g=try XCTUnwrap(roof.geometry),source=try XCTUnwrap(g.sources(for:.vertex).first)
        func point(_ index:Int)->SIMD3<Float> {
            source.data.withUnsafeBytes {b in
                let offset=source.dataOffset+index*source.dataStride
                return SIMD3(b.loadUnaligned(fromByteOffset:offset,as:Float.self),b.loadUnaligned(fromByteOffset:offset+4,as:Float.self),b.loadUnaligned(fromByteOffset:offset+8,as:Float.self))
            }
        }
        func key(_ p:SIMD3<Float>)->String {"\(Int(p.x*1000)),\(Int(p.y*1000)),\(Int(p.z*1000))"}
        var edges:[String:Int]=[:];var volume:Float=0
        for element in g.elements {
            let indices=element.data.withUnsafeBytes {b in (0..<element.primitiveCount*3).map {Int(b.loadUnaligned(fromByteOffset:$0*4,as:Int32.self))}}
            for i in stride(from:0,to:indices.count,by:3) {
                let a=point(indices[i]),b=point(indices[i+1]),c=point(indices[i+2])
                volume += simd_dot(a,simd_cross(b,c))/6
                for (p,q) in [(a,b),(b,c),(c,a)] {edges[[key(p),key(q)].sorted().joined(separator:"|") ,default:0] += 1}
            }
        }
        XCTAssertTrue(edges.values.allSatisfy {$0==2},"Every edge needs two incident faces; open gables leave visible holes")
        XCTAssertEqual(volume,180,accuracy:0.001,"Closed roof volume and winding must match a triangular prism")
        XCTAssertFalse(g.materials.contains {$0.isDoubleSided},"Backface hiding must not conceal an open roof")
    }

    @MainActor func testLandscapeAssetsAndRidgeNormals() throws {
        for name in ["ridge-rock","ridge-rock-normal","ridge-rock-roughness","terracotta","terracotta-normal","terracotta-roughness"] {
            let image=try XCTUnwrap(SurfaceLibrary.image(name),name)
            XCTAssertGreaterThanOrEqual(image.size.width,2048)
        }
        let ridge=LandscapeArt.ridge(radius:200,height:160,seed:17,vegetated:true,desert:false,snow:false)
        let source=try XCTUnwrap(ridge.geometry?.sources(for:.normal).first)
        var steep=0
        for i in 0..<source.vectorCount {
            let n:SIMD3<Float>=source.data.withUnsafeBytes {b in let o=source.dataOffset+i*source.dataStride;return SIMD3(b.loadUnaligned(fromByteOffset:o,as:Float.self),b.loadUnaligned(fromByteOffset:o+4,as:Float.self),b.loadUnaligned(fromByteOffset:o+8,as:Float.self))}
            XCTAssertTrue(n.x.isFinite && n.y.isFinite && n.z.isFinite)
            XCTAssertEqual(simd_length(n),1,accuracy:0.001)
            XCTAssertGreaterThan(n.y,0)
            if n.y<0.7 {steep += 1}
        }
        XCTAssertGreaterThan(steep,100,"Ridges need real relief, not a flat texture")
        XCTAssertFalse(ridge.castsShadow,"Distant mountains must not pollute the near shadow map")
    }
}
