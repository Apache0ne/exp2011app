import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone")
                .font(.system(size: 56))

            Text("Hello from exp2011app")
                .font(.title)
                .fontWeight(.semibold)

            Text("This basic iOS app is running on your iPhone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}
