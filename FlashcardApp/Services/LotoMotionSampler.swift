//
//  LotoMotionSampler.swift
//
//  Reads the accelerometer while the drum spins: how the learner's hand shakes the phone is one factor of the chaos system.
//  Raw acceleration needs no permission and is never stored or sent; only a summary and a digest of the samples leave this file.
//

import CoreMotion
import CryptoKit
import Foundation

final class LotoMotionSampler {
    private let manager: CMMotionManager
    private var samples: [(x: Double, y: Double, z: Double)] = []

    init(manager: CMMotionManager = CMMotionManager()) { self.manager = manager }

    var isAvailable: Bool { manager.isAccelerometerAvailable }

    func start() {
        samples.removeAll()
        guard manager.isAccelerometerAvailable else { return }
        manager.accelerometerUpdateInterval = 1.0 / 60
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let a = data?.acceleration else { return }
            self?.samples.append((a.x, a.y, a.z))
        }
    }

    /// nil when the device has no accelerometer or nothing was read, so a missing sensor is never presented as a factor.
    func stop() -> LotoChaosFactor? {
        manager.stopAccelerometerUpdates()
        defer { samples.removeAll() }
        guard !samples.isEmpty else { return nil }
        var hasher = SHA256()
        var peak = 0.0
        for sample in samples {
            for value in [sample.x, sample.y, sample.z] { withUnsafeBytes(of: value.bitPattern.bigEndian) { hasher.update(bufferPointer: $0) } }
            peak = max(peak, (sample.x * sample.x + sample.y * sample.y + sample.z * sample.z).squareRoot())
        }
        let digest = hasher.finalize().prefix(8).map { String(format: "%02x", $0) }.joined()
        return LotoChaosFactor(kind: .motion, key: "motion", value: "samples=\(samples.count);digest=\(digest)",
                               display: String(format: NSLocalizedString("%d readings, peak %.2f g", comment: "Loto chaos: accelerometer summary"), samples.count, peak))
    }
}
