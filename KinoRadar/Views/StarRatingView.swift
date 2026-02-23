import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    var maxRating = 5

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundStyle(index <= rating ? .yellow : .gray)
                    .font(.title3)
                    .onTapGesture {
                        if rating == index {
                            rating = 0
                        } else {
                            rating = index
                        }
                    }
                    .accessibilityLabel("\(index) Sterne")
            }
        }
    }
}

