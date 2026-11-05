import content from './content.js';
export {content};
export const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
export const wrap=n=>n-Math.floor(n);
export const regions=['01 / THE COAST','02 / THE CITY','03 / THE BADLANDS','04 / THE SUMMIT'];
export const colors=['#ffaa79','#59e8d4','#ffd76e','#bba8ff'];
export const modes={circuit:{name:'Circuit',detail:'2 laps • 3 rivals',laps:2,rivals:true},sprint:{name:'Time attack',detail:'1 lap • chase the clock',laps:1},drift:{name:'Drift run',detail:'1 lap • build your drift score',laps:1},elimination:{name:'Elimination',detail:'last place is out every 20 seconds',laps:3,rivals:true},knockdown:{name:'Knockdown',detail:'take down 3 rivals in 2 laps',laps:2,rivals:true},duel:{name:'Duel',detail:'2 laps • beat the district champion',laps:2,rivals:true}};
export const special=c=>['elimination','knockdown','duel'][c.id%3];
export const events=c=>['circuit','sprint','drift',special(c)];
export const eventKey=(c,m)=>['circuit','sprint','drift'].includes(m)?c.id*3+['circuit','sprint','drift'].indexOf(m):1000+c.id;
export const dayStamp=(date=new Date())=>date.toISOString().slice(0,10);
export const dailyCircuit=(date=new Date())=>content.circuits[Math.floor(date.getTime()/86400000)%20];
export const freshSave=()=>({credits:0,selectedCar:0,owned:[0],upgrades:{},medals:{},bestTimes:{},bestDrifts:{},races:0,wins:0,distance:0,sounds:true,tiltSteering:false,xp:0,music:true,haptics:true,steeringSensitivity:1,dailyStamp:'',dailyBest:0,memorySparks:{},dailyRewardStamp:''});
export function validateSave(raw){
 const s=freshSave();if(!raw || typeof raw!=='object')return s;
 for(const k of ['credits','races','wins','xp','dailyBest'])if(Number.isSafeInteger(raw[k])&&raw[k]>=0)s[k]=raw[k];
 if(Number.isFinite(raw.distance)&&raw.distance>=0)s.distance=raw.distance;
 if(Array.isArray(raw.owned))s.owned=[...new Set([0,...raw.owned.filter(i=>Number.isInteger(i)&&i>=0&&i<12)])];
 if(s.owned.includes(raw.selectedCar))s.selectedCar=raw.selectedCar;
 for(const k of ['sounds','tiltSteering','music','haptics'])if(typeof raw[k]==='boolean')s[k]=raw[k];
 if(Number.isFinite(raw.steeringSensitivity))s.steeringSensitivity=clamp(raw.steeringSensitivity,.65,1.5);
 for(const [k,limit,maxKey] of [['upgrades',4,11],['medals',3,1019],['memorySparks',12,19],['bestTimes',86400,1019],['bestDrifts',1e9,1019]]){
  if(raw[k]&&typeof raw[k]==='object')for(const [id,v] of Object.entries(raw[k]))if(/^\d+$/.test(id)&&+id<=maxKey&&Number.isFinite(v)&&v>=0)s[k][id]=Math.min(limit,k==='bestTimes'?v:Math.floor(v));
 }
 for(const k of ['dailyStamp','dailyRewardStamp'])if(typeof raw[k]==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(raw[k]))s[k]=raw[k];
 return s;
}
export const starsIn=(s,r)=>content.circuits.filter(c=>c.environment===r).reduce((n,c)=>n+events(c).reduce((a,m)=>a+(s.medals[eventKey(c,m)]||0),0),0);
export const memoriesIn=(s,r)=>Math.min(12,content.circuits.filter(c=>c.environment===r).reduce((n,c)=>n+(s.memorySparks[c.id]||0),0));
export const unlockedRegion=s=>Math.min(3,[0,1,2,3].find(r=>starsIn(s,r)<5)??3);
export const experience=r=>120+r.stars*90+r.stunts*12+r.takedowns*40+r.collected*8;
export function buy(s,c){if(s.owned.includes(c.id)||s.credits<c.price)return false;s.credits-=c.price;s.owned.push(c.id);s.selectedCar=c.id;return true;}
export function upgrade(s){const level=s.upgrades[s.selectedCar]||0,cost=(level+1)*600;if(level>=4||s.credits<cost)return false;s.credits-=cost;s.upgrades[s.selectedCar]=level+1;return true;}
export function record(s,r,c,m,daily,date=new Date()){
 const key=eventKey(c,m);s.xp+=experience(r);s.credits+=r.credits;s.races++;s.wins+=r.position===1?1:0;s.distance+=c.length*modes[m].laps/1000;
 if(!daily)s.medals[key]=Math.max(s.medals[key]||0,r.stars);
 s.memorySparks[c.id]=Math.min(12,(s.memorySparks[c.id]||0)+r.collected);
 s.bestTimes[key]=Math.min(s.bestTimes[key]??Infinity,r.time);s.bestDrifts[key]=Math.max(s.bestDrifts[key]||0,r.drift);
 if(daily){const day=dayStamp(date);if(s.dailyRewardStamp!==day&&r.stars>0){s.credits+=350;s.dailyRewardStamp=day;}if(s.dailyStamp!==day)s.dailyBest=0;s.dailyStamp=day;s.dailyBest=Math.max(s.dailyBest,r.drift);}
}
export function sampleCircuit(c){
 // Same closed Catmull–Rom curve and 1024-segment arc-length resampling as Swift.
 const n=c.coordinates.length,res=1024,raw=t=>{const u=t*n,i=Math.floor(u)%n,f=u-Math.floor(u);return [0,1].map(k=>{const a=c.coordinates[(i+n-1)%n][k],b=c.coordinates[i][k],cc=c.coordinates[(i+1)%n][k],d=c.coordinates[(i+2)%n][k];return (2*b+(cc-a)*f+(2*a-5*b+4*cc-d)*f*f+(-a+3*b-3*cc+d)*f*f*f)*.5;});};
 const source=Array.from({length:res+1},(_,i)=>raw(i/res)),dist=[0];for(let i=1;i<=res;i++)dist.push(dist[i-1]+Math.hypot(source[i][0]-source[i-1][0],source[i][1]-source[i-1][1]));
 const length=dist[res];let j=1;const points=Array.from({length:res},(_,i)=>{let target=length*i/res;while(j<res&&dist[j]<target)j++;const f=(target-dist[j-1])/Math.max(.0001,dist[j]-dist[j-1]);return [0,1].map(k=>source[j-1][k]+(source[j][k]-source[j-1][k])*f);});
 return {...c,length,points};
}
export function center(c,p){const u=wrap(p)*c.points.length,i=Math.floor(u),f=u-i;return [0,1].map(k=>c.points[i][k]+(c.points[(i+1)%c.points.length][k]-c.points[i][k])*f);}
export function heading(c,p){const a=center(c,p-.0005),b=center(c,p+.0005);return Math.atan2(b[0]-a[0],b[1]-a[1]);}
export function point(c,p,lane=0){const a=center(c,p),h=heading(c,p);return [a[0]+Math.cos(h)*lane,a[1]-Math.sin(h)*lane];}
export const bodyFamily=c=>['Roadster','Hyper'].includes(c.design)?'ConceptPlatform':c.design;
export function rivalCars(player,route,mode){if(!modes[mode].rivals)return [];const pool=content.cars.filter(c=>bodyFamily(c)!==bodyFamily(player));if(mode==='duel')return [[...pool.filter(c=>c.speed>=player.speed)].sort((a,b)=>Math.abs(a.speed-player.speed-4)-Math.abs(b.speed-player.speed-4))[0]||pool[route%3]];const used=new Set([bodyFamily(player)]),grid=[];for(let i=0;i<12;i++){const c=content.cars[(route+i)%12];if(!used.has(bodyFamily(c))){used.add(bodyFamily(c));grid.push(c);}if(grid.length===3)break;}return grid;}
export const rampsFor=c=>{const side=c.id%2===0?1:-1;return [{progress:.27,lane:side*3,barrel:false,width:3.2,height:1.25},{progress:.655,lane:-side*3.4,barrel:true,width:2.4,height:1.5}];};
export class AirState{
 constructor(){this.height=0;this.velocity=0;this.airborne=false;this.airTime=0;this.roll=0;this.rollRate=0;this.ramp=null;}
 update(dt,progress,lane,speed,ramps,length){
  if(this.airborne){this.velocity-=24*dt;this.height+=this.velocity*dt;this.airTime+=dt;this.roll+=this.rollRate*dt;if(this.height<=0){const result={time:this.airTime,barrel:this.rollRate!==0};Object.assign(this,new AirState());return result;}return null;}
  for(let i=0;i<ramps.length;i++){const r=ramps[i],d=(wrap(progress)-r.progress)*length;if(d>=0&&d<=9&&Math.abs(lane-r.lane)<r.width){this.height=r.height*d/9*(1+(r.barrel?Math.max(0,(lane-r.lane)*(r.lane>0?-1:1)/r.width)*.35:0));this.ramp=i;return null;}}
  if(this.ramp!==null){const r=ramps[this.ramp],d=(wrap(progress)-r.progress)*length;this.airborne=true;this.airTime=0;if(d>9&&d<15){this.velocity=clamp(speed*.17,5.5,10.5);if(r.barrel){const flight=(this.velocity+Math.sqrt(this.velocity**2+48*this.height))/24;this.rollRate=(r.lane>0?1:-1)*2*Math.PI/Math.max(.55,flight);}}else this.velocity=0;this.ramp=null;}else this.height=0;
  return null;
 }
}
export const separation=(a,b,length)=>{let d=(a-b)%1;if(d>.5)d--;if(d<-.5)d++;return d*length;};
export const projected=(body,yaw)=>({halfWidth:body.halfWidth*Math.abs(Math.cos(yaw))+body.halfLength*Math.abs(Math.sin(yaw)),halfLength:body.halfLength*Math.abs(Math.cos(yaw))+body.halfWidth*Math.abs(Math.sin(yaw))});
export const sweptContact=(a,b,previous,current,lateral)=>Math.abs(lateral)<a.halfWidth+b.halfWidth&&Math.min(previous,current)<a.halfLength+b.halfLength&&Math.max(previous,current)>-a.halfLength-b.halfLength;
const gearTop=[0,15,26,37,49,62,80];
export class RaceEngine{
 constructor(c,mode,car,upgrade=0,sensitivity=1){
  Object.assign(this,{c,mode,car,upgrade,sensitivity,speed:0,lap:1,position:4,elapsed:0,driftScore:0,nitro:1,countdown:3,paused:false,result:null,collected:0,sparkMessage:'',offRoad:false,boosting:false,combo:1,gear:1,rpm:900,stunt:'',takedowns:0,shockwave:false,stuntCount:0,stuntTimer:0,stuntCredits:0,steering:0,braking:false,drifting:false,progress:0,lane:0,lateral:0,countdownTime:0,driftFraction:0,driftChain:0,collisionCooldown:0,barrierCooldown:0,messageTimer:0,eliminationClock:20,eliminated:0,playerOut:false,lastPosition:4,announcedFinalLap:false,lastNitroRelease:-10,shockwaveArmed:false,nitroExhausted:false,_nitroHeld:false,collisionCount:0});
  this.air=new AirState();this.ramps=rampsFor(c);this.rivalCars=rivalCars(car,c.id,mode);this.rivals=this.rivalCars.map((car,i)=>({car,progress:[-.008,-.016,-.024][i],lane:[-4,0,4][i],target:[-4,0,4][i],wreck:0,out:false,nearMissReady:true,air:new AirState(),body:{halfWidth:1.05,halfLength:2.4}}));this.collectedChips=new Set();this.body={halfWidth:1.05,halfLength:2.4};this.signals=[];
 }
 set nitroHeld(value){if(value===this._nitroHeld)return;this._nitroHeld=value;if(value)this.shockwaveArmed=this.elapsed-this.lastNitroRelease<.35&&this.nitro>=.5;else {this.lastNitroRelease=this.elapsed;this.shockwaveArmed=false;}}
 get nitroHeld(){return this._nitroHeld;}
 resetControls(){this.steering=0;this.braking=false;this.drifting=false;this.nitroHeld=false;}
 setPaused(value){this.paused=value;this.resetControls();}
 signal(sound){this.signals.push(sound);}
 call(text){this.stunt=text;this.stuntTimer=1.4;this.stuntCount++;}
 advance(dt){
  dt=clamp(dt,0,.1);if(this.paused||this.result)return;
  if(this.countdown>0){this.countdownTime+=dt;const next=Math.max(0,3-Math.floor(this.countdownTime));if(next!==this.countdown)this.signal('haptic');this.countdown=next;return;}
  this.elapsed+=dt;this.messageTimer=Math.max(0,this.messageTimer-dt);if(!this.messageTimer)this.sparkMessage='';this.collisionCooldown=Math.max(0,this.collisionCooldown-dt);this.barrierCooldown=Math.max(0,this.barrierCooldown-dt);
  const maxSpeed=this.car.speed+this.upgrade*3;
  if(!this.nitroHeld)this.nitroExhausted=false;if(this.nitroHeld&&this.nitro<=.015)this.nitroExhausted=true;
  const wasBoosting=this.boosting;this.boosting=this.nitroHeld&&!this.nitroExhausted&&!this.braking&&!this.offRoad;if(this.boosting&&!wasBoosting)this.signal('nitro');this.shockwave=this.boosting&&this.shockwaveArmed;
  this.stuntTimer=Math.max(0,this.stuntTimer-dt);if(!this.stuntTimer)this.stunt='';
  this.nitro=clamp(this.nitro+dt*(this.boosting?(this.shockwave?-.42:-.27):this.drifting?.1:.035),0,1);
  const desired=this.braking?maxSpeed*.3:this.offRoad&&!this.air.airborne?maxSpeed*.52:maxSpeed*(this.shockwave?1.6:this.boosting?1.38:1);
  this.speed+=(desired-this.speed)*Math.min(1,dt*(this.braking?3:.65));
  if(this.speed>gearTop[this.gear]*.97&&this.gear<6)this.gear++;else if(this.gear>1&&this.speed<gearTop[this.gear-1]*.7)this.gear--;
  const bottom=this.gear>1?gearTop[this.gear-1]*.62:0;this.rpm=950+clamp((this.speed-bottom)/(gearTop[this.gear]-bottom),0,1.05)*6400;
  this.lateral+=(-this.steering*this.sensitivity*this.car.handling*(this.drifting?10:7)-this.lateral)*Math.min(1,dt*5);
  const angleDiff=(a,b)=>Math.atan2(Math.sin(a-b),Math.cos(a-b));
  const bend=angleDiff(heading(this.c,this.progress+.002),heading(this.c,this.progress)),outward=-clamp(bend*65,-2,2)*(this.speed/maxSpeed)**2;
  this.lane=clamp(this.lane+(this.lateral+outward)*dt,-12,12);this.offRoad=Math.abs(this.lane)>8.1&&!this.air.airborne;
  const curve=Math.abs(angleDiff(heading(this.c,this.progress+.001),heading(this.c,this.progress)));
  if(this.drifting&&this.speed>23&&Math.abs(this.steering)>.18&&!this.offRoad){this.driftChain+=dt;this.combo=Math.min(5,1+Math.floor(this.driftChain/2));this.driftFraction+=dt*(24+curve*1000)*this.combo;this.driftScore=Math.floor(this.driftFraction);}else {this.driftChain=0;this.combo=1;}
  const previousProgress=this.progress;this.progress+=this.speed*dt/this.c.length;this.lap=Math.min(modes[this.mode].laps,Math.floor(this.progress)+1);
  for(let i=0;i<this.rivals.length;i++){
   const r=this.rivals[i];if(r.out)continue;const gap=separation(r.progress,this.progress,this.c.length),band=gap< -60?1.06:gap>80?.96:1;
   let speed=maxSpeed*((this.mode==='duel'?.955:.88+i*.023)+.025*Math.sin(this.elapsed*.6+i))*band;
   if(r.wreck>0){r.wreck=Math.max(0,r.wreck-dt);speed*=r.wreck>0?.25:.6;}
   const previousRival=r.progress;r.progress+=speed*dt/this.c.length;
   if(Math.floor(this.elapsed*10)%(30+i*7)===0)r.target=clamp(4.5*Math.sin(this.elapsed*.37+i*2.1),-6,6);
   r.lane+=clamp(r.target-r.lane,-2.2*dt,2.2*dt);r.air.update(dt,r.progress,r.lane,speed,this.ramps,this.c.length);
   const d=separation(this.progress,r.progress,this.c.length),previous=d-((this.progress-r.progress)-(previousProgress-previousRival))*this.c.length,body=projected(this.body,this.lateral*.022*(this.drifting?2:1));
   if(r.wreck===0&&Math.abs(this.air.height-r.air.height)<1.2&&sweptContact(body,r.body,previous,d,this.lane-r.lane)){
    if(this.elapsed>3&&this.speed>25&&previous<.5&&(this.boosting||this.speed>speed*1.12)){r.wreck=2.6;this.takedowns++;this.nitro=Math.min(1,this.nitro+.3);this.stuntCredits+=60;this.call('TAKEDOWN!');this.signal('takedown');this.speed*=.95;}
    else {const side=this.lane>=r.lane?1:-1;this.lane=clamp(r.lane+side*(body.halfWidth+r.body.halfWidth+.12),-12,12);this.lateral=side*Math.max(1,Math.abs(this.lateral)*.4);if(!this.collisionCooldown){this.collisionCount++;this.speed=Math.min(this.speed*.76,speed*.92);this.collisionCooldown=.5;this.signal('impact');}}
    r.nearMissReady=false;
   }else if(previous<0&&d>=0&&r.wreck===0){if(r.nearMissReady&&Math.abs(this.lane-r.lane)<body.halfWidth+r.body.halfWidth+1.3){this.nitro=Math.min(1,this.nitro+.08);this.stuntCredits+=15;this.call('NEAR MISS');this.signal('whoosh');}r.nearMissReady=true;}else if(Math.abs(d)>20)r.nearMissReady=true;
  }
  const landing=this.air.update(dt,this.progress,this.lane,this.speed,this.ramps,this.c.length);
  if(landing){if(landing.barrel){this.nitro=Math.min(1,this.nitro+.3);this.stuntCredits+=80;this.call('BARREL ROLL');}else if(landing.time>.45){this.nitro=Math.min(1,this.nitro+.2);this.stuntCredits+=40;this.call(landing.time>.9?'BIG AIR':'JUMP');}this.signal('land');}
  const width=projected(this.body,this.lateral*.022*(this.drifting?2:1)).halfWidth,limit=Math.max(6,10.8-width-.35);
  if(Math.abs(this.lane)>limit){this.lane=this.lane<0?-limit:limit;this.lateral=0;if(!this.barrierCooldown){this.speed=Math.max(Math.min(this.speed,maxSpeed*.45),this.speed*.85);this.barrierCooldown=.4;this.signal('impact');}}
  this.position=1+this.rivals.filter(r=>!r.out&&r.progress>this.progress).length;
  if(this.mode==='elimination'){this.eliminationClock-=dt;if(this.eliminationClock<=0){this.eliminationClock=20;const alive=this.rivals.filter(r=>!r.out),last=[...alive].sort((a,b)=>a.progress-b.progress)[0];if(last&&last.progress<this.progress){last.out=true;this.eliminated++;this.call(last.car.name+' ELIMINATED');if(alive.length===1){this.position=1;this.finish();return;}}else {this.playerOut=true;this.call('ELIMINATED');this.finish();return;}}}
  if(this.mode==='knockdown'&&this.takedowns>=3){this.finish();return;}
  if(modes[this.mode].rivals&&this.position<this.lastPosition&&this.elapsed>2)this.call(this.position===1?'TAKING THE LEAD':'OVERTAKE · P'+this.position);this.lastPosition=this.position;
  if(modes[this.mode].laps>1&&this.lap===modes[this.mode].laps&&!this.announcedFinalLap){this.announcedFinalLap=true;this.call('FINAL LAP');}
  for(let i=0;i<12;i++)if(!this.collectedChips.has(i)&&Math.abs(wrap(this.progress)-(i+1)/13)*this.c.length<4.5&&Math.abs(this.lane-(i%3-1)*5)<2.3){this.collectedChips.add(i);this.collected++;this.nitro=Math.min(1,this.nitro+.12);this.sparkMessage='MEMORY CHIP +35 • NITRO RESTORED';this.messageTimer=2;this.signal('spark');}
  if(this.progress>=modes[this.mode].laps)this.finish();
 }
 finish(){
  if(this.result)return;let stars;
  switch(this.mode){case 'circuit':case 'elimination':stars=this.playerOut?0:Math.max(0,4-this.position);break;case 'duel':stars=this.position===1?3:0;break;case 'knockdown':stars=Math.min(3,this.takedowns);break;case 'sprint':{const target=this.c.length/(this.car.speed*.83);stars=this.elapsed<target?3:this.elapsed<target*1.16?2:this.elapsed<target*1.4?1:0;break;}default:stars=this.driftScore>=1600?3:this.driftScore>=850?2:this.driftScore>=300?1:0;}
  this.result={position:['circuit','elimination','duel'].includes(this.mode)?this.position:stars===3?1:2,time:this.elapsed,drift:this.driftScore,credits:150+stars*180+Math.min(400,Math.floor(this.driftScore/8))+this.collected*35+this.stuntCredits,stars,collected:this.collected,takedowns:this.takedowns,stunts:this.stuntCount};this.signal('haptic');this.resetControls();
 }
}
