import Foundation

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
