//
//  NowPlayingProgressView.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct NowPlayingProgressView: View {
    let item: NowPlayingItem
    let onSeek: ((Double) -> Void)?
    @Binding var isSeeking: Bool
    @Binding var seekProgress: Double

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let displayProgress = isSeeking ? seekProgress : item.progress

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: isSeeking ? 2.5 : 1.5)
                        .fill(.white.opacity(0.3))
                        .frame(height: isSeeking ? 5 : 3)

                    RoundedRectangle(cornerRadius: isSeeking ? 2.5 : 1.5)
                        .fill(.white)
                        .frame(width: geometry.size.width * displayProgress, height: isSeeking ? 5 : 3)

                    if isSeeking && onSeek != nil {
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .position(x: geometry.size.width * displayProgress, y: 2.5)
                    }
                }
                .frame(height: isSeeking ? 5 : 3)
                .contentShape(Rectangle().size(width: geometry.size.width, height: 30))
                .accessibilityLabel("Playback progress")
                .accessibilityValue("\(Int(displayProgress * 100)) percent")
                .accessibilityHint("Drag to seek")
                .gesture(
                    onSeek != nil ? DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isSeeking {
                                isSeeking = true
                                seekProgress = item.progress
                                HapticService.impact(.light)
                            }
                            seekProgress = max(0, min(1, value.location.x / geometry.size.width))
                        }
                        .onEnded { value in
                            let finalProgress = max(0, min(1, value.location.x / geometry.size.width))
                            onSeek?(finalProgress)
                            HapticService.impact(.medium)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isSeeking = false
                            }
                        } : nil
                )
            }
            .frame(height: isSeeking ? 5 : 3)
            .animation(.easeInOut(duration: 0.15), value: isSeeking)

            if item.isPlaying && !isSeeking {
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    timeLabels(at: context.date)
                }
            } else {
                timeLabels(at: Date())
            }
        }
    }

    @ViewBuilder
    private func timeLabels(at date: Date) -> some View {
        HStack {
            Text(seekTimeDisplay(at: date).formattedDuration)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Text("-\(seekRemainingDisplay(at: date).formattedDuration)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func seekTimeDisplay(at date: Date) -> TimeInterval {
        if isSeeking {
            return seekProgress * Double(item.duration)
        }
        return item.estimatedPosition(at: date)
    }

    private func seekRemainingDisplay(at date: Date) -> TimeInterval {
        if isSeeking {
            return max(0, Double(item.duration) - seekProgress * Double(item.duration))
        }
        return item.estimatedRemainingTime(at: date)
    }
}
