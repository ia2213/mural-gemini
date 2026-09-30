import Foundation

// MARK: - Simplified FSRS (Free Spaced Repetition Scheduler)
//
// Based on Wang et al. (2024) "FSRS: Free Spaced Repetition Scheduler"
// with simplified formulas for mobile use:
//   R = exp(-Δt / S)   (exponential forgetting curve)
//   S(n+1) = S(n) * (R*d4 + (1-R)*d3) / (R*d4*f + (1-R)*d3)
//   f = 1 - 0.5*(1 - d1)
//   d1..d4 derived from difficulty D (1-10)
//
// Target retention is configurable via `desiredRetention` (default 90%).

public enum FSRS {
    /// Desired retention rate: review when probability of recall drops to this level.
    /// Lower values = longer intervals, higher values = shorter intervals.
    public static let desiredRetention: Double = 0.90

    // MARK: - Core Formulas

    /// Retrievability R = exp(-Δt / S): probability of successful recall after elapsedDays.
    public static func retrievability(stability: Double, elapsedDays: Double) -> Double {
        guard stability > 0 else { return 0 }
        return exp(-max(0, elapsedDays) / max(0.01, stability))
    }

    /// Next review interval in days to reach target retention.
    /// Δt = -S * ln(R_target), with a minimum of 1 day.
    public static func nextInterval(stability: Double, targetRetention: Double = desiredRetention) -> Double {
        guard stability > 0, targetRetention > 0 && targetRetention < 1 else { return 1.0 }
        let interval = -stability * log(targetRetention)
        return max(1.0, interval)
    }

    /// Update stability after a review outcome.
    /// On success: S grows based on retrievability at time of recall and difficulty factors.
    /// On failure: S is halved (catastrophic forgetting).
    public static func updateStability(stability: Double, difficulty: Double, retrievability: Double, wasSuccessful: Bool) -> Double {
        if !wasSuccessful {
            return max(0.5, stability * 0.5)
        }
        // Derived from difficulty D (1-10)
        let d1 = 0.6 + (10 - difficulty) / 10.0 * 0.4   // 0.6 (hard) → 1.0 (easy)
        let d3 = 1.5 + (10 - difficulty) / 10.0 * 0.5   // 1.5 → 2.0
        let d4 = 2.0 + difficulty / 10.0 * 0.5          // 2.0 → 2.5
        let f = 1.0 - 0.5 * (1.0 - d1)                   // forgetting index, 0.8 → 1.0

        let r = max(0.01, min(0.99, retrievability))
        let numerator = r * d4 + (1.0 - r) * d3
        let denominator = r * d4 * f + (1.0 - r) * d3

        return stability * numerator / denominator
    }

    /// Update difficulty after a review: easier after success, harder after failure.
    public static func updateDifficulty(difficulty: Double, wasSuccessful: Bool) -> Double {
        if wasSuccessful {
            return max(1.0, difficulty - 0.2)
        } else {
            return min(10.0, difficulty + 0.5)
        }
    }

    // MARK: - UI Compatibility

    /// Map stability to bars (0-3) for backward compatibility with UI.
    /// Stability thresholds roughly align with old SM-2 interval milestones.
    public static func barsFromStability(_ stability: Double) -> Int {
        if stability < 1.0 { return 0 }
        if stability < 4.0 { return 1 }
        if stability < 14.0 { return 2 }
        return 3
    }

    /// Human-readable label from bars.
    public static func labelFromBars(_ bars: Int) -> String {
        ["New", "Fragile", "Growing", "Steady"][min(3, max(0, bars))]
    }

    /// Explanation text from independent count and bars.
    public static func explanation(independentCount: Int, bars: Int) -> String {
        if independentCount == 0 {
            return "Heard or used with support. Try using it in your own words."
        }
        if bars == 1 {
            return "Used independently. We'll bring it back soon."
        }
        if bars == 2 {
            return "Recalled on different days. Still worth revisiting."
        }
        return "Recalled across days and contexts. Strength can fade with time."
    }
}
