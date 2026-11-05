import * as T from 'three';
import {HDRLoader} from './vendor/HDRLoader.js';
import {RoundedBoxGeometry} from './vendor/RoundedBoxGeometry.js';
import {RaceEffects} from './effects.js';
import {configureTerrain,configureSea} from './terrain.js';
import {SVGLoader} from './vendor/SVGLoader.js';
import {heading,point,wrap,clamp} from './engine.js';
const base='./art/';
const json=async name=>{const r=await fetch(base+name+'.json',{cache:'no-store'});if(!r.ok)throw new Error('Missing bundled scene: '+name);return r.json();};
const color=(values,fallback=0xffffff)=>values?new T.Color().setRGB(...values.slice(0,3),T.SRGBColorSpace):new T.Color(fallback);
export class SceneRenderer{
 constructor(canvas){
  this.renderer=new T.WebGLRenderer({canvas,antialias:true,powerPreference:'high-performance'});
  this.renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));this.renderer.outputColorSpace=T.SRGBColorSpace;
  this.shaderErrors=0;this.renderer.debug.onShaderError=(gl,program,vertex,fragment)=>{this.shaderErrors++;console.error('Afterlight shader compilation failed: '+gl.getShaderInfoLog(fragment)+' '+gl.getShaderInfoLog(vertex));};
  this.renderer.toneMapping=T.ACESFilmicToneMapping;this.renderer.shadowMap.enabled=true;this.renderer.shadowMap.type=this.renderer.extensions.has('EXT_color_buffer_float')?T.VSMShadowMap:T.BasicShadowMap;
  this.camera=new T.PerspectiveCamera(36,1,.1,1200);this.scene=new T.Scene();this.scene.background=new T.Color(0x172330);
  this.geo=new Map();this.mats=new Map();this.textures=new Map();this.buffers=new Map();this.sceneCache=new Map();this.generation=0;this.time=0;this.focus=2.2;this.wheels=[];this.chips=[];this.seaTime={value:0};
  this.requests=0;this.waiting=[];this.library=json('library');this.resize();window.addEventListener('resize',()=>this.resize());
  canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();window.afterlightSuspend?.();});
  canvas.addEventListener('webglcontextrestored',()=>location.reload());
 }
 resize(){const w=innerWidth,h=innerHeight;this.renderer.setSize(w,h,false);this.camera.aspect=w/h;this.camera.updateProjectionMatrix();}
 async buffer(file){if(!this.buffers.has(file))this.buffers.set(file,(async()=>{
  if(this.requests>=8)await new Promise(resolve=>this.waiting.push(resolve));this.requests++;
  try{const r=await fetch(base+file,{cache:'no-store'});if(!r.ok)throw new Error('Missing bundled data: '+file);return await r.arrayBuffer();}
  catch(error){throw new Error('Cannot load '+file+': '+error.message);}
  finally{this.requests--;this.waiting.shift()?.();}
 })());return this.buffers.get(file);}
 async texture(p,isColor=false){
  if(!p?.image)return null;
  const id=JSON.stringify([p.image,p.transform,p.repeatS,p.repeatT,p.uv,isColor]);
  if(!this.textures.has(id))this.textures.set(id,(async()=>{
   const bytes=await this.buffer(p.image);let t;
   if(p.image.endsWith('.hdr')){const hdr=new HDRLoader().parse(bytes);t=new T.DataTexture(hdr.data,hdr.width,hdr.height,T.RGBAFormat,hdr.type);t.colorSpace=T.LinearSRGBColorSpace;t.minFilter=T.LinearFilter;t.magFilter=T.LinearFilter;t.needsUpdate=true;}
   else {const url=URL.createObjectURL(new Blob([bytes],{type:'image/png'}));try{t=await new T.TextureLoader().loadAsync(url);}finally{URL.revokeObjectURL(url);}}
   t.flipY=false;if(isColor&&!p.image.endsWith('.hdr'))t.colorSpace=T.SRGBColorSpace;
   t.wrapS=p.repeatS?T.RepeatWrapping:T.ClampToEdgeWrapping;t.wrapT=p.repeatT?T.RepeatWrapping:T.ClampToEdgeWrapping;t.anisotropy=Math.min(4,this.renderer.capabilities.getMaxAnisotropy());t.channel=p.uv||0;
   if(p.transform){const m=p.transform;t.matrixAutoUpdate=false;t.matrix.set(m[0],m[4],m[12],m[1],m[5],m[13],0,0,1);}
   return t;
  })());return this.textures.get(id);
 }
 async material(id){
  if(this.mats.has(id))return this.mats.get(id);
  const promise=(async()=>{
   const lib=await this.library,d=lib.materials[id];
   const m=d.unlit?new T.MeshBasicMaterial():d.clearcoat?.value>0?new T.MeshPhysicalMaterial({clearcoat:d.clearcoat.value,clearcoatRoughness:d.clearcoatRoughness?.value??.12}):new T.MeshStandardMaterial();
   m.name=d.name;m.color=color(d.diffuse?.color);if(d.multiply?.color)m.color.multiply(color(d.multiply.color));
   m.opacity=d.opacity*(d.diffuse?.color?.[3]??1);m.transparent=m.opacity<1||d.blend===1||!d.depthWrite;m.depthWrite=d.depthWrite;m.depthTest=d.depthTest;
   m.side=d.doubleSided?T.DoubleSide:T.FrontSide;m.alphaTest=d.alphaTest||0;
   if(d.blend===1)m.blending=T.AdditiveBlending;
   m.map=await this.texture(d.diffuse,true);
   if(!d.unlit){
    m.roughness=d.roughness?.value??.7;m.metalness=d.metalness?.value??0;
    m.emissive=color(d.emission?.color,0);m.emissiveIntensity=d.emission?.intensity??1;
    m.emissiveMap=await this.texture(d.emission,true);if(m.emissiveMap)m.emissive.set(0xffffff);
    m.normalMap=await this.texture(d.normal);if(m.normalMap)m.normalScale.setScalar(d.normal.intensity??1);
    m.roughnessMap=await this.texture(d.roughness);m.metalnessMap=await this.texture(d.metalness);m.aoMap=await this.texture(d.ao);m.aoMapIntensity=d.ao?.intensity??1;
   }
   if(d.multiply?.image){
    const wear=await this.texture(d.multiply,true);
    m.onBeforeCompile=shader=>{
     shader.uniforms.wearMap={value:wear};shader.uniforms.wearTransform={value:wear.matrix};
     shader.vertexShader='varying vec2 vWearUV; uniform mat3 wearTransform;\n'+shader.vertexShader;
     shader.vertexShader=shader.vertexShader.replace('#include <uv_vertex>','#include <uv_vertex>\n vWearUV=(wearTransform*vec3(uv,1.0)).xy;');
     shader.fragmentShader='uniform sampler2D wearMap; varying vec2 vWearUV;\n'+shader.fragmentShader;
     shader.fragmentShader=shader.fragmentShader.replace('#include <map_fragment>','#include <map_fragment>\n diffuseColor.rgb *= texture2D(wearMap,vWearUV).rgb;');
    };
    m.customProgramCacheKey=()=> 'afterlight-wear';
   }
   if(d.name==='Triplanar landscape'&&d.cliffColor)await configureTerrain(m,d,(p,c)=>this.texture(p,c));
   if(d.normal?.transform?.[0]===110)configureSea(m,this.seaTime);
   return m;
  })();this.mats.set(id,promise);return promise;
 }
 async geometry(id){
  if(!this.geo.has(id))this.geo.set(id,(async()=>{
   const lib=await this.library,d=lib.geometries[id];let g=new T.BufferGeometry();
   if(d.primitive){const p=d.primitive;
    switch(p.type){
     case 'text':{const shapes=new SVGLoader().parse(p.svg).paths.flatMap(path=>path.toShapes());g=new T.ExtrudeGeometry(shapes,{depth:p.depth,bevelEnabled:false,curveSegments:8});g.clearGroups();break;}
     case 'box':g=p.radius>0?new RoundedBoxGeometry(p.width,p.height,p.depth,2,Math.min(p.radius,Math.min(p.width,p.height,p.depth)/2)):new T.BoxGeometry(p.width,p.height,p.depth);break;
     case 'plane':g=new T.PlaneGeometry(p.width,p.height);break;
     case 'floor':g=new T.PlaneGeometry(4000,4000);g.rotateX(-Math.PI/2);break;
     case 'cylinder':g=new T.CylinderGeometry(p.top,p.bottom,p.height,p.segments);break;
     case 'sphere':g=new T.SphereGeometry(p.radius,p.segments,Math.max(8,p.segments/2));break;
     case 'torus':g=new T.TorusGeometry(p.ring,p.pipe,p.pipeSegments,p.ringSegments);g.rotateX(Math.PI/2);break;
     case 'capsule':g=new T.CapsuleGeometry(p.radius,Math.max(0,p.height-2*p.radius),8,p.segments);break;
    }
    let materials=await Promise.all(d.materials.map(id=>this.material(id)));
    if(p.type==='box'&&materials.length>1)materials=[1,3,4,5,0,2].map(i=>materials[i%materials.length]);
    if(materials.length===1)g.clearGroups();
    return {g,materials};
   }
   await Promise.all(Object.entries(d.attributes).map(async([k,a])=>g.setAttribute(k,new T.BufferAttribute(new Float32Array(await this.buffer(a.file)),a.size))));
   const index=new Uint32Array(await this.buffer(d.index));if(index.length)g.setIndex(new T.BufferAttribute(index,1));
   for(const group of d.groups)g.addGroup(group.start,group.count,group.material);
   if(g.attributes.position&&!g.attributes.normal)g.computeVertexNormals();
   if(g.attributes.position)g.computeBoundingSphere();
   return {g,materials:await Promise.all(d.materials.map(id=>this.material(id)))};
  })());return this.geo.get(id);
 }
 async node(d){
  let n;
  if(d.light){const l=d.light,c=color(l.color?.color);if(l.type==='ambient')n=new T.AmbientLight(c,l.intensity/1000*Math.PI);
   else if(l.type==='directional'){n=new T.DirectionalLight(c,l.intensity/1000*Math.PI);n.target.position.set(0,0,-1);n.add(n.target);n.shadow.camera.left=-75;n.shadow.camera.right=75;n.shadow.camera.top=75;n.shadow.camera.bottom=-75;n.shadow.camera.far=600;}
   else {n=new T.SpotLight(c,l.intensity/Math.PI,Math.max(l.far||0,100),Math.min(Math.PI/2,l.outer/2*Math.PI/180),1-(l.inner||45)/(l.outer||105),2);n.target.position.set(0,0,-1);n.add(n.target);}
   n.castShadow=!!l.shadow;n.shadow?.mapSize.set(1024,1024);if(n.shadow){n.shadow.bias=-.00015;n.shadow.normalBias=.035;n.shadow.radius=2.5;n.shadow.blurSamples=4;}
  }else if(d.geometry){const {g,materials}=await this.geometry(d.geometry);n=g.attributes.position?new T.Mesh(g,materials.length===1?materials[0]:materials.length?materials:new T.MeshStandardMaterial({color:0xaaaaaa})):new T.Group();n.castShadow=!!d.shadow;n.receiveShadow=true;}
  else n=new T.Group();
  n.name=d.name;n.visible=d.visible;n.renderOrder=d.order||0;
  if(d.matrix){n.matrix.fromArray(d.matrix);n.matrix.decompose(n.position,n.quaternion,n.scale);}
  const children=await Promise.all((d.children||[]).map(x=>this.node(x)));if(children.length)n.add(...children);
  return n;
 }
 async buildScene(name){
  const d=await json(name),s=new T.Scene();s.add(await this.node(d.root));s.background=d.background?.image?await this.texture(d.background,true):color(d.background?.color,0x172330);
  if(s.background?.isTexture)s.background.mapping=T.EquirectangularReflectionMapping;
  if(d.environment?.image){s.environment=await this.texture(d.environment,true);s.environment.mapping=T.EquirectangularReflectionMapping;s.environmentIntensity=d.environment.intensity??.65;}
  if(d.fogFar>d.fogNear)s.fog=new T.Fog(color(d.fog?.color),d.fogNear,d.fogFar);
  if(name.startsWith('route-')||name==='studio')this.instanceScenery(s);
  return {scene:s,data:d};
 }
 instanceScenery(scene){
  scene.updateMatrixWorld(true);const groups=new Map();
  scene.traverse(n=>{if(!n.isMesh)return;for(let p=n;p;p=p.parent)if(p.name==='chip')return;
   const key=[n.geometry.uuid,...(Array.isArray(n.material)?n.material:[n.material]).map(m=>m.uuid),n.castShadow,n.renderOrder].join('|');
   if(!groups.has(key))groups.set(key,[]);groups.get(key).push(n);
  });
  for(const nodes of groups.values())if(nodes.length>=3){const first=nodes[0],mesh=new T.InstancedMesh(first.geometry,first.material,nodes.length);mesh.castShadow=first.castShadow;mesh.receiveShadow=true;mesh.renderOrder=first.renderOrder;nodes.forEach((n,i)=>{mesh.setMatrixAt(i,n.matrixWorld);n.removeFromParent();});mesh.computeBoundingSphere();scene.add(mesh);}
 }
 async showroom(car,focus=2.2){
  const generation=++this.generation;this.resetScene();this.mode='loading';
  const [{scene},model]=await Promise.all([this.buildScene('studio'),this.buildScene('car-'+car.id)]);
  if(generation!==this.generation)return;
  this.scene=scene;this.player=model.scene.getObjectByName('player');this.scene.add(this.player);this.focus=focus;this.time=0;this.mode='showroom';this.renderer.toneMappingExposure=2**(-.4);
  this.renderer.domElement.style.filter='none';
  this.camera.fov=36;this.camera.position.set(3.7,2.15,6.7);this.camera.lookAt(focus,.65,.6);this.camera.updateProjectionMatrix();
  this.scene.add(this.shadow(this.player));
 }
 shadow(car){const bounds=new T.Box3().setFromObject(car),size=bounds.getSize(new T.Vector3());const canvas=document.createElement('canvas');canvas.width=canvas.height=128;const ctx=canvas.getContext('2d'),gradient=ctx.createRadialGradient(64,64,0,64,64,64);gradient.addColorStop(0,'#000a');gradient.addColorStop(.55,'#0007');gradient.addColorStop(1,'#0000');ctx.fillStyle=gradient;ctx.fillRect(0,0,128,128);const m=new T.MeshBasicMaterial({map:new T.CanvasTexture(canvas),transparent:true,depthWrite:false});const mesh=new T.Mesh(new T.PlaneGeometry(size.x*1.4,size.z*1.15),m);mesh.rotation.x=-Math.PI/2;mesh.position.y=.13;return mesh;}
 async race(engine){
  const generation=++this.generation;this.resetScene();this.mode='loading';
  const [{scene,data},...models]=await Promise.all([this.buildScene('route-'+engine.c.id),...([engine.car,...engine.rivalCars].map(c=>this.buildScene('car-'+c.id)))]);
  if(generation!==this.generation)return false;
  this.scene=scene;engine.c.length=data.length;engine.c.points=data.points;this.player=models[0].scene.getObjectByName('player');this.rivalNodes=models.slice(1).map(x=>x.scene.getObjectByName('player'));
  const vehicles=[this.player,...this.rivalNodes];this.shadows=vehicles.map(car=>this.shadow(car));scene.add(...vehicles,...this.shadows);
  engine.body={halfWidth:models[0].data.halfWidth,halfLength:models[0].data.halfLength};models.slice(1).forEach((m,i)=>engine.rivals[i].body={halfWidth:m.data.halfWidth,halfLength:m.data.halfLength});
  this.chips=[];this.wheels=[];scene.traverse(n=>{if(n.name==='chip')this.chips.push(n);if(n.name==='rolling-wheel')this.wheels.push(n);});
  this.smoothHeading=heading(engine.c,0);this.boostBlend=0;this.camera.fov=2*Math.atan(Math.tan(68*Math.PI/360)/this.camera.aspect)*180/Math.PI;this.camera.updateProjectionMatrix();
  const grade=[[1.1,.04],[1.15,.06],[1.08,.05],[1.03,.03]][engine.c.environment];this.renderer.domElement.style.filter=`saturate(${grade[0]}) contrast(${1+grade[1]})`;
  this.renderer.toneMappingExposure=2**(data.cameraExposure||0);this.mode='race';this.engine=engine;this.effects=new RaceEffects(scene,this.player,this.camera,engine.c.environment);this.update(engine,0);return true;
 }
 update(e,dt){
  this.seaTime.value=e.elapsed;
  const c=e.c,place=(n,p,lane,air,lateral=0,wreck=0)=>{const xy=point(c,p,lane),h=heading(c,p);n.position.set(xy[0],air.height,xy[1]);n.rotation.set(air.airborne?-air.velocity*.012:air.ramp!==null?-.13:0,h+lateral,air.roll,'YXZ');if(wreck){const t=2.6-wreck;n.position.y+=Math.max(0,2.2*Math.sin(Math.min(Math.PI,t*2.2)));n.rotation.set(t*3.1,h+t*4.5,t*5.2);}};
  place(this.player,e.progress,e.lane,e.air,e.lateral*.022*(e.drifting?2:1));
  e.rivals.forEach((r,i)=>{this.rivalNodes[i].visible=!r.out;place(this.rivalNodes[i],r.progress,r.lane,r.air,0,r.wreck);});
  [this.player,...this.rivalNodes].forEach((n,i)=>{this.shadows[i].position.set(n.position.x,.13,n.position.z);this.shadows[i].rotation.set(-Math.PI/2,0,-n.rotation.y);this.shadows[i].visible=n.visible;});
  this.chips.forEach((n,i)=>{n.visible=!e.collectedChips.has(i);n.rotation.y+=dt*1.6;});this.wheels.forEach(n=>n.rotation.x+=e.speed*dt/.465);
  const h=heading(c,e.progress),difference=Math.atan2(Math.sin(h-this.smoothHeading),Math.cos(h-this.smoothHeading));this.smoothHeading+=difference*Math.min(1,dt*8);this.boostBlend+=((e.boosting?1:0)-this.boostBlend)*(1-Math.exp(-dt*7));
  const p=point(c,e.progress,e.lane),distance=8.3+1.2*this.boostBlend;
  this.camera.position.set(p[0]-Math.sin(this.smoothHeading)*distance,2.8+e.air.height*.75,p[1]-Math.cos(this.smoothHeading)*distance);
  this.camera.lookAt(p[0]+Math.sin(h)*5,.6+e.air.height*.85,p[1]+Math.cos(h)*5);this.camera.fov=2*Math.atan(Math.tan((68+8*this.boostBlend)*Math.PI/360)/this.camera.aspect)*180/Math.PI;this.camera.updateProjectionMatrix();
  this.effects?.update(e,dt);
  this.scene.traverse(n=>{if(n.isDirectionalLight){const direction=new T.Vector3(0,0,1).applyQuaternion(n.quaternion);n.position.copy(this.player.position).addScaledVector(direction,120);}});
 }
 render(dt){if(this.mode==='showroom'){this.time+=dt;this.player.rotation.y=this.time*2*Math.PI/28;}this.renderer.render(this.scene,this.camera);}
 leave(){this.generation++;this.engine=null;this.effects?.dispose();this.effects=null;this.chips=[];this.wheels=[];}
 resetScene(){
  this.effects?.dispose();this.effects=null;
  for(const p of this.geo.values())p.then(({g})=>g.dispose()).catch(()=>{});
  for(const p of this.mats.values())p.then(m=>m.dispose()).catch(()=>{});
  for(const p of this.textures.values())p.then(t=>t.dispose()).catch(()=>{});
  this.geo.clear();this.mats.clear();this.textures.clear();this.buffers.clear();this.renderer.renderLists.dispose();
  this.scene=new T.Scene();this.scene.background=new T.Color(0x172330);
 }
}
