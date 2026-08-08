import AppKit
import SwiftUI

enum MotionIntensity: String, CaseIterable, Identifiable {
    case enhanced
    case reduced
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .enhanced: "Enhanced"
        case .reduced: "Reduced"
        case .none: "Off"
        }
    }
}

struct AccentColorOption: Identifiable, Hashable {
    let id: String
    let name: String
    let color: Color

    static let all: [AccentColorOption] = [
        AccentColorOption(id: "red", name: "Red", color: Color(red: 0.90, green: 0.24, blue: 0.28)),
        AccentColorOption(id: "orange", name: "Orange", color: Color(red: 0.94, green: 0.48, blue: 0.16)),
        AccentColorOption(id: "yellow", name: "Yellow", color: Color(red: 0.90, green: 0.72, blue: 0.18)),
        AccentColorOption(id: "green", name: "Green", color: Color(red: 0.22, green: 0.70, blue: 0.38)),
        AccentColorOption(id: "cyan", name: "Cyan", color: Color(red: 0.10, green: 0.70, blue: 0.76)),
        AccentColorOption(id: "blue", name: "Blue", color: Color(red: 0.20, green: 0.48, blue: 0.92)),
        AccentColorOption(id: "purple", name: "Purple", color: Color(red: 0.56, green: 0.34, blue: 0.88)),
        AccentColorOption(id: "pink", name: "Pink", color: Color(red: 0.92, green: 0.34, blue: 0.62)),
        AccentColorOption(id: "rose", name: "Rose", color: Color(red: 0.86, green: 0.30, blue: 0.42)),
        AccentColorOption(id: "amber", name: "Amber", color: Color(red: 0.96, green: 0.58, blue: 0.18)),
        AccentColorOption(id: "lime", name: "Lime", color: Color(red: 0.54, green: 0.76, blue: 0.22)),
        AccentColorOption(id: "mint", name: "Mint", color: Color(red: 0.18, green: 0.72, blue: 0.56)),
        AccentColorOption(id: "teal", name: "Teal", color: Color(red: 0.12, green: 0.58, blue: 0.70)),
        AccentColorOption(id: "indigo", name: "Indigo", color: Color(red: 0.36, green: 0.38, blue: 0.86)),
        AccentColorOption(id: "darkGray", name: "Dark Gray", color: Color(red: 0.36, green: 0.38, blue: 0.43)),
        AccentColorOption(id: "lightGray", name: "Light Gray", color: Color(red: 0.72, green: 0.74, blue: 0.78))
    ]

    static func option(for id: String) -> AccentColorOption {
        all.first { $0.id == id } ?? all[6]
    }
}

enum MotionTokens {
    static let quick: Animation = .interactiveSpring(response: 0.22, dampingFraction: 0.72, blendDuration: 0.04)
    static let soft: Animation = .interactiveSpring(response: 0.42, dampingFraction: 0.78, blendDuration: 0.08)
    static let page: Animation = .interactiveSpring(response: 0.54, dampingFraction: 0.82, blendDuration: 0.10)
    static let appear: Animation = .spring(response: 0.48, dampingFraction: 0.84, blendDuration: 0.08)
    static let hover: Animation = .interactiveSpring(response: 0.30, dampingFraction: 0.74, blendDuration: 0.04)
    static let color: Animation = .easeInOut(duration: 0.30)
    static let listSelection: Animation = .interactiveSpring(response: 0.34, dampingFraction: 0.76, blendDuration: 0.06)
}

func makeInterfaceAnimation(reduceMotion: Bool, intensity: MotionIntensity) -> Animation? {
    guard !reduceMotion else { return nil }
    switch intensity {
    case .enhanced: return MotionTokens.page
    case .reduced: return MotionTokens.soft
    case .none: return nil
    }
}

struct LightweightPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : MotionTokens.quick, value: configuration.isPressed)
    }
}

struct SidebarPageButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isSelected: Bool
    let accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.15) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? accentColor.opacity(0.22) : Color.clear, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : MotionTokens.listSelection, value: isSelected)
            .animation(reduceMotion ? nil : MotionTokens.quick, value: configuration.isPressed)
    }
}

struct ControlButtonHoverModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    let accentColor: Color

    func body(content: Content) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(accentColor.opacity(isHovered ? 0.08 : 0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(accentColor.opacity(isHovered ? 0.42 : 0), lineWidth: isHovered ? 1.2 : 1)
            }
            .scaleEffect(isHovered && !reduceMotion ? 1.018 : 1)
            .animation(reduceMotion ? nil : MotionTokens.hover, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

struct InteractivePanelModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    let cornerRadius: CGFloat
    let accentColor: Color

    func body(content: Content) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(accentColor.opacity(isHovered ? 0.045 : 0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(accentColor.opacity(isHovered ? 0.34 : 0.12), lineWidth: isHovered ? 1.3 : 1)
            }
            .scaleEffect(isHovered && !reduceMotion ? 1.004 : 1)
            .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.035), radius: isHovered ? 9 : 4, x: 0, y: isHovered ? 4 : 2)
            .animation(reduceMotion ? nil : MotionTokens.hover, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

struct SoftAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 8)
            .onAppear {
                guard !isVisible else { return }
                guard delay > 0 else {
                    withAnimation(reduceMotion ? nil : MotionTokens.appear) { isVisible = true }
                    return
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    withAnimation(reduceMotion ? nil : MotionTokens.appear) { isVisible = true }
                }
            }
    }
}

extension View {
    func interactivePanel(cornerRadius: CGFloat = 16, accentColor: Color) -> some View {
        modifier(InteractivePanelModifier(cornerRadius: cornerRadius, accentColor: accentColor))
    }

    func controlButtonHover(accentColor: Color) -> some View {
        modifier(ControlButtonHoverModifier(accentColor: accentColor))
    }

    func softAppear(delay: Double = 0) -> some View {
        modifier(SoftAppearModifier(delay: delay))
    }
}

struct AccentColorPicker: View {
    @Binding var selection: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 16), spacing: 7), count: 8)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
            ForEach(AccentColorOption.all) { option in
                Button {
                    withAnimation(reduceMotion ? nil : MotionTokens.color) {
                        selection = option.id
                    }
                } label: {
                    Capsule(style: .continuous)
                        .fill(option.color)
                        .frame(height: 14)
                        .overlay {
                            if selection == option.id {
                                Capsule(style: .continuous)
                                    .strokeBorder(.primary.opacity(0.9), lineWidth: 1.5)
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .strokeBorder(.white.opacity(0.9), lineWidth: 0.8)
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)
                        .contentShape(Rectangle())
                        .accessibilityLabel(option.name)
                }
                .buttonStyle(LightweightPressButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(title)
                .frame(width: 126, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SidebarStatusRow<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            content
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 42, height: 42)
                .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.largeTitle.bold())
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
    }
}
