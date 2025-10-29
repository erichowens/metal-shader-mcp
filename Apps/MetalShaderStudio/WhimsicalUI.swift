import SwiftUI
import MetalKit
import Metal

// MARK: - Whimsical Button System with Disney BRDFs

struct WhimsicalButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle
    @State private var isPressed = false
    @State private var sparklePhase: Double = 0
    @State private var isHovered = false
    
    enum ButtonStyle {
        case primary    // Main action buttons
        case secondary  // Secondary actions
        case sparkle    // Special sparkle effect
        case magic      // Magic moments
        case danger     // Destructive actions
    }
    
    var body: some View {
        Button(action: {
            // Satisfying haptic feedback (macOS compatible)
            #if os(macOS)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            #endif
            
            // Sparkle animation
            withAnimation(.easeInOut(duration: 0.6)) {
                sparklePhase += .pi * 2
            }
            
            action()
        }) {
            Text(title)
                .font(.system(.body, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    // Disney BRDF gradient based on style
                    backgroundGradient
                        .overlay(
                            // Sparkle effect overlay with fallback
                            Group {
                                if #available(macOS 14.0, *) {
                                    SparkleEffect(phase: sparklePhase, intensity: sparkleIntensity)
                                } else {
                                    SparkleEffectFallback(phase: sparklePhase, intensity: sparkleIntensity)
                                }
                            }
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            // Additional tap animation
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
    
    private var backgroundGradient: LinearGradient {
        switch style {
        case .primary:
            return LinearGradient(
                colors: [.blue.opacity(0.8), .purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            return LinearGradient(
                colors: [.gray.opacity(0.7), .gray.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sparkle:
            return LinearGradient(
                colors: [.yellow.opacity(0.8), .orange.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .magic:
            return LinearGradient(
                colors: [.pink.opacity(0.8), .purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .danger:
            return LinearGradient(
                colors: [.red.opacity(0.8), .pink.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var sparkleIntensity: Double {
        switch style {
        case .sparkle, .magic: return 0.8
        case .primary: return 0.4
        case .secondary: return 0.2
        case .danger: return 0.3
        }
    }
}

// MARK: - Sparkle Effect using Metal Shaders

@available(macOS 14.0, *)
struct SparkleEffect: View {
    let phase: Double
    let intensity: Double
    
    var body: some View {
        Rectangle()
            .fill(
                Shader(
                    function: ShaderFunction(library: .default, name: "sparkle"),
                    arguments: [
                        .float(phase),
                        .float(intensity),
                        .float(0.1)  // size
                    ]
                )
            )
            .opacity(0.6)
    }
}

// Fallback for older macOS versions
struct SparkleEffectFallback: View {
    let phase: Double
    let intensity: Double
    
    var body: some View {
        Rectangle()
            .fill(
                RadialGradient(
                    colors: [.yellow.opacity(intensity), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 50
                )
            )
            .opacity(0.6)
    }
}

// MARK: - Magic Moments System

struct MagicMoment: View {
    let moment: MagicMomentType
    @State private var isVisible = false
    @State private var confettiPhase: Double = 0
    
    enum MagicMomentType {
        case firstShader
        case aestheticImprovement(Int)
        case competitionWin
        case tutorialCompletion(String)
        case mergeSuccess
        
        var message: String {
            switch self {
            case .firstShader:
                return "🎉 You did it! Your first shader is alive!"
            case .aestheticImprovement(let points):
                return "✨ Your shader just got \(points) points more beautiful!"
            case .competitionWin:
                return "🏆 You're a shader wizard! Your creation is magical!"
            case .tutorialCompletion(let concept):
                return "🌟 You've unlocked the power of \(concept)! Ready for the next adventure?"
            case .mergeSuccess:
                return "🎊 Merge magic complete! Your code is sparkling!"
            }
        }
        
        var animation: Animation {
            switch self {
            case .firstShader, .mergeSuccess:
                return .spring(response: 0.6, dampingFraction: 0.7)
            case .aestheticImprovement:
                return .easeInOut(duration: 0.8)
            case .competitionWin:
                return .spring(response: 0.8, dampingFraction: 0.6)
            case .tutorialCompletion:
                return .easeInOut(duration: 1.0)
            }
        }
        
        var confettiColor: Color {
            switch self {
            case .firstShader, .mergeSuccess: return .blue
            case .aestheticImprovement: return .yellow
            case .competitionWin: return .orange
            case .tutorialCompletion: return .purple
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(moment.message)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [moment.confettiColor.opacity(0.9), moment.confettiColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            ConfettiEffect(phase: confettiPhase, color: moment.confettiColor)
                        )
                )
                .scaleEffect(isVisible ? 1.0 : 0.1)
                .opacity(isVisible ? 1.0 : 0.0)
                .animation(moment.animation, value: isVisible)
        }
        .onAppear {
            isVisible = true
            
            // Start confetti animation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                confettiPhase += .pi * 2
            }
            
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeOut(duration: 0.5)) {
                    isVisible = false
                }
            }
        }
    }
}

// MARK: - Confetti Effect

struct ConfettiEffect: View {
    let phase: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .offset(
                        x: sin(phase + Double(index) * 0.3) * geometry.size.width * 0.3,
                        y: cos(phase + Double(index) * 0.3) * geometry.size.height * 0.3
                    )
                    .opacity(0.8)
            }
        }
    }
}

// MARK: - Whimsical Error Messages

struct WhimsicalErrorMessage: View {
    let error: CompilationError
    @State private var showEncouragement = false
    @State private var showCelebration = false
    
    struct CompilationError {
        let type: ErrorType
        let message: String
        let lineNumber: Int?
        let suggestion: String?
        
        enum ErrorType {
            case syntax
            case semantic
            case performance
            case warning
            case info
        }
        
        var whimsicalMessage: String {
            switch type {
            case .syntax:
                return "🧶 Oops! Your shader got a bit tangled. Let's untangle it together!"
            case .semantic:
                return "🤔 Hmm, something doesn't quite add up here. Let's figure it out!"
            case .performance:
                return "🐌 Your shader is taking a leisurely stroll. Let's speed it up!"
            case .warning:
                return "⚠️ Just a friendly heads up from your shader!"
            case .info:
                return "💡 Here's a helpful hint for your shader!"
            }
        }
        
        var encouragement: String {
            switch type {
            case .syntax:
                return "Don't worry, even Pixar pros make typos! ✨"
            case .semantic:
                return "Every shader wizard started somewhere! 🌟"
            case .performance:
                return "Optimization is an art form! 🎨"
            case .warning:
                return "You're doing great! Keep going! 💪"
            case .info:
                return "You're learning something new! 🎓"
            }
        }
        
        var celebrationWhenFixed: String {
            return "🎉 You untangled it! Your shader is alive and sparkling! ✨"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Main error message
            Text(error.whimsicalMessage)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Technical details
            if let suggestion = error.suggestion {
                Text(suggestion)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            // Encouragement
            if showEncouragement {
                Text(error.encouragement)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .scale))
            }
            
            // Celebration when fixed
            if showCelebration {
                Text(error.celebrationWhenFixed)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.green)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).delay(0.5)) {
                showEncouragement = true
            }
        }
        .onChange(of: error.type) { newType in
            if newType == .info {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showCelebration = true
                }
            }
        }
    }
}

// MARK: - Sparkle Shader Function

@available(macOS 14.0, *)
extension ShaderFunction {
    static let sparkle = ShaderFunction(
        library: .default,
        name: "sparkle"
    )
}

// MARK: - Preview Support

#if DEBUG
struct WhimsicalUI_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            WhimsicalButton(title: "✨ Make it Sparkle", action: {}, style: .sparkle)
            WhimsicalButton(title: "🎨 Improve Aesthetics", action: {}, style: .primary)
            WhimsicalButton(title: "🧪 Run Tests", action: {}, style: .secondary)
            WhimsicalButton(title: "🏆 Submit Competition", action: {}, style: .magic)
            
            MagicMoment(moment: .firstShader)
            MagicMoment(moment: .aestheticImprovement(15))
            
            WhimsicalErrorMessage(
                error: WhimsicalErrorMessage.CompilationError(
                    type: .syntax,
                    message: "Expected ';' after expression",
                    lineNumber: 5,
                    suggestion: "Add a semicolon at the end of line 5"
                )
            )
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}
#endif
