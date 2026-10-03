import CoreMotion
import UIKit

/// Steer by turning the device like a wheel. Gravity along the device's
/// long axis maps to steering; the sign follows the landscape orientation.
@MainActor final class TiltSteering {
    private let motion = CMMotionManager()
    func start(_ steer: @escaping @MainActor (Double) -> Void) {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0/60
        motion.startDeviceMotionUpdates(to: .main) { data, _ in
            guard let gravity = data?.gravity else { return }
            let orientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.effectiveGeometry.interfaceOrientation ?? .landscapeRight
            MainActor.assumeIsolated { steer(TiltSteering.steering(gravityY: gravity.y, orientation: orientation)) }
        }
    }
    func stop() { motion.stopDeviceMotionUpdates() }
    nonisolated static func steering(gravityY: Double, orientation: UIInterfaceOrientation) -> Double {
        // In landscape-right the device's top points left, so turning the
        // screen clockwise (steering right) gives negative gravity along y.
        let raw = (orientation == .landscapeLeft ? gravityY : -gravityY)/0.32
        let deadZone = 0.06
        guard abs(raw) > deadZone else { return 0 }
        return max(-1, min(1, (abs(raw)-deadZone)/(1-deadZone)*(raw<0 ? -1 : 1)))
    }
}
