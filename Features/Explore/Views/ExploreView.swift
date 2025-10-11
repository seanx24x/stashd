//
//  ExploreView.swift
//  stashd
//
//  Created by Sean Lynch on 10/9/25.
//


// File: Features/Explore/Views/ExploreView.swift

import SwiftUI

struct ExploreView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xLarge) {
                    SearchBar()
                        .padding(.horizontal, Spacing.large)
                    
                    CategoriesSection()
                    
                    Text("Trending collections coming soon")
                        .font(.bodyLarge)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.top, Spacing.xxLarge)
                }
            }
            .navigationTitle("Explore")
        }
    }
}

struct SearchBar: View {
    @State private var searchText = ""
    
    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textTertiary)
            
            TextField("Search collections, users...", text: $searchText)
                .textInputAutocapitalization(.never)
        }
        .padding(Spacing.medium)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

struct CategoriesSection: View {
    let columns = [
        GridItem(.flexible(), spacing: Spacing.medium),
        GridItem(.flexible(), spacing: Spacing.medium)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Categories")
                .font(.headlineSmall)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, Spacing.large)
            
            LazyVGrid(columns: columns, spacing: Spacing.medium) {
                ForEach(CollectionCategory.allCases, id: \.self) { category in
                    CategoryCard(category: category)
                }
            }
            .padding(.horizontal, Spacing.large)
        }
    }
}

struct CategoryCard: View {
    let category: CollectionCategory
    
    var body: some View {
        VStack(spacing: Spacing.small) {
            Image(systemName: category.iconName)
                .font(.system(size: 32))
                .foregroundStyle(Color.stashdPrimary)
            
            Text(category.rawValue)
                .font(.labelLarge)
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}