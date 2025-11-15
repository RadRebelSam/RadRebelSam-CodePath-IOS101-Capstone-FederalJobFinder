//
//  LaunchScreenView.swift
//  Federal Job Finder
//
//  Created by Federal Job Finder Team on 11/13/25.
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.white,
                    Color.blue.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App icon placeholder
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 120, height: 120)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                
                // App name
                VStack(spacing: 8) {
                    Text("Federal Job Finder")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Discover Your Federal Career")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .opacity(opacity)
                .animation(.easeIn(duration: 0.8).delay(0.5), value: opacity)
                
                // Loading indicator
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.blue)
                    .opacity(opacity)
                    .animation(.easeIn(duration: 0.8).delay(1.0), value: opacity)
            }
        }
        .onAppear {
            isAnimating = true
            opacity = 1.0
        }
    }
}

#Preview {
    LaunchScreenView()
}