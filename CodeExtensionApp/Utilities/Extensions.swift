import Foundation
import SwiftUI

// MARK: - Color Extensions

extension Color {
    static let claudeOrange = Color(red: 218/255, green: 119/255, blue: 86/255)
}

// MARK: - String Extensions

extension String {
    var isValidPath: Bool {
        FileManager.default.fileExists(atPath: self)
    }

    var expandingTilde: String {
        (self as NSString).expandingTildeInPath
    }
}

// MARK: - URL Extensions

extension URL {
    var isDirectory: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}

// MARK: - Date Extensions

extension Date {
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - View Extensions

extension View {
    func onFirstAppear(perform action: @escaping () -> Void) -> some View {
        modifier(FirstAppearModifier(action: action))
    }
}

struct FirstAppearModifier: ViewModifier {
    let action: () -> Void
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content.onAppear {
            if !hasAppeared {
                hasAppeared = true
                action()
            }
        }
    }
}

// MARK: - Array Extensions

extension Array where Element == String {
    func sortedCaseInsensitive() -> [String] {
        sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
