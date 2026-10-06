import FiBotEngine
import Foundation

struct Request: Decodable {
    let context: FiBotFinancialContext
    let purchase: FiBotPurchase
    let policy: FiBotPolicy?
}
do {
    var data = Data()
    while let chunk = try FileHandle.standardInput.read(upToCount: 65536), !chunk.isEmpty {
        guard data.count + chunk.count <= 4 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        data.append(chunk)
    }
    let request = try JSONDecoder().decode(Request.self, from: data)
    let decision = FiBotAffordabilityEngine.evaluate(context: request.context, purchase: request.purchase, policy: request.policy ?? .init())
    FileHandle.standardOutput.write(try JSONEncoder().encode(decision))
} catch {
    FileHandle.standardError.write(Data("Invalid FiBot evaluation request.\n".utf8))
    exit(1)
}
