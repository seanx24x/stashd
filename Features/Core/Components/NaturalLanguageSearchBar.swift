//
//  NaturalLanguageSearchBar.swift
//  stashd
//
//  Created by Sean Lynch on 10/17/25.
//


//
//  NaturalLanguageSearchBar.swift
//  stashd
//
//  Created by Sean Lynch
//

import SwiftUI

struct NaturalLanguageSearchBar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    
    let onSearch: () -> Void
    let placeholder: String
    
    @FocusState private var isFocused: Bool
    
    init(
        searchText: Binding<String>,
        isSearching: Binding<Bool>,
        placeholder: String = "Ask me anything about your collection...",
        onSearch: @escaping () -> Void
    ) {
        self._searchText = searchText
        self._isSearching = isSearching
        self.placeholder = placeholder
        self.onSearch = onSearch
    }
    
    var body: some View {
        HStack(spacing: Spacing.small) {
            // AI Sparkle Icon
            Image(systemName: "sparkles")
                .foregroundStyle(Color.stashdPrimary)
                .font(.title3)
            
            // Search Field
            TextField(placeholder, text: $searchText)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit {
                    if !searchText.isEmpty {
                        HapticManager.shared.light()
                        onSearch()
                    }
                }
            
            // Loading or Clear Button
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !searchText.isEmpty {
                Button {
                    HapticManager.shared.light()
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.textTertiary)
                }
            }
        }
        .padding(Spacing.medium)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .strokeBorder(isFocused ? Color.stashdPrimary : Color.separator, lineWidth: isFocused ? 2 : 1)
        }
    }
}

#Preview {
    @Previewable @State var searchText = ""
    @Previewable @State var isSearching = false
    
    return VStack {
        NaturalLanguageSearchBar(
            searchText: $searchText,
            isSearching: $isSearching,
            onSearch: {
                print("Search: \(searchText)")
            }
        )
        .padding()
        
        Spacer()
    }
}