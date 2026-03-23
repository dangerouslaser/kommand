//
//  LibraryFilterSheet.swift
//  kodi.remote.xbmc
//

import SwiftUI

struct LibraryFilterSheet: View {
    @Binding var sortField: LibraryState.SortField
    @Binding var sortAscending: Bool
    @Binding var watchFilter: LibraryState.LibraryFilter
    @Binding var selectedGenres: Set<String>
    let availableGenres: [String]
    let onShuffle: (() -> Void)?

    @Environment(\.themeColors) private var colors
    @Environment(\.dismiss) private var dismiss

    private var hasActiveFilters: Bool {
        watchFilter != .all || !selectedGenres.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionSpacing) {
                    sortSection
                    watchStatusSection
                    if !availableGenres.isEmpty {
                        genreSection
                    }
                }
                .padding()
            }
            .navigationTitle("Sort & Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if hasActiveFilters {
                        Button("Reset") {
                            watchFilter = .all
                            selectedGenres = []
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sort Section

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text("Sort By")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: DesignSystem.Spacing.small) {
                ForEach(LibraryState.SortField.allCases, id: \.self) { field in
                    FilterChip(
                        label: field.displayName,
                        icon: sortField == field
                            ? (sortAscending ? "chevron.up" : "chevron.down")
                            : nil,
                        isSelected: sortField == field
                    ) {
                        if sortField == field {
                            sortAscending.toggle()
                        } else {
                            sortField = field
                            sortAscending = true
                        }
                        if field == .random { onShuffle?() }
                    }
                }
            }
        }
    }

    // MARK: - Watch Status Section

    private var watchStatusSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text("Watch Status")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: DesignSystem.Spacing.small) {
                ForEach(LibraryState.LibraryFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        label: filter.displayName,
                        isSelected: watchFilter == filter
                    ) {
                        watchFilter = filter
                    }
                }
            }
        }
    }

    // MARK: - Genre Section

    private var genreSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Text("Genre")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if !selectedGenres.isEmpty {
                    Text("(\(selectedGenres.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            FlowLayout(spacing: DesignSystem.Spacing.small) {
                ForEach(availableGenres, id: \.self) { genre in
                    FilterChip(
                        label: genre,
                        isSelected: selectedGenres.contains(genre)
                    ) {
                        if selectedGenres.contains(genre) {
                            selectedGenres.remove(genre)
                        } else {
                            selectedGenres.insert(genre)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.themeColors) private var colors

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? colors.accent : Color(.secondarySystemFill))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
