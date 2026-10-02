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
                for material in child.geometry?.materials ?? [] where material.name=="Glass" {
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
        XCTAssertGreaterThan(hyper.max.x-hyper.min.x,tourer.max.x-tourer.min.x)
    }

    @MainActor func testRoadsideRocksLeaveTheFullCircuitClear() {
        for circuit in Circuit.all.suffix(2) {
            let engine=RaceEngine(circuit:circuit,mode:.sprint,car:Car.all[0],upgrade:0,sensitivity:1,haptics:false)
            var rockCount=0
            engine.scene.rootNode.enumerateChildNodes { rock,_ in
                guard rock.name=="roadside-rock" else {return};rockCount += 1
                let b=rock.boundingBox, center=rock.convertPosition(SCNVector3Zero,to:nil)
                var radius:Float=0
                for x in [b.min.x,b.max.x] {for z in [b.min.z,b.max.z] {
                    let corner=rock.convertPosition(SCNVector3(x,0,z),to:nil)
                    radius=max(radius,hypot(corner.x-center.x,corner.z-center.z))
                }}
                for step in 0..<480 {
                    let road=circuit.point(Double(step)/480)
                    XCTAssertGreaterThan(hypot(road.x-center.x,road.z-center.z)-radius,11,"Imported rock intersects the road corridor")
                }
            }
            XCTAssertGreaterThan(rockCount,0)
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
