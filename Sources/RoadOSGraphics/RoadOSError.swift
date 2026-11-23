import Foundation
import RoadOSBridge

/// Error raised by the RoadOS SDK. Codes mirror the C++ core's ErrorCode.
public struct RoadOSError: Error, Sendable, Hashable, LocalizedError, CustomStringConvertible {
    public enum Code: Int, Sendable {
        case invalidArgument = 1
        case parse = 2
        case io = 3
        case notFound = 4
        case unsupported = 5
        case render = 6
        case validation = 7
        case incompatible = 8
    }

    public let code: Code
    public let message: String

    public init(_ code: Code, _ message: String) {
        self.code = code
        self.message = message
    }

    public var errorDescription: String? { message }
    public var description: String { "RoadOSError.\(code): \(message)" }

    /// Converts an NSError from the Objective-C++ bridge.
    init(_ error: any Error) {
        let ns = error as NSError
        if ns.domain == ROSErrorDomain, let code = Code(rawValue: ns.code) {
            self.init(code, ns.localizedDescription)
        } else if let e = error as? RoadOSError {
            self = e
        } else {
            self.init(.render, ns.localizedDescription)
        }
    }
}

/// Runs a bridge call and maps any thrown NSError to RoadOSError.
@inline(__always)
func bridged<T>(_ body: () throws -> T) throws(RoadOSError) -> T {
    do {
        return try body()
    } catch {
        throw RoadOSError(error)
    }
}
