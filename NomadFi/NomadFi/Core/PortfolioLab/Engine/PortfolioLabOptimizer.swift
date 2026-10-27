import Foundation

public struct PortfolioLabOptimization: Equatable, Sendable {
    public var weights: [Double]
    public var objective: Double
    public var iterations: Int
    public var converged: Bool
}

/// Long-only, fully invested mean-variance with trading costs:
///
///     maximize  μ·w − λ·wᵀΣw − Σ cᵢ·|wᵢ − w0ᵢ|   subject to  Σw = 1,  0 ≤ wᵢ ≤ cap
///
/// Solved exactly by accelerated proximal gradient (FISTA). The smooth part
/// takes a gradient step; the cost and constraints are handled together by a
/// proximal step that is separable once the budget multiplier is known, and
/// that multiplier is found by bisection. The problem is convex, so the
/// answer is the global optimum.
public enum PortfolioLabOptimizer {
    public static func optimize(expectedReturns mu: [Double], covariance sigma: [[Double]],
                                previous: [Double]? = nil, costs: [Double]? = nil, riskAversion lambda: Double,
                                maxWeight cap: Double, tolerance: Double = 1e-13,
                                maxIterations: Int = 50_000) throws -> PortfolioLabOptimization {
        let n = mu.count
        guard n > 0 else { throw PortfolioLabError.noAssets }
        guard Double(n) * cap >= 1 - 1e-12 else { throw PortfolioLabError.infeasibleCap(maxWeight: cap, assets: n) }
        let w0 = previous ?? Array(repeating: 0, count: n)
        let c = costs ?? Array(repeating: 0, count: n)

        // Gershgorin bound on the largest eigenvalue of 2λΣ gives a safe step.
        let lipschitz = 2 * lambda * (sigma.map { $0.reduce(0) { $0 + abs($1) } }.max() ?? 0)
        let step = 1 / max(lipschitz, 1e-9)

        func gradient(_ w: [Double]) -> [Double] {
            (0..<n).map { i in -mu[i] + 2 * lambda * (0..<n).reduce(0) { $0 + sigma[i][$1] * w[$1] } }
        }

        var w = project(Array(repeating: 1 / Double(n), count: n), anchor: w0, thresholds: Array(repeating: 0, count: n), cap: cap)
        var y = w, momentum = 1.0
        var iterations = 0, converged = false
        while iterations < maxIterations {
            iterations += 1
            let g = gradient(y)
            let next = project((0..<n).map { y[$0] - step * g[$0] }, anchor: w0, thresholds: c.map { step * $0 }, cap: cap)
            let change = zip(next, w).map { abs($0 - $1) }.max() ?? 0
            let nextMomentum = (1 + (1 + 4 * momentum * momentum).squareRoot()) / 2
            // Restart the momentum whenever it points uphill, which keeps FISTA monotone in practice.
            let uphill = zip(zip(y, next), w).reduce(0) { $0 + ($1.0.0 - $1.0.1) * ($1.0.1 - $1.1) } > 0
            y = uphill ? next : (0..<n).map { next[$0] + (momentum - 1) / nextMomentum * (next[$0] - w[$0]) }
            momentum = uphill ? 1 : nextMomentum
            w = next
            if change < tolerance { converged = true; break }
        }
        let cleaned = w.map { $0 < 1e-12 ? 0 : $0 }
        return .init(weights: cleaned, objective: objective(cleaned, mu: mu, sigma: sigma, previous: w0, costs: c, lambda: lambda),
                     iterations: iterations, converged: converged)
    }

    /// The quantity being maximized, so any candidate can be scored the same way.
    public static func objective(_ w: [Double], mu: [Double], sigma: [[Double]], previous: [Double],
                                 costs: [Double], lambda: Double) -> Double {
        var variance = 0.0
        for i in w.indices { for j in w.indices { variance += w[i] * sigma[i][j] * w[j] } }
        let alpha = zip(w, mu).reduce(0) { $0 + $1.0 * $1.1 }
        let trading = w.indices.reduce(0) { $0 + costs[$1] * abs(w[$1] - previous[$1]) }
        return alpha - lambda * variance - trading
    }

    /// argmin ½‖w − v‖² + Σ tᵢ|wᵢ − aᵢ|  subject to  Σw = 1, 0 ≤ w ≤ cap.
    static func project(_ v: [Double], anchor a: [Double], thresholds t: [Double], cap: Double) -> [Double] {
        func weights(_ nu: Double) -> [Double] {
            v.indices.map { i in
                let u = v[i] - nu
                let shrunk = u > a[i] + t[i] ? u - t[i] : (u < a[i] - t[i] ? u + t[i] : a[i])
                return min(max(shrunk, 0), cap)
            }
        }
        let spread = (t.max() ?? 0) + cap + 1
        var low = (v.min() ?? 0) - spread, high = (v.max() ?? 0) + spread
        for _ in 0..<200 {
            let mid = (low + high) / 2
            if weights(mid).reduce(0, +) > 1 { low = mid } else { high = mid }
            if high - low < 1e-15 { break }
        }
        return weights((low + high) / 2)
    }
}
