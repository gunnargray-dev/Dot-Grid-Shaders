import SwiftUI

struct ContentView: View {
    @State private var isPlaying: Bool = true
    @State private var animationSpeed: Double = 0.8
    @State private var particleSize: Double = 0.003
    @State private var particleCount: Double = 1000
    @State private var sphereSize: Double = 400.0
    @State private var isShowingSheet = false
    @State private var isAudioEnabled = false
    @StateObject private var audioProcessor = AudioProcessor()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Only render ParticleShaderView when not in preview
            if !_isPreview {
                ParticleShaderView(
                    isPlaying: $isPlaying,
                    particleSpeed: animationSpeed,
                    particleSize: particleSize,
                    particleCount: Int(particleCount),
                    sphereSize: sphereSize,
                    isAudioEnabled: .constant(true) // Always enabled
                )
                .environmentObject(audioProcessor)
                .onAppear {
                    audioProcessor.startMonitoring()
                }
                .onDisappear {
                    audioProcessor.stopMonitoring()
                }
                .ignoresSafeArea()
            }

            VStack {
                // Audio level
                Text("Audio Level: \(String(format: "%.2f", audioProcessor.currentDecibels))")
                    .foregroundColor(.white)
                Text("Audio Scale: \(String(format: "%.2f", 1.0 + audioProcessor.currentDecibels * 4.0))")
                    .foregroundColor(.white)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Helper to detect preview environment
private var _isPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

#Preview {
    ContentView()
}
