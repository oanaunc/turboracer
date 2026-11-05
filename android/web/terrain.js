// GLSL translation of LandscapeArt.terrainMaterial's original SceneKit shader.
export async function configureTerrain(material,d,texture){
 const [cliff,normal,soil]=await Promise.all([texture(d.cliffColor,true),texture(d.cliffNormal),texture(d.soilColor,true)]);
 material.onBeforeCompile=shader=>{
  Object.assign(shader.uniforms,{landCliff:{value:cliff},landNormal:{value:normal},landSoil:{value:soil},hasGrass:{value:d.hasGrass||0},isDesert:{value:d.isDesert||0},hasSnow:{value:d.hasSnow||0}});
  shader.vertexShader='varying vec3 landscapePosition;varying vec3 landscapeNormal;\n'+shader.vertexShader;
  shader.vertexShader=shader.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\n landscapePosition=position;landscapeNormal=normal;');
  shader.fragmentShader='varying vec3 landscapePosition;varying vec3 landscapeNormal;uniform sampler2D landCliff;uniform sampler2D landNormal;uniform sampler2D landSoil;uniform float hasGrass;uniform float isDesert;uniform float hasSnow;uniform mat3 normalMatrix;\n'+shader.fragmentShader;
  shader.fragmentShader=shader.fragmentShader.replace('#include <map_fragment>',`#include <map_fragment>
   vec3 lp=landscapePosition;vec3 ln=normalize(landscapeNormal);vec3 lw=pow(abs(ln),vec3(4.0));lw/=max(lw.x+lw.y+lw.z,0.001);vec3 lq=lp/38.0;
   vec3 stone=texture2D(landCliff,lq.zy).rgb*lw.x+texture2D(landCliff,lq.xz).rgb*lw.y+texture2D(landCliff,lq.xy).rgb*lw.z;
   vec3 macro=texture2D(landCliff,lp.xz/143.0+0.37).rgb;stone*=mix(vec3(0.78),vec3(1.18),macro);
   float grey=dot(stone,vec3(0.2126,0.7152,0.0722));stone=mix(stone,mix(vec3(grey),vec3(grey)*vec3(1.65,0.91,0.50),isDesert),0.65);
   vec3 soil=texture2D(landSoil,lp.xz/7.0).rgb;float landPatch=0.5+0.25*sin(lp.x*0.019+lp.z*0.026)+0.25*cos(lp.z*0.031-lp.x*0.013);
   float coverage=smoothstep(0.68,0.94,ln.y)*mix(0.68,0.98,landPatch)*hasGrass;
   vec3 albedo=mix(stone,soil*vec3(0.72,1.12,0.64),coverage);float snowCover=hasSnow*smoothstep(0.45,0.82,ln.y)*smoothstep(12.0,65.0,lp.y+landPatch*20.0);
   diffuseColor=vec4(mix(albedo,vec3(0.56,0.65,0.72),snowCover),1.0);
  `);
  shader.fragmentShader=shader.fragmentShader.replace('#include <normal_fragment_begin>',`#include <normal_fragment_begin>
   vec3 nx=texture2D(landNormal,lq.zy).xyz*2.0-1.0;vec3 ny=texture2D(landNormal,lq.xz).xyz*2.0-1.0;vec3 nz=texture2D(landNormal,lq.xy).xyz*2.0-1.0;
   vec3 perturb=vec3(0.0,nx.y,nx.x)*lw.x+vec3(ny.x,0.0,ny.y)*lw.y+vec3(nz.x,nz.y,0.0)*lw.z;
   vec3 detailNormal=normalize(ln+perturb*0.38*(1.0-snowCover));normal=normalize(normalMatrix*detailNormal);
  `);
 };
 material.customProgramCacheKey=()=> 'afterlight-landscape-v1';
}
export function configureSea(material,time){
 material.onBeforeCompile=shader=>{
  shader.uniforms.seaTime=time;
  shader.vertexShader='varying vec2 seaPosition;\n'+shader.vertexShader;
  shader.vertexShader=shader.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\n seaPosition=position.xy;');
  shader.fragmentShader='varying vec2 seaPosition;uniform float seaTime;\n'+shader.fragmentShader;
  shader.fragmentShader=shader.fragmentShader.replace('#include <map_fragment>',`#include <map_fragment>
   vec2 sp=seaPosition;float t=seaTime;float shore=smoothstep(290.0,415.0,sp.x);
   float swell=sin(sp.y*0.21+t*0.9+sin(sp.x*0.05))*0.5+sin(sp.y*0.07-t*0.5+sp.x*0.03)*0.5;
   vec3 water=mix(vec3(0.015,0.09,0.17),vec3(0.03,0.26,0.36),smoothstep(0.0,0.6,shore));water=mix(water,vec3(0.12,0.55,0.55),smoothstep(0.6,1.0,shore))*(0.92+swell*0.08);
   float edge=smoothstep(392.0,405.0,sp.x)*(1.0-smoothstep(408.0,416.0,sp.x));float crest=smoothstep(0.55,0.95,sin(sp.y*0.45+t*1.6+sp.x*0.6)*0.5+0.5);float foam=clamp(edge*(0.45+crest*0.7),0.0,1.0);
   diffuseColor.rgb=mix(water,vec3(0.92,0.96,0.97),foam);
  `);
  shader.fragmentShader=shader.fragmentShader.replace('#include <roughnessmap_fragment>','#include <roughnessmap_fragment>\n roughnessFactor=mix(0.06,0.6,foam);');
 };
 material.customProgramCacheKey=()=> 'afterlight-sea-v1';
}
