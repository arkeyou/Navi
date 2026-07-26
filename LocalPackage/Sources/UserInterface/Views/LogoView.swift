import SwiftUI

struct LogoView: View {
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Spacer()
                    Image(.monoIcon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundColor(Color(.systemGray4))
                    /*Text("navi")
                        .italic()
                        .bold()
                        .foregroundColor(Color(.systemGray4))*/
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: proxy.size.height / 2)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.secondarySystemBackground))
        }
    }
}

#Preview {
    LogoView()
}
