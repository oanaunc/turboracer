import SceneKit
import UIKit

/// Shared terrain art: metre-scale triplanar projection, rather than stretching
/// a horizontal photograph over a steep slope. Distant ridges do not cast shadows.
@MainActor enum LandscapeArt {
    private static var materials: [String:SCNMaterial] = [:]
    static func terrainMaterial(vegetated:Bool,desert:Bool,snow:Bool) -> SCNMaterial {
        let key="\(vegetated)-\(desert)-\(snow)"
        if let cached=materials[key] {return cached}
        let m=SCNMaterial();m.name="Triplanar landscape";m.lightingModel = .physicallyBased
        m.diffuse.contents=UIColor.white;m.roughness.contents=0.92;m.metalness.contents=0
        for (key,name) in [("cliffColor","ridge-rock"),("cliffNormal","ridge-rock-normal"),("soilColor",desert ? "sand":"terrain-grass")] {
            let p=SCNMaterialProperty(contents:SurfaceLibrary.image(name) ?? UIColor.gray)
            p.wrapS = .repeat;p.wrapT = .repeat;p.mipFilter = .linear;p.maxAnisotropy=8
            m.setValue(p,forKey:key)
        }
        m.setValue(vegetated ? 1.0:0.0,forKey:"hasGrass")
        m.setValue(desert ? 1.0:0.0,forKey:"isDesert")
        m.setValue(snow ? 1.0:0.0,forKey:"hasSnow")
        m.shaderModifiers=[.geometry:"""
        #pragma varyings
        float3 landscapePosition;
        float3 landscapeNormal;
        #pragma body
        out.landscapePosition = _geometry.position.xyz;
        out.landscapeNormal = _geometry.normal;
        """,.surface:"""
        #pragma arguments
        texture2d<float> cliffColor;
        texture2d<float> cliffNormal;
        texture2d<float> soilColor;
        float hasGrass;
        float isDesert;
        float hasSnow;
        #pragma body
        constexpr sampler terrainSampler(coord::normalized, address::repeat, filter::linear, mip_filter::linear, max_anisotropy(8));
        float3 p = in.landscapePosition;
        float3 n = normalize(in.landscapeNormal);
        float3 w = pow(abs(n),float3(4.0));
        w /= max(w.x+w.y+w.z,0.001);
        float3 q = p / 38.0;
        float3 stone = cliffColor.sample(terrainSampler,q.zy).rgb*w.x
                     + cliffColor.sample(terrainSampler,q.xz).rgb*w.y
                     + cliffColor.sample(terrainSampler,q.xy).rgb*w.z;
        // A second, broad scale breaks the wallpaper repetition without a new map.
        float3 macro = cliffColor.sample(terrainSampler,p.xz/143.0+0.37).rgb;
        stone *= mix(float3(0.78),float3(1.18),macro);
        float grey = dot(stone,float3(0.2126,0.7152,0.0722));
        stone = mix(stone,mix(float3(grey),float3(grey)*float3(1.65,0.91,0.50),isDesert),0.65);
        float3 soil = soilColor.sample(terrainSampler,p.xz/7.0).rgb;
        float patch = 0.5+0.25*sin(p.x*0.019+p.z*0.026)+0.25*cos(p.z*0.031-p.x*0.013);
        float coverage = smoothstep(0.68,0.94,n.y)*mix(0.68,0.98,patch)*hasGrass;
        float3 albedo = mix(stone,soil*float3(0.72,1.12,0.64),coverage);
        float snowCover = hasSnow*smoothstep(0.45,0.82,n.y)*smoothstep(12.0,65.0,p.y+patch*20.0);
        albedo = mix(albedo,float3(0.56,0.65,0.72),snowCover);
        _surface.diffuse = float4(albedo,1.0);
        float3 nx = cliffNormal.sample(terrainSampler,q.zy).xyz*2.0-1.0;
        float3 ny = cliffNormal.sample(terrainSampler,q.xz).xyz*2.0-1.0;
        float3 nz = cliffNormal.sample(terrainSampler,q.xy).xyz*2.0-1.0;
        float3 perturb = float3(0,nx.y,nx.x)*w.x + float3(ny.x,0,ny.y)*w.y + float3(nz.x,nz.y,0)*w.z;
        float3 detailNormal = normalize(n + perturb*0.38*(1.0-snowCover));
        _surface.normal = normalize((scn_node.normalTransform*float4(detailNormal,0.0)).xyz);
        _surface.roughness = 0.94;
        """]
        materials[key]=m;return m
    }

    // Deterministic value noise with continuous derivatives, independent of frame time.
    static func noise(_ x:Float,_ z:Float,seed:Int) -> Float {
        func hash(_ x:Int,_ z:Int)->Float {
            var h=UInt32(truncatingIfNeeded:x &* 374761393 &+ z &* 668265263 &+ seed &* 144269)
            h=(h ^ (h >> 13)) &* 1274126177
            return Float((h ^ (h >> 16)) & 0xffff)/65535
        }
        let ix=Int(floor(x)),iz=Int(floor(z)),fx=x-Float(ix),fz=z-Float(iz)
        let u=fx*fx*(3-2*fx),v=fz*fz*(3-2*fz)
        let a=hash(ix,iz)*(1-u)+hash(ix+1,iz)*u
        let b=hash(ix,iz+1)*(1-u)+hash(ix+1,iz+1)*u
        return a*(1-v)+b*v
    }
    static func ridge(radius:Float,height:Float,seed:Int,vegetated:Bool,desert:Bool,snow:Bool) -> SCNNode {
        let steps=72
        func elevation(_ x:Float,_ z:Float) -> Float {
            let u=x/radius,v=z/radius
            let edge=max(0,1-max(abs(u),abs(v)));let fade=min(1,edge*4)
            let warp=noise(u*3+8,v*3-2,seed:seed)*0.4-0.2
            let spine=max(0,1-abs(v+warp)*1.35)
            let broad=0.46+0.54*noise(u*3.8+4,v*3.8,seed:seed+7)
            let erosion=abs(noise(u*12+9,v*12,seed:seed+2)*2-1)
            let fine=noise(u*31,v*31,seed:seed+11)
            return max(0,height*fade*(pow(spine,1.25)*broad + erosion*0.12+fine*0.035)-0.2)
        }
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uv:[CGPoint]=[],indices:[Int32]=[]
        for row in 0...steps {for col in 0...steps {
            let x=(Float(col)/Float(steps)*2-1)*radius,z=(Float(row)/Float(steps)*2-1)*radius
            let dx=(elevation(x+0.5,z)-elevation(x-0.5,z)),dz=(elevation(x,z+0.5)-elevation(x,z-0.5))
            vertices.append(SCNVector3(x,elevation(x,z),z));normals.append(vector(simd_normalize(SIMD3(-dx,1,-dz))))
            uv.append(CGPoint(x:Double(x)/38,y:Double(z)/38))
        }}
        for row in 0..<steps {for col in 0..<steps {let a=Int32(row*(steps+1)+col),c=a+Int32(steps+1);indices += [a,c,a+1,a+1,c,c+1]}}
        // Match normals to the rendered triangles, not sub-grid noise derivatives.
        var accumulated=Array(repeating:SIMD3<Float>.zero,count:vertices.count)
        for i in stride(from:0,to:indices.count,by:3) {
            let a=Int(indices[i]),b=Int(indices[i+1]),c=Int(indices[i+2])
            func point(_ i:Int)->SIMD3<Float> {let p=vertices[i];return SIMD3(p.x,p.y,p.z)}
            let n=simd_cross(point(b)-point(a),point(c)-point(a));accumulated[a] += n;accumulated[b] += n;accumulated[c] += n
        }
        normals=accumulated.map {vector(simd_normalize($0))}
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        g.materials=[terrainMaterial(vegetated:vegetated,desert:desert,snow:snow)]
        let node=SCNNode(geometry:g);node.name="landscape-ridge";node.castsShadow=false;return node
    }
}
