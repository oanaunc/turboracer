import XCTest
import SceneKit
@testable import Afterlight
final class ProgressTests: XCTestCase {
    @MainActor func testFleetModelsAndMaterialsAreBundled() {
        for car in Car.all {
            guard let node=SurfaceLibrary.grandTourer(car) else { XCTFail("Missing concept model: \(car.name)");continue }
            let bounds=node.boundingBox
            XCTAssertGreaterThan(bounds.max.z-bounds.min.z,3.8)
            XCTAssertLessThan(bounds.max.z-bounds.min.z,5.6)
            var vertexCount=0;var glassFound=false
            node.enumerateChildNodes { child,_ in
                vertexCount += child.geometry?.sources(for:.vertex).first?.vectorCount ?? 0
                for material in child.geometry?.materials ?? [] where material.name?.localizedCaseInsensitiveContains("glass") == true && material.name?.localizedCaseInsensitiveContains("red") != true {
                    glassFound=true
                    XCTAssertEqual(material.emission.contents as? UIColor,UIColor(red:0,green:0,blue:0,alpha:1),"Glazing must not glow")
                    XCTAssertEqual(material.lightingModel,.physicallyBased)
                }
            }
            XCTAssertGreaterThan(vertexCount,10000)
            XCTAssertTrue(glassFound)
        }
        for name in ["asphalt-art","asphalt-normal","rubber","rock","grass","sand"] { XCTAssertNotNil(SurfaceLibrary.image(name)) }
        XCTAssertNotNil(Bundle.main.url(forResource:"studio-light",withExtension:"hdr"))
    }

    @MainActor func testLocalProtectedArtDecodesWithoutSourceFiles() {
        for name in GeneratedArtKeys.keys.keys {
            XCTAssertNotNil(ArtVault.model(name))
            guard let model=GLBAsset.load(name) else {XCTFail("Cannot decode local licensed art: \(name)");continue}
            XCTAssertGreaterThan(model.boundingBox.max.y-model.boundingBox.min.y,0)
            if ["LuxurySedan","SportsCoupe","RivalPickup","ConceptGT"].contains(name) {
                var wheels=0
                model.enumerateChildNodes {node,_ in if node.name?.hasPrefix("Wheel") == true {wheels += 1}}
                XCTAssertEqual(wheels,4,"Licensed cars must keep four authored wheel pivots")
            }
        }
    }

    @MainActor func testVehicleCollidersFitEveryCarAndCatchSweptContact() {
        for car in Car.all {
            let model=RaceEngine.makeCar(car),body=VehicleCollider(node:model)
            XCTAssertNotNil(model.physicsBody?.physicsShape)
            XCTAssertEqual(model.physicsBody?.type,.kinematic)
            XCTAssertGreaterThan(body.halfWidth,0.8)
            XCTAssertGreaterThan(body.halfLength,1.9)
            XCTAssertTrue(body.overlaps(body,longitudinal:0,lateral:0))
            XCTAssertGreaterThan(body.projected(yaw:0.3).halfWidth,body.halfWidth,"Drift contact must include the swung-out body")
            XCTAssertFalse(body.overlaps(body,longitudinal:0,lateral:body.halfWidth*2+0.1))
            XCTAssertTrue(body.sweptContact(body,previous:-12,current:12,lateral:0),"Fast cars must not tunnel through a competitor")
            XCTAssertFalse(body.sweptContact(body,previous:-12,current:12,lateral:body.halfWidth*2+0.1))
        }
        XCTAssertEqual(VehicleCollider.trackSeparation(1.002,0.998,length:1000),4,accuracy:0.001,"Contact must wrap across the finish line")
    }

    @MainActor func testRivalGridHasBodyCollidersAndRespondsToContact() {
        let engine=RaceEngine(circuit:Circuit.all[0],mode:.circuit,car:Car.all[0],upgrade:0,sensitivity:1,haptics:false)
        let cars=engine.scene.rootNode.childNodes.filter {$0.physicsBody?.categoryBitMask == 1}
        XCTAssertEqual(cars.count,4)
        XCTAssertTrue(cars.allSatisfy {$0.physicsBody?.physicsShape != nil})
        for _ in 0..<420 {engine.advance(dt:1.0/60)}
        XCTAssertGreaterThan(engine.collisionCount,0,"The accelerating player must react when the rival grid catches its body")
        XCTAssertTrue(engine.speed.isFinite)
    }

    @MainActor func testSteeringMovesInTheRequestedCameraDirection() {
        for input in [-1.0, 1.0] {
            let circuit=Circuit.all[0]
            let engine=RaceEngine(circuit:circuit,mode:.sprint,car:Car.all[0],upgrade:0,sensitivity:1,haptics:false)
            engine.advance(dt:3.1)
            engine.steering=input
            for _ in 0..<45 {engine.advance(dt:1.0/60)}
            let center=engine.camera.convertPosition(vector(circuit.point(engine.routeProgress)),from:nil)
            let player=engine.camera.convertPosition(engine.player.position,from:nil)
            XCTAssertGreaterThan((player.x-center.x)*Float(input),2,"LEFT must move screen-left and RIGHT screen-right in the actual chase camera")
            let forward=engine.player.convertVector(SCNVector3(0,0,1),to:engine.camera)
            let trackForward=engine.camera.convertVector(SCNVector3(sin(circuit.heading(engine.routeProgress)),0,cos(circuit.heading(engine.routeProgress))),from:nil)
            XCTAssertGreaterThan((forward.x-trackForward.x)*Float(input),0,"The car must lean into the requested steering direction")
        }
    }

    @MainActor func testSafetyBarriersKeepTheCarBodyInsideEveryCircuit() {
        for circuit in Circuit.all {
            let engine=RaceEngine(circuit:circuit,mode:.sprint,car:Car.all[0],upgrade:0,sensitivity:1,haptics:false)
            let track=(0..<720).map {circuit.point(Double($0)/720)}
            let body=VehicleCollider(node:engine.player)
            engine.steering=1
            for frame in 0..<1000 {
                engine.advance(dt:1.0/60)
                if frame%60==0 {
                    let p=engine.player.position
                    let distance=track.map {hypot(Double($0.x-p.x),Double($0.z-p.z))}.min()!
                    XCTAssertLessThan(distance+body.halfWidth,10.9,"Holding steering must not push a car through the safety rail")
                }
            }
        }
    }

    @MainActor func testImportedCityAndLandscapingHaveUsableBounds() {
        for name in ["CityCorner","CityMidrise","CityLandmark","CoastalPalm","coastal_cliff_01","island_tree_01","pine_sapling_small"] {
            guard let node=SceneDressing.asset(name,height:12) else {XCTFail("Missing or empty environment: \(name)");continue}
            let bounds=node.boundingBox
            XCTAssertGreaterThan(bounds.max.y-bounds.min.y,0)
            XCTAssertTrue(node.scale.y.isFinite)
        }
        let tourer=SurfaceLibrary.grandTourer(Car.all[0])!.boundingBox
        let compact=SurfaceLibrary.grandTourer(Car.all[1])!.boundingBox
        let hyper=SurfaceLibrary.grandTourer(Car.all[2])!.boundingBox
        XCTAssertLessThan(compact.max.z-compact.min.z,tourer.max.z-tourer.min.z)
        XCTAssertLessThan(hyper.max.y-hyper.min.y,tourer.max.y-tourer.min.y)
    }

    @MainActor func testRoadsideModelsLeaveTheFullCircuitClear() {
        for circuit in Circuit.all {
            let engine=RaceEngine(circuit:circuit,mode:.sprint,car:Car.all[0],upgrade:0,sensitivity:1,haptics:false)
            var rockCount=0
            engine.scene.rootNode.enumerateChildNodes { rock,_ in
                guard ["roadside-rock","roadside-building","route-landmark"].contains(rock.name ?? "") else {return};rockCount += 1
                let b=rock.boundingBox, center=rock.convertPosition(SCNVector3Zero,to:nil)
                var radius:Float=0
                for x in [b.min.x,b.max.x] {for z in [b.min.z,b.max.z] {
                    let corner=rock.convertPosition(SCNVector3(x,0,z),to:nil)
                    radius=max(radius,hypot(corner.x-center.x,corner.z-center.z))
                }}
                for step in 0..<480 {
                    let road=circuit.point(Double(step)/480)
                    XCTAssertGreaterThan(hypot(road.x-center.x,road.z-center.z)-radius,11,"Imported scenery intersects the road corridor")
                }
            }
            if circuit.id != 0 || GeneratedArtKeys.keys["CityTerrace"] != nil {XCTAssertGreaterThan(rockCount,0)}
        }
    }

    @MainActor func testPurchaseCannotOverspendAndPersists() {
        let defaults = UserDefaults(suiteName:UUID().uuidString)!
        let garage=Garage(storage:defaults)
        garage.buy(Car.all[1]); XCTAssertEqual(garage.save.owned,[0])
        garage.save.credits=2000; garage.buy(Car.all[1]); garage.buy(Car.all[1])
        XCTAssertEqual(garage.save.credits,200); XCTAssertEqual(garage.save.owned,[0,1])
        XCTAssertEqual(Garage(storage:defaults).save.selectedCar,1)
    }
    @MainActor func testRewardsPreserveBestAndUnlockRegions() {
        let garage=Garage(storage:UserDefaults(suiteName:UUID().uuidString)!)
        let good=RaceResult(position:1,time:20,drift:1700,credits:700,stars:3)
        garage.record(good,circuit:Circuit.all[0],mode:.circuit,daily:false)
        XCTAssertEqual(garage.save.unlockedRegion,0)
        garage.record(good,circuit:Circuit.all[0],mode:.sprint,daily:false)
        XCTAssertEqual(garage.save.unlockedRegion,1)
        garage.record(RaceResult(position:4,time:45,drift:0,credits:150,stars:0),circuit:Circuit.all[0],mode:.circuit,daily:false)
        XCTAssertEqual(garage.save.medals[0],3); XCTAssertEqual(garage.save.bestTimes[0],20)
        XCTAssertEqual(garage.save.credits,1550); XCTAssertEqual(garage.save.races,3)
    }
    @MainActor func testUpgradeCapAndReset() {
        let garage=Garage(storage:UserDefaults(suiteName:UUID().uuidString)!)
        garage.save.credits=10000
        for _ in 0..<10 { garage.upgrade() }
        XCTAssertEqual(garage.save.upgrades[0],4); XCTAssertEqual(garage.save.credits,4000)
        garage.reset(); XCTAssertEqual(garage.save.credits,0); XCTAssertEqual(garage.save.owned,[0])
    }
    func testCircuitsAreClosedDistinctAndFinite() {
        for circuit in Circuit.all {
            XCTAssertGreaterThan(circuit.length,500); XCTAssertLessThan(circuit.length,1500)
            let a=circuit.point(0), b=circuit.point(1)
            XCTAssertEqual(a.x,b.x,accuracy:0.001); XCTAssertEqual(a.z,b.z,accuracy:0.001)
            for i in 0...100 { XCTAssertTrue(circuit.heading(Double(i)/100).isFinite) }
        }
    }
    func testWorldTourHasTwentySafeConstantWidthRoutes() {
        XCTAssertEqual(Circuit.all.count,20)
        XCTAssertEqual(Set(Circuit.all.map(\.id)).count,20)
        for environment in 0..<4 {XCTAssertEqual(Circuit.all.filter {$0.environment==environment}.count,5)}
        var signatures=Set<String>()
        for circuit in Circuit.all {
            let points=(0..<240).map {circuit.point(Double($0)/240)}
            signatures.insert(points.map {"\(Int($0.x)),\(Int($0.z))"}.joined(separator:";"))
            var steps:[Float]=[]
            for i in 0..<240 {
                let t=Double(i)/240,center=points[i],edge=circuit.point(t,lane:9)
                XCTAssertEqual(hypot(edge.x-center.x,edge.z-center.z),9,accuracy:0.002)
                let h=circuit.heading(t)
                XCTAssertGreaterThan((edge.x-center.x)*cos(h)-(edge.z-center.z)*sin(h),8.99,"Positive lane coordinates must keep the authored road normal")
                let next=points[(i+1)%240];steps.append(hypot(next.x-center.x,next.z-center.z))
                // Non-adjacent parts of a course need a full road-width gap.
                for j in (i+1)..<240 where min(j-i,240-(j-i))>12 {
                    XCTAssertGreaterThan(hypot(points[j].x-center.x,points[j].z-center.z),25,"Road overlap on \(circuit.name)")
                }
            }
            XCTAssertLessThan(steps.max()!/steps.min()!,1.08,"Arc-length sampling should keep speed consistent")
        }
        XCTAssertEqual(signatures.count,20)
    }
    @MainActor func testEveryRouteHasDistinctArtAndClearLandmarks() {
        XCTAssertEqual(RouteLook.all.count,Circuit.all.count)
        XCTAssertEqual(Set(Circuit.all.map { $0.look.setting }).count,20)
        XCTAssertEqual(Set(Circuit.all.map { $0.look.landmark }).count,20)
        for circuit in Circuit.all {
            let landmarks=RouteScenery.landmarks(circuit)
            XCTAssertEqual(landmarks.childNodes.count,3,"Every route needs its three authored landmark sites: \(circuit.name)")
            for node in landmarks.childNodes {
                XCTAssertGreaterThan(node.boundingBox.max.y-node.boundingBox.min.y,4)
                let center=node.position
                XCTAssertEqual(RouteScenery.terrainRelief(center.x,center.z,circuit:circuit),0,"Landmark terrain must be level")
            }
        }
    }

    func testExpandedCampaignPreservesSavesAndUnlocksDistrictRoutes() throws {
        var legacy=SaveData();legacy.medals=[0:3,1:3];legacy.owned=[0,1];legacy.selectedCar=1
        let restored=try JSONDecoder().decode(SaveData.self,from:JSONEncoder().encode(legacy))
        XCTAssertEqual(restored.unlockedRegion,1);XCTAssertTrue(restored.isUnlocked(Circuit.all[11]))
        XCTAssertFalse(restored.isUnlocked(Circuit.all[12]));XCTAssertEqual(restored.selectedCar,1)
        var newSave=SaveData();newSave.medals=[4*3:3,5*3:2]
        XCTAssertEqual(newSave.unlockedRegion,1,"New routes must contribute to district progression")
        newSave.memorySparks=[0:3,4:5,7:4,8:9]
        XCTAssertEqual(newSave.memories(in:0),12,"New routes must contribute to their district's notebook")
        XCTAssertEqual(newSave.memories(in:1),9)
    }
    @MainActor func testEveryUrbanBuildingHasSealedFoundation() {
        for environment in 0..<2 {
            let engine=RaceEngine(circuit:Circuit.all[environment],mode:.sprint,car:Car.all[0],upgrade:0,sensitivity:1,haptics:false)
            var buildings=0,foundations=0
            engine.scene.rootNode.enumerateChildNodes {node,_ in
                if node.name=="roadside-building" {buildings += 1}
                if node.name=="building-foundation" {
                    foundations += 1
                    let bounds=node.boundingBox
                    XCTAssertLessThan(node.convertPosition(bounds.min,to:nil).y,-0.04)
                    XCTAssertGreaterThan(node.convertPosition(bounds.max,to:nil).y,0.3)
                }
            }
            XCTAssertGreaterThan(buildings,0);XCTAssertEqual(foundations,buildings)
        }
    }
    @MainActor func testRaceFinishesOnceAndPauseFreezesSimulation() {
        let engine=RaceEngine(circuit:Circuit.all[0],mode:.sprint,car:Car.all[0],upgrade:0,sensitivity:1,haptics:false)
        engine.setPaused(true); engine.advance(dt:1); XCTAssertEqual(engine.elapsed,0)
        engine.setPaused(false)
        for _ in 0..<4000 { engine.advance(dt:1.0/60) }
        XCTAssertNotNil(engine.result); XCTAssertGreaterThan(engine.result?.credits ?? 0,0)
        let time=engine.elapsed; engine.advance(dt:1); XCTAssertEqual(engine.elapsed,time)
    }
    @MainActor func testNitroDriftAndOffRoadHaveRealEffects() {
        let engine=RaceEngine(circuit:Circuit.all[1],mode:.drift,car:Car.all[0],upgrade:0,sensitivity:1,haptics:false)
        for _ in 0..<360 { engine.advance(dt:1.0/60) }
        engine.nitroHeld=true
        for _ in 0..<60 { engine.advance(dt:1.0/60) }
        XCTAssertLessThan(engine.nitro,1)
        engine.steering = -1; engine.drifting=true
        for _ in 0..<15 { engine.advance(dt:1.0/60) }
        XCTAssertGreaterThan(engine.driftScore,0)
        for _ in 0..<300 { engine.advance(dt:1.0/60) }
        XCTAssertTrue(engine.offRoad); XCTAssertGreaterThanOrEqual(engine.nitro,0)
    }
    @MainActor func testDailyDoesNotBypassCampaignAndBonusIsOncePerDay() {
        let garage=Garage(storage:UserDefaults(suiteName:UUID().uuidString)!)
        let result=RaceResult(position:1,time:20,drift:1700,credits:700,stars:3,collected:4)
        garage.record(result,circuit:Circuit.all[3],mode:.drift,daily:true)
        XCTAssertEqual(garage.save.credits,1050); XCTAssertNil(garage.save.medals[11])
        garage.record(result,circuit:Circuit.all[3],mode:.drift,daily:true)
        XCTAssertEqual(garage.save.credits,1750); XCTAssertEqual(garage.save.memorySparks?[3],8)
    }

}
