import SwiftUI

/**
 * PhotoReportReasonButton
 * 
 * A reusable button component for photo report reason selection.
 * Used in PhotoReportView and other reporting interfaces.
 * 
 * Features:
 * - Toggle selection state with visual feedback
 * - Consistent styling with app theme colors
 * - Accessible button interaction
 */

// MARK: - Photo Report Reason Button Component
struct PhotoReportReasonButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color("dark"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 40)
                .padding(.horizontal, 10)
                .background(isSelected ? Color("ButtonColor").opacity(0.2) : Color("shade2"))
                .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct PhotoReportReasonButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            PhotoReportReasonButton(
                title: "    Sample Report Reason    ",
                isSelected: false
            ) {
                print("Button tapped")
            }
            
            PhotoReportReasonButton(
                title: "    Selected Report Reason    ",
                isSelected: true
            ) {
                print("Selected button tapped")
            }
        }
        .padding()
        .background(Color("Background Color"))
    }
} 