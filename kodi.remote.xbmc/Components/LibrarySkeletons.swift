//
//  LibrarySkeletons.swift
//  kodi.remote.xbmc
//

import SwiftUI

// MARK: - Grid Skeleton

struct LibraryGridSkeleton: View {
    let columns: [GridItem]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<12, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemFill))
                            .aspectRatio(2/3, contentMode: .fit)

                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 14)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.tertiarySystemFill))
                                .frame(width: 80, height: 12)
                        }
                    }
                }
            }
            .padding()
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }
}

// MARK: - List Skeleton

struct LibraryListSkeleton: View {
    var body: some View {
        List {
            ForEach(0..<10, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.secondarySystemFill))
                        .frame(width: 60, height: 90)

                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 160, height: 16)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 120, height: 12)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 90, height: 10)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }
}
