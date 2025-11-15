//
//  LoadingView.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import SwiftUI

// MARK: - Loading Indicator View

/// A reusable loading indicator with customizable appearance
struct LoadingView: View {
    let message: String?
    let showProgress: Bool
    let progress: Double?
    
    init(
        message: String? = nil,
        showProgress: Bool = false,
        progress: Double? = nil
    ) {
        self.message = message
        self.showProgress = showProgress
        self.progress = progress
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress Indicator
            if showProgress, let progress = progress {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)
            }
            
            // Loading Message
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Inline Loading View

/// A compact loading indicator for inline use
struct InlineLoadingView: View {
    let message: String?
    let size: LoadingSize
    
    init(message: String? = nil, size: LoadingSize = .medium) {
        self.message = message
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(size.scale)
            
            if let message = message {
                Text(message)
                    .font(size.font)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Full Screen Loading View

/// A full-screen loading overlay
struct FullScreenLoadingView: View {
    let message: String?
    let showProgress: Bool
    let progress: Double?
    let allowsInteraction: Bool
    
    init(
        message: String? = nil,
        showProgress: Bool = false,
        progress: Double? = nil,
        allowsInteraction: Bool = false
    ) {
        self.message = message
        self.showProgress = showProgress
        self.progress = progress
        self.allowsInteraction = allowsInteraction
    }
    
    var body: some View {
        ZStack {
            // Background Overlay
            if !allowsInteraction {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
            }
            
            // Loading Content
            VStack(spacing: 20) {
                // Progress Indicator
                if showProgress, let progress = progress {
                    VStack(spacing: 12) {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2.0)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2.0)
                }
                
                // Loading Message
                if let message = message {
                    Text(message)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(40)
        }
    }
}

// MARK: - Skeleton Loading View

/// A skeleton loading view for list items
struct SkeletonLoadingView: View {
    let itemCount: Int
    let itemHeight: CGFloat
    
    init(itemCount: Int = 5, itemHeight: CGFloat = 80) {
        self.itemCount = itemCount
        self.itemHeight = itemHeight
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<itemCount, id: \.self) { _ in
                SkeletonItemView(height: itemHeight)
            }
        }
        .padding(.horizontal, 16)
    }
}

/// Individual skeleton item
struct SkeletonItemView: View {
    let height: CGFloat
    @State private var isAnimating = false
    
    init(height: CGFloat) {
        self.height = height
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar/Icon placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(skeletonGradient)
                .frame(width: height * 0.6, height: height * 0.6)
            
            VStack(alignment: .leading, spacing: 8) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Subtitle placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(height: 12)
                    .frame(maxWidth: .infinity * 0.7, alignment: .leading)
                
                // Additional info placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(height: 10)
                    .frame(maxWidth: .infinity * 0.5, alignment: .leading)
            }
            
            Spacer()
        }
        .frame(height: height)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
    
    private var skeletonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemGray5).opacity(isAnimating ? 0.6 : 1.0),
                Color(.systemGray4).opacity(isAnimating ? 0.6 : 1.0),
                Color(.systemGray5).opacity(isAnimating ? 0.6 : 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Pull to Refresh Loading

/// Custom pull-to-refresh loading indicator
struct PullToRefreshLoadingView: View {
    let progress: Double
    let isRefreshing: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(progress >= 1.0 ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: progress)
            }
            
            Text(isRefreshing ? "Refreshing..." : "Pull to refresh")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 60)
        .opacity(max(0.3, min(1.0, progress)))
    }
}

// MARK: - Loading Button

/// A button that shows loading state
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isLoading ? .gray : .blue)
            )
            .foregroundColor(.white)
        }
        .disabled(isLoading)
    }
}

// MARK: - Loading Size Enum

enum LoadingSize {
    case small
    case medium
    case large
    
    var scale: CGFloat {
        switch self {
        case .small:
            return 0.7
        case .medium:
            return 1.0
        case .large:
            return 1.3
        }
    }
    
    var font: Font {
        switch self {
        case .small:
            return .caption
        case .medium:
            return .subheadline
        case .large:
            return .headline
        }
    }
}

// MARK: - Loading Overlay Modifier

struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let message: String?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)
            
            if isLoading {
                LoadingView(message: message)
            }
        }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading, message: message))
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard Loading View
            LoadingView(message: "Loading jobs...")
                .previewDisplayName("Standard Loading")
            
            // Progress Loading View
            LoadingView(
                message: "Downloading data...",
                showProgress: true,
                progress: 0.65
            )
            .previewDisplayName("Progress Loading")
            
            // Inline Loading View
            InlineLoadingView(message: "Loading...", size: .medium)
                .previewDisplayName("Inline Loading")
            
            // Full Screen Loading
            FullScreenLoadingView(message: "Searching for jobs...")
                .previewDisplayName("Full Screen Loading")
            
            // Skeleton Loading
            SkeletonLoadingView(itemCount: 3)
                .previewDisplayName("Skeleton Loading")
            
            // Loading Button
            VStack {
                LoadingButton(title: "Search Jobs", isLoading: false) {}
                LoadingButton(title: "Searching...", isLoading: true) {}
            }
            .padding()
            .previewDisplayName("Loading Button")
        }
    }
}
#endif