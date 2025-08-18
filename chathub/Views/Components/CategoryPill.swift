//
//  CategoryPill.swift
//  ChatHub
//
//  Created by Claude on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import SwiftUI

/// CategoryPill - Enhanced pill component for AboutYou categories
struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white.opacity(0.9) : Color("shade6"))
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : Color("dark"))
            
            if isSelected {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Group {
                if isSelected {
                    Color("blue")
                } else {
                    Color("shade2")
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.white.opacity(0.25) : Color("shade4"), lineWidth: 0.8)
        )
        .clipShape(Capsule())
        .onTapGesture { onTap() }
    }
}

/// ZodiacPill - Special pill component for zodiac signs
struct ZodiacPill: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white.opacity(0.9) : Color("shade6"))
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : Color("dark"))
            
            if isSelected {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Group {
                if isSelected {
                    Color("blue")
                } else {
                    Color("shade2")
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.white.opacity(0.25) : Color("shade4"), lineWidth: 0.8)
        )
        .clipShape(Capsule())
        .onTapGesture { onTap() }
    }
}

#Preview {
    VStack(spacing: 16) {
        CategoryPill(
            title: "I love music",
            icon: "music.note",
            isSelected: false,
            onTap: {}
        )
        
        CategoryPill(
            title: "I love music",
            icon: "music.note",
            isSelected: true,
            onTap: {}
        )
        
        ZodiacPill(
            title: "Aries ♈",
            isSelected: false,
            onTap: {}
        )
        
        ZodiacPill(
            title: "Aries ♈",
            isSelected: true,
            onTap: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
