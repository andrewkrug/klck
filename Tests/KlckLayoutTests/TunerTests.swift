import XCTest
@testable import Klck

/// Pitch-detection unit tests. Synthesizing PCM in-test means the regression
/// suite proves the detector returns the correct fundamental for known tones,
/// independent of any device microphone or audio session setup.
final class TunerTests: XCTestCase {

    /// Build a clean sine wave at `freq` Hz, `n` samples long, at the given
    /// `sampleRate`. The detector consumes `[Float]` so we return that.
    private func sine(_ freq: Double, n: Int, sampleRate: Double) -> [Float] {
        let omega = 2 * .pi * freq / sampleRate
        return (0..<n).map { i in Float(sin(omega * Double(i))) }
    }

    /// Sine plus its octave + fifth — a stand-in for a real instrument tone
    /// where the autocorrelation will see strong subharmonic-period peaks.
    /// The detector must still return the fundamental, not an octave down.
    private func complexTone(_ fundamental: Double, n: Int, sampleRate: Double) -> [Float] {
        let f1 = 2 * .pi * fundamental / sampleRate
        let f2 = 2 * .pi * (fundamental * 2) / sampleRate
        let f3 = 2 * .pi * (fundamental * 3) / sampleRate
        return (0..<n).map { i in
            let t = Double(i)
            return Float(sin(f1 * t) + 0.6 * sin(f2 * t) + 0.4 * sin(f3 * t)) / 2.0
        }
    }

    // Tolerance: a couple of Hz at A4 is well within the cents range the
    // tuner displays. Lower-frequency tests get a touch more headroom because
    // parabolic interpolation has more period-fraction to chew on.
    private func assertDetected(_ samples: [Float],
                                 sampleRate: Double,
                                 expected: Double,
                                 tolerance: Double = 2.0,
                                 file: StaticString = #file,
                                 line: UInt = #line) {
        guard let detected = Tuner.detectPitch(samples: samples, sampleRate: sampleRate) else {
            XCTFail("detectPitch returned nil for expected \(expected) Hz", file: file, line: line)
            return
        }
        XCTAssertEqual(detected, expected, accuracy: tolerance,
                       "Detected \(detected) Hz, expected \(expected) Hz",
                       file: file, line: line)
    }

    // MARK: Pure sines — baseline.

    func testDetectsA4() {
        assertDetected(sine(440, n: 4096, sampleRate: 48_000),
                       sampleRate: 48_000, expected: 440)
    }

    func testDetectsA3() {
        assertDetected(sine(220, n: 4096, sampleRate: 48_000),
                       sampleRate: 48_000, expected: 220)
    }

    func testDetectsA5() {
        assertDetected(sine(880, n: 4096, sampleRate: 48_000),
                       sampleRate: 48_000, expected: 880, tolerance: 4.0)
    }

    func testDetectsLowE() {
        // Guitar low E (82.41Hz) — close to the 50Hz floor, so wider tolerance.
        assertDetected(sine(82.41, n: 8192, sampleRate: 48_000),
                       sampleRate: 48_000, expected: 82.41, tolerance: 1.0)
    }

    // MARK: Complex tones — the octave-down regression case.

    /// The bug this guards against: when the autocorrelation function has
    /// peaks at every multiple of the fundamental, an algorithm that picks
    /// the *global* maximum can pick a later (lower-frequency) peak and
    /// report the pitch an octave down. The fix is to take the first
    /// significant local maximum.
    func testComplexA4ToneIsNotMisreadAsA3() {
        assertDetected(complexTone(440, n: 4096, sampleRate: 48_000),
                       sampleRate: 48_000, expected: 440, tolerance: 3.0)
    }

    func testComplexA3ToneIsNotMisreadAsA2() {
        assertDetected(complexTone(220, n: 4096, sampleRate: 48_000),
                       sampleRate: 48_000, expected: 220, tolerance: 2.0)
    }

    // MARK: Negative cases.

    func testReturnsNilForSilence() {
        let samples = [Float](repeating: 0, count: 4096)
        XCTAssertNil(Tuner.detectPitch(samples: samples, sampleRate: 48_000))
    }

    func testReturnsNilForTooFewSamples() {
        let samples = sine(440, n: 512, sampleRate: 48_000)
        XCTAssertNil(Tuner.detectPitch(samples: samples, sampleRate: 48_000))
    }
}
