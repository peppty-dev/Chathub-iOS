import SwiftUI

/// Rating Popup View - matches Android dialog_rate_us.xml exactly
struct RatingPopupView: View {
    @ObservedObject private var ratingService = RatingService.shared
    @Environment(\.colorScheme) var colorScheme
    
    // Consistent background color: shade2 (following RefreshPopupView pattern)
    private var customBackgroundColor: Color {
        Color("shade2")
    }
    
    var body: some View {
        ZStack {
            // Background overlay - dark semi-transparent covering everything including top bar
            Color.black.opacity(0.6)
                .ignoresSafeArea(.all, edges: .all)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Main dialog container (following RefreshPopupView structure)
            VStack {
                Spacer() // Center vertically
                
                // Dialog content - improved layout following RefreshPopupView patterns
                VStack(spacing: 0) {
                    // Header Section - removed icon, improved spacing
                    VStack(spacing: 16) {
                        // Title (matching Android R.id.title) - improved typography
                        Text("Rate the App")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color("dark"))
                            .multilineTextAlignment(.center)
                        
                        // Subtitle (matching Android R.id.secondtitale) - improved styling
                        Text("Your feedback helps us improve the app")
                            .font(.system(size: 14))
                            .foregroundColor(Color("shade_800"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    
                    // Star Rating Section (matching Android star_rating_layout with improved spacing and click quality)
                    VStack(spacing: 16) {
                        HStack(spacing: 16) { // Increased spacing from 8 to 16 for better click quality
                            ForEach(1...5, id: \.self) { star in
                                Button(action: {
                                    ratingService.rating = Float(star)
                                }) {
                                                                    Image(systemName: "star.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(star <= Int(ratingService.rating) ? 
                                                   starColor(for: Int(ratingService.rating)) : 
                                                   Color.gray)
                                        .scaleEffect(starScale(for: star))
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: ratingService.rating)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: 44, height: 44) // Minimum touch target size for better accessibility
                            }
                        }
                        
                        // Rating Guide (positioning labels below specific stars)
                        HStack(spacing: 16) { // Match star spacing
                            // Bad - positioned below first star - show when rating is 0, 1, or 2
                            if Int(ratingService.rating) == 0 || Int(ratingService.rating) <= 2 {
                                Text("Bad")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.red)
                                    .frame(width: 44, alignment: .center)
                            } else {
                                Spacer().frame(width: 44)
                            }
                            
                            // Empty space for second star
                            Spacer().frame(width: 44)
                            
                            // Average - positioned below middle (third) star - show when rating is 0, 1, 2, or 3 (hide for 4-5)
                            if Int(ratingService.rating) == 0 || Int(ratingService.rating) <= 3 {
                                Text("Average")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.yellow)
                                    .frame(minWidth: 60, alignment: .center)
                                    .lineLimit(1)
                            } else {
                                Spacer().frame(minWidth: 60)
                            }
                            
                            // Empty space for fourth star
                            Spacer().frame(width: 44)
                            
                            // Good - positioned below fifth star - always show
                            Text("Good")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                                .frame(width: 44, alignment: .center)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    
                    // Rating Feedback Section (matching Android rating_feedback) - compact horizontal layout
                    if Int(ratingService.rating) > 0 {
                        HStack(spacing: 12) {
                            Text(ratingService.ratingEmoji(for: Int(ratingService.rating)))
                                .font(.system(size: 32)) // Slightly smaller emoji for horizontal layout
                            
                            // Improved text display with proper line spacing and formatting
                            Text(ratingService.ratingDescription(for: Int(ratingService.rating)))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(starColor(for: Int(ratingService.rating)))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true) // Allow proper text wrapping
                        }
                        .padding(.top, 20) // Reduced padding for more compact layout
                        .padding(.horizontal, 20)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Buttons Section (matching Android button layout) - improved button design following RefreshPopupView
                    HStack(spacing: 12) {
                        // Maybe Later Button (matching Android R.id.maybe_later) - improved styling
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: RatingPopupView", message: "maybe later button tapped")
                            ratingService.cancelRatingDialog()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color("shade_800"))
                                
                                Text("MAYBE LATER")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("shade_800"))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("shade_200"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color("shade_300"), lineWidth: 1)
                                    )
                            )
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Submit Button (matching Android R.id.submit_rating) - improved styling with gradient
                        Button(action: {
                            AppLogger.log(tag: "LOG-APP: RatingPopupView", message: "submit rating button tapped with rating: \(ratingService.rating)")
                            if ratingService.rating > 0 {
                                ratingService.submitRating()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: ratingService.rating > 0 ? "paperplane.fill" : "paperplane")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                
                                Text("SUBMIT")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ratingService.rating > 0 ? 
                                          LinearGradient(
                                            colors: [Color("ColorAccent"), Color("ColorAccent").opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                          ) : 
                                          LinearGradient(
                                            colors: [Color("grey_500"), Color("grey_500")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                          )
                                    )
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(ratingService.rating == 0)
                        .opacity(ratingService.rating > 0 ? 1.0 : 0.6)
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(customBackgroundColor)
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: ratingService.rating)
                
                Spacer() // Center vertically
                
                // Bottom spacing to keep dialog above tab bar (approximately 100 points for safe area)
                Color.clear
                    .frame(height: 100)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: ratingService.rating)
    }
    
    // MARK: - Helper Methods (matching Android exactly)
    
    /// Get star color based on rating - matches Android updateStars() logic
    private func starColor(for rating: Int) -> Color {
        switch rating {
        case 1, 2: return .red
        case 3: return .yellow
        case 4, 5: return .green
        default: return Color.gray
        }
    }
    
    /// Get star scale - matches Android scaleX/scaleY exactly but with subtle improvements
    private func starScale(for star: Int) -> CGFloat {
        switch star {
        case 1: return 0.85  // Slightly improved from 0.8
        case 2: return 1.0   // matches Android scaleX="1.0" scaleY="1.0"
        case 3: return 1.15  // Slightly improved from 1.2
        case 4: return 1.25  // Slightly improved from 1.4
        case 5: return 1.35  // Slightly improved from 1.6
        default: return 1.0
        }
    }
}

#Preview {
    RatingPopupView()
}
