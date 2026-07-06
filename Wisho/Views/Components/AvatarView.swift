import SwiftUI

/// Contact photo if available, otherwise initials on a stable per-person color.
struct AvatarView: View {
    let person: Person
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let data = person.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    backgroundColor
                    Text(person.initials)
                        .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var backgroundColor: Color {
        let palette: [Color] = [.pink, .orange, .teal, .indigo, .purple, .mint, .blue, .red]
        let hash = person.fullName.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[hash % palette.count]
    }
}
