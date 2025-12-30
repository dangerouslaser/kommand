//
//  NavigationPad.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct NavigationPad: View {
    let onInput: (InputAction) -> Void

    private let buttonSize: CGFloat = 70
    private let centerButtonSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 8) {
            // Up button
            DirectionButton(
                direction: .up,
                size: buttonSize,
                action: { onInput(.up) }
            )

            HStack(spacing: 8) {
                // Left button
                DirectionButton(
                    direction: .left,
                    size: buttonSize,
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
                        .background(.tint, in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select")

                // Right button
                DirectionButton(
                    direction: .right,
                    size: buttonSize,
                    action: { onInput(.right) }
                )
            }

            // Down button
            DirectionButton(
                direction: .down,
                size: buttonSize,
                action: { onInput(.down) }
            )
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
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
    let size: CGFloat
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: direction.iconName)
                .font(.title)
                .fontWeight(.semibold)
                .frame(width: size, height: size)
                .background(
                    isPressed ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.15),
                    in: Circle()
                )
                .foregroundStyle(.primary)
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
