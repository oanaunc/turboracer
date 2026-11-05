import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {content,modes,events,eventKey,freshSave,validateSave,buy,upgrade,record,starsIn,memoriesIn,unlockedRegion,dayStamp,dailyCircuit,sampleCircuit,center,point,heading,rivalCars,bodyFamily,RaceEngine,AirState,rampsFor,sweptContact,separation} from '../web/engine.js';
const routes=content.circuits.map(sampleCircuit),car=content.cars[0];
const run=(e,seconds,control=()=>{})=>{for(let i=0;i<seconds*60&&!e.result;i++){control(e,i/60);e.advance(1/60);}return e;};
test('catalogue contains the complete shipping content and stable save IDs',()=>{
 assert.equal(content.cars.length,12);assert.equal(routes.length,20);assert.equal(routes.reduce((n,c)=>n+events(c).length,0),80);
 assert.deepEqual(content.story.map(s=>s.length>80),[true,true,true,true]);assert.equal(content.notebook.length,4);
 const keys=routes.flatMap(c=>events(c).map(m=>eventKey(c,m)));assert.equal(new Set(keys).size,80);assert.equal(eventKey(routes[0],'circuit'),0);assert.equal(eventKey(routes[19],'duel'),1019);
 const swift=fs.readFileSync(new URL('../../Afterlight/Sources/World.swift',import.meta.url),'utf8');for(const c of content.cars)assert.ok(swift.includes(`name: "${c.name}"`));for(const c of routes)assert.ok(swift.includes(`Circuit(${c.id},"${c.name}"`));
});
test('twenty circuits close, maintain lane width, and match exported Apple samples',()=>{
 for(const c of routes){assert.ok(c.length>700);assert.deepEqual(center(c,0),center(c,1));for(let i=0;i<100;i++){const p=i/100,a=point(c,p,-9),b=point(c,p,9);assert.ok(Math.abs(Math.hypot(b[0]-a[0],b[1]-a[1])-18)<1e-8);assert.ok(Number.isFinite(heading(c,p)));}
 const source=new URL(`../../build/android-scenes/route-${c.id}.json`,import.meta.url);if(fs.existsSync(source)){const native=JSON.parse(fs.readFileSync(source));assert.ok(Math.abs(c.length-native.length)<.02);for(let i=0;i<1024;i+=13){assert.ok(Math.hypot(c.points[i][0]-native.points[i][0],c.points[i][1]-native.points[i][1])<.02);}}}
});
test('garage purchases, selection and four upgrade stages enforce credit rules',()=>{
 const s=freshSave();assert.equal(buy(s,content.cars[1]),false);s.credits=10000;assert.equal(buy(s,content.cars[1]),true);assert.equal(s.selectedCar,1);assert.equal(s.credits,8200);assert.equal(buy(s,content.cars[1]),false);for(let i=0;i<4;i++)assert.equal(upgrade(s),true);assert.equal(upgrade(s),false);assert.equal(s.credits,2200);assert.equal(s.upgrades[1],4);
});
test('campaign unlocks with five stars; daily rewards reset on UTC dates and pay once',()=>{
 const s=freshSave(),r={position:1,time:85,drift:900,credits:500,stars:3,collected:9,takedowns:2,stunts:6};assert.equal(unlockedRegion(s),0);record(s,r,routes[0],'circuit',false);record(s,{...r,stars:2},routes[4],'sprint',false);assert.equal(starsIn(s,0),5);assert.equal(unlockedRegion(s),1);assert.equal(memoriesIn(s,0),12);
 const day=new Date('2026-11-05T23:59:59Z'),before=s.credits;record(s,r,routes[2],'drift',true,day);assert.equal(s.credits,before+850);record(s,r,routes[2],'drift',true,day);assert.equal(s.credits,before+1350);record(s,r,routes[2],'drift',true,new Date('2026-11-06T00:00:01Z'));assert.equal(s.credits,before+2200);assert.equal(s.medals[eventKey(routes[2],'drift')],undefined);assert.equal(dayStamp(day),'2026-11-05');assert.equal(dailyCircuit(day).id,dailyCircuit(new Date('2026-11-05T00:00:01Z')).id);
});
test('save validation protects local progression from malformed and stale data',()=>{
 const s=validateSave({credits:-100,selectedCar:30,owned:[1,1,99,'3'],upgrades:{1:999},steeringSensitivity:100,medals:{0:9},bestTimes:{0:100},music:'false'});assert.equal(s.credits,0);assert.deepEqual(s.owned,[0,1]);assert.equal(s.selectedCar,0);assert.equal(s.upgrades[1],4);assert.equal(s.medals[0],3);assert.equal(s.steeringSensitivity,1.5);assert.equal(s.music,true);assert.deepEqual(validateSave(null),freshSave());assert.deepEqual(validateSave(JSON.parse(JSON.stringify(s))),s);
});
test('rivals exclude player body family and choose three distinct families',()=>{
 for(const player of content.cars)for(const c of routes){const grid=rivalCars(player,c.id,'circuit');assert.equal(grid.length,3);assert.equal(new Set([player,...grid].map(bodyFamily)).size,4);const champ=rivalCars(player,c.id,'duel');assert.equal(champ.length,1);assert.notEqual(bodyFamily(champ[0]),bodyFamily(player));assert.equal(rivalCars(player,c.id,'sprint').length,0);}
});
test('braking, pause, steering and nitro exhaustion match the Apple driving rules',()=>{
 const e=new RaceEngine(routes[0],'sprint',car);run(e,8);assert.ok(e.elapsed>4);assert.ok(e.speed>45);const p=e.progress,t=e.elapsed;e.setPaused(true);run(e,2);assert.equal(e.elapsed,t);assert.equal(e.progress,p);e.setPaused(false);e.braking=true;run(e,2);assert.ok(e.speed<22);e.braking=false;e.nitro=.1;e.nitroHeld=true;run(e,2);assert.equal(e.nitroExhausted,true);assert.equal(e.boosting,false);e.nitroHeld=false;run(e,.2);e.nitro=.7;e.nitroHeld=true;assert.equal(e.shockwaveArmed,true);e.setPaused(true);assert.equal(e.nitroHeld,false);assert.equal(e.steering,0);
});
test('drift scoring, collection, six completion rules and reward accounting',()=>{
 const e=new RaceEngine(routes[0],'drift',car);run(e,6);e.speed=54;e.steering=.6;e.drifting=true;e.lane=0;run(e,1);assert.ok(e.driftScore>0);
 for(const mode of Object.keys(modes)){const race=new RaceEngine(routes[0],mode,car);race.position=1;race.elapsed=14;race.driftScore=1700;race.collected=4;race.takedowns=3;race.stuntCredits=100;race.finish();assert.equal(race.result.stars,3);assert.equal(race.result.credits,150+540+212+140+100);const result=race.result;race.finish();assert.equal(race.result,result);}
 const clean=new RaceEngine(routes[0],'sprint',car);clean.countdown=0;clean.progress=1/13;clean.lane=-5;clean.speed=20;clean.advance(.001);assert.equal(clean.collected,1);clean.advance(.001);assert.equal(clean.collected,1);
});
test('ramps launch, complete a barrel roll and land; swept collisions wrap correctly',()=>{
 const c=routes[0],ramps=rampsFor(c),r=ramps[1],air=new AirState();air.update(.016,r.progress+8/c.length,r.lane,65,ramps,c.length);assert.ok(air.height>1);air.update(.016,r.progress+10/c.length,r.lane,65,ramps,c.length);assert.equal(air.airborne,true);assert.notEqual(air.rollRate,0);let landing;for(let i=0;i<180;i++){landing=air.update(1/60,.8,r.lane,65,ramps,c.length);if(landing)break;}assert.equal(landing.barrel,true);assert.equal(air.height,0);
 const body={halfWidth:1,halfLength:2};assert.equal(sweptContact(body,body,-8,8,1),true);assert.equal(sweptContact(body,body,-8,8,3),false);assert.ok(Math.abs(separation(.99,.01,100)+2)<1e-8);
});
test('all routes finish playable time attacks under deterministic control',()=>{
 for(const c of routes){const e=new RaceEngine(c,'sprint',car);run(e,120,e=>{e.steering=clampForTest(e.lane*.12,-1,1);});assert.ok(e.result,`${c.name} did not finish`);assert.ok(e.result.time>10);assert.equal(e.result.collected<=12,true);}
});
function clampForTest(n,a,b){return Math.max(a,Math.min(b,n));}
