//
//  NavigationPad.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct NavigationPad: View {
    let onInput: (InputAction) -> Void
    @Environment(\.themeColors) private var colors
    @Environment(\.currentTheme) private var theme

    private let buttonWidth: CGFloat = 64
    private let buttonHeight: CGFloat = 48
    private let centerButtonSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 8) {
            // Up button
            DirectionButton(
                direction: .up,
                width: buttonWidth,
                height: buttonHeight,
                action: { onInput(.up) }
            )

            HStack(spacing: 8) {
                // Left button
                DirectionButton(
                    direction: .left,
                    width: buttonWidth,
                    height: buttonHeight,
                    action: { onInput(.left) }
                )

                // Center OK button
                Button {
                    onInput(.select)
                } label: {
                    Text("OK")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(width: centerButtonSize, height: centerButtonSize)
                        .background(colors.accent, in: Circle())
                        .foregroundStyle(colors.invertAccentText ? colors.textPrimary : .white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select")

                // Right button
                DirectionButton(
                    direction: .right,
                    width: buttonWidth,
                    height: buttonHeight,
                    action: { onInput(.right) }
                )
            }

            // Down button
            DirectionButton(
                direction: .down,
                width: buttonWidth,
                height: buttonHeight,
                action: { onInput(.down) }
            )
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(colors.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .themeCardBorder(cornerRadius: 20)
    }
}

struct DirectionButton: View {
    enum Direction {
        case up, down, left, right

        var iconName: String {
            switch self {
            case .up: return "chevron.up"
            case .down: return "chevron.down"
            case .left: return "chevron.left"
            case .right: return "chevron.right"
            }
        }

        var label: String {
            switch self {
            case .up: return "Up"
            case .down: return "Down"
            case .left: return "Left"
            case .right: return "Right"
            }
        }
    }

    let direction: Direction
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    @Environment(\.themeColors) private var colors
    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: direction.iconName)
                .font(.title)
                .fontWeight(.semibold)
                .frame(width: width, height: height)
                .background(
                    isPressed ? colors.secondaryFill.opacity(1.5) : colors.secondaryFill,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .foregroundStyle(colors.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(direction.label)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    NavigationPad(onInput: { print($0) })
        .padding()
}
