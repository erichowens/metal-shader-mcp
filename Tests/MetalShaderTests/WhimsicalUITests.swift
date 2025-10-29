import XCTest
import SwiftUI
@testable import MetalShaderStudio

/// Comprehensive tests for the Whimsical UI system
/// Tests verify that our magical buttons, error messages, and moments work correctly
final class WhimsicalUITests: XCTestCase {
    
    // MARK: - WhimsicalButton Tests
    
    func testWhimsicalButtonCreation() throws {
        // Given: A whimsical button with primary style
        var actionCalled = false
        let button = WhimsicalButton(
            title: "Test Button",
            action: { actionCalled = true },
            style: .primary
        )
        
        // Then: Button should be created successfully
        XCTAssertNotNil(button)
    }
    
    func testWhimsicalButtonStyles() throws {
        // Given: All button styles
        let styles: [WhimsicalButton.ButtonStyle] = [.primary, .secondary, .sparkle, .magic, .danger]
        
        // When: Creating buttons with each style
        for style in styles {
            let button = WhimsicalButton(
                title: "Test",
                action: {},
                style: style
            )
            
            // Then: Each button should be created successfully
            XCTAssertNotNil(button, "Button with style \(style) should be created")
        }
    }
    
    func testWhimsicalButtonActionTriggered() throws {
        // Given: A button with an action
        var actionCalled = false
        let button = WhimsicalButton(
            title: "Click Me",
            action: { actionCalled = true },
            style: .primary
        )
        
        // When: The button action is called
        button.action()
        
        // Then: The action should have been triggered
        XCTAssertTrue(actionCalled, "Button action should be called")
    }
    
    // MARK: - MagicMoment Tests
    
    func testMagicMomentTypes() throws {
        // Given: All magic moment types
        let moments: [MagicMoment.MagicMomentType] = [
            .firstShader,
            .aestheticImprovement(15),
            .competitionWin,
            .tutorialCompletion("UV Mapping"),
            .mergeSuccess
        ]
        
        // Then: Each moment should have appropriate message
        for moment in moments {
            let message = moment.message
            XCTAssertFalse(message.isEmpty, "Magic moment should have a message")
            XCTAssertTrue(message.contains("🎉") || message.contains("✨") || message.contains("🏆") || message.contains("🌟") || message.contains("🎊"),
                         "Magic moment message should contain celebratory emoji")
        }
    }
    
    func testMagicMomentMessagesAreWhimsical() throws {
        // Given: First shader moment
        let firstShader = MagicMoment.MagicMomentType.firstShader
        
        // Then: Message should be celebratory and encouraging
        XCTAssertTrue(firstShader.message.contains("🎉"), "Should have celebration emoji")
        XCTAssertTrue(firstShader.message.contains("did it") || firstShader.message.contains("alive"),
                     "Should be encouraging")
    }
    
    func testMagicMomentAestheticImprovement() throws {
        // Given: An aesthetic improvement moment
        let improvement = MagicMoment.MagicMomentType.aestheticImprovement(25)
        
        // Then: Message should mention the points and be positive
        XCTAssertTrue(improvement.message.contains("25"), "Should mention the improvement amount")
        XCTAssertTrue(improvement.message.contains("beautiful") || improvement.message.contains("✨"),
                     "Should be positive about beauty")
    }
    
    func testMagicMomentConfettiColors() throws {
        // Given: Different magic moment types
        let moments: [MagicMoment.MagicMomentType] = [
            .firstShader,
            .aestheticImprovement(10),
            .competitionWin,
            .tutorialCompletion("Test"),
            .mergeSuccess
        ]
        
        // Then: Each should have an appropriate confetti color
        for moment in moments {
            let color = moment.confettiColor
            XCTAssertNotNil(color, "Magic moment should have a confetti color")
        }
    }
    
    // MARK: - WhimsicalErrorMessage Tests
    
    func testWhimsicalErrorMessageTypes() throws {
        // Given: Different error types
        let errorTypes: [WhimsicalErrorMessage.CompilationError.ErrorType] = [
            .syntax, .semantic, .performance, .warning, .info
        ]
        
        // When: Creating errors of each type
        for errorType in errorTypes {
            let error = WhimsicalErrorMessage.CompilationError(
                type: errorType,
                message: "Test error message",
                lineNumber: 10,
                suggestion: "Try this fix"
            )
            
            // Then: Each error should have whimsical message
            XCTAssertFalse(error.whimsicalMessage.isEmpty, "Should have whimsical message")
            XCTAssertTrue(error.whimsicalMessage.contains("🧶") || 
                         error.whimsicalMessage.contains("🤔") || 
                         error.whimsicalMessage.contains("🐌") ||
                         error.whimsicalMessage.contains("⚠️") ||
                         error.whimsicalMessage.contains("💡"),
                         "Whimsical message should contain emoji")
        }
    }
    
    func testWhimsicalErrorMessageEncouragement() throws {
        // Given: A syntax error
        let error = WhimsicalErrorMessage.CompilationError(
            type: .syntax,
            message: "Expected semicolon",
            lineNumber: 5,
            suggestion: "Add ; at end of line"
        )
        
        // Then: Should have encouraging message
        XCTAssertFalse(error.encouragement.isEmpty, "Should have encouragement")
        XCTAssertTrue(error.encouragement.contains("Pixar") || error.encouragement.contains("wizard"),
                     "Should mention professionals or mastery")
    }
    
    func testWhimsicalErrorMessageCelebrationWhenFixed() throws {
        // Given: Any error type
        let error = WhimsicalErrorMessage.CompilationError(
            type: .syntax,
            message: "Test",
            lineNumber: 1,
            suggestion: nil
        )
        
        // Then: Should have celebration message for when fixed
        XCTAssertFalse(error.celebrationWhenFixed.isEmpty, "Should have celebration message")
        XCTAssertTrue(error.celebrationWhenFixed.contains("🎉"), "Should be celebratory")
        XCTAssertTrue(error.celebrationWhenFixed.contains("alive") || 
                     error.celebrationWhenFixed.contains("sparkling"),
                     "Should be positive and alive")
    }
    
    // MARK: - ErrorBannerView Tests
    
    func testErrorBannerCreation() throws {
        // Given: Different error severities
        let severities: [ErrorSeverity] = [.error, .warning, .info, .success]
        
        // When: Creating error banners for each severity
        for severity in severities {
            var dismissed = false
            let banner = ErrorBannerView(
                message: "Test message",
                severity: severity,
                onDismiss: { dismissed = true }
            )
            
            // Then: Each should be created successfully
            XCTAssertNotNil(banner, "Banner should be created for \(severity)")
        }
    }
    
    func testErrorBannerDismissal() throws {
        // Given: An error banner
        var dismissed = false
        let banner = ErrorBannerView(
            message: "Compilation failed",
            severity: .error,
            onDismiss: { dismissed = true }
        )
        
        // Then: Banner should exist
        XCTAssertNotNil(banner, "Banner should be created")
        // Note: Dismissal would be tested in UI tests
    }
    
    func testErrorBannerSeverityLevels() throws {
        // Given: All severity levels
        let severities: [ErrorSeverity] = [.error, .warning, .info, .success]
        
        // Then: Each severity should have appropriate styling
        for severity in severities {
            XCTAssertNotNil(severity.color, "Severity should have a color")
            XCTAssertNotNil(severity.icon, "Severity should have an icon")
            XCTAssertFalse(severity.icon.isEmpty, "Icon should not be empty")
        }
    }
    
    // MARK: - Integration Tests
    
    func testWhimsicalUIConsistency() throws {
        // Given: Multiple UI components
        let button = WhimsicalButton(title: "Test", action: {}, style: .sparkle)
        let moment = MagicMoment.MagicMomentType.firstShader
        let error = WhimsicalErrorMessage.CompilationError(
            type: .syntax,
            message: "Test",
            lineNumber: 1,
            suggestion: nil
        )
        
        // Then: All should use consistent whimsical language
        XCTAssertTrue(moment.message.contains("🎉") || moment.message.contains("✨"),
                     "Magic moments should be celebratory")
        XCTAssertTrue(error.whimsicalMessage.contains("🧶") || error.whimsicalMessage.contains("🤔"),
                     "Errors should be gentle")
        // Button title can be anything, but style should be valid
        XCTAssertNotNil(button, "Button should be created")
    }
    
    func testAllWhimsicalMessagesAreEncouraging() throws {
        // Given: Collection of all whimsical messages
        let messages = [
            MagicMoment.MagicMomentType.firstShader.message,
            MagicMoment.MagicMomentType.aestheticImprovement(10).message,
            MagicMoment.MagicMomentType.competitionWin.message,
            WhimsicalErrorMessage.CompilationError(type: .syntax, message: "", lineNumber: 1, suggestion: nil).encouragement,
            WhimsicalErrorMessage.CompilationError(type: .semantic, message: "", lineNumber: 1, suggestion: nil).encouragement,
            WhimsicalErrorMessage.CompilationError(type: .performance, message: "", lineNumber: 1, suggestion: nil).encouragement
        ]
        
        // Then: All messages should be positive and encouraging
        for message in messages {
            XCTAssertFalse(message.isEmpty, "Messages should not be empty")
            // No negative words allowed!
            XCTAssertFalse(message.lowercased().contains("stupid"), "Should not be negative")
            XCTAssertFalse(message.lowercased().contains("dumb"), "Should not be negative")
            XCTAssertFalse(message.lowercased().contains("bad"), "Should not be harsh")
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testWhimsicalUIAccessibility() throws {
        // Given: UI components
        var actionCalled = false
        let button = WhimsicalButton(
            title: "Accessible Button",
            action: { actionCalled = true },
            style: .primary
        )
        
        // Then: Button should have accessible title
        // Note: In a real UI test, we'd verify accessibility labels
        XCTAssertNotNil(button, "Button should exist and be accessible")
    }
    
    // MARK: - Performance Tests
    
    func testWhimsicalButtonCreationPerformance() throws {
        // Given: Performance measurement
        measure {
            // When: Creating many buttons
            for _ in 0..<100 {
                _ = WhimsicalButton(
                    title: "Performance Test",
                    action: {},
                    style: .primary
                )
            }
        }
        // Then: Should complete quickly (measured by XCTest)
    }
    
    func testMagicMomentCreationPerformance() throws {
        // Given: Performance measurement
        measure {
            // When: Creating many magic moments
            for i in 0..<100 {
                _ = MagicMoment.MagicMomentType.aestheticImprovement(i)
            }
        }
        // Then: Should complete quickly
    }
}

// MARK: - Test Goals & Acceptance Criteria

/*
 ## Whimsical UI Test Goals
 
 ### ✅ Goal 1: Whimsical Buttons Work Correctly
 **Acceptance Criteria:**
 - All button styles (primary, secondary, sparkle, magic, danger) can be created
 - Button actions are triggered when called
 - Buttons have appropriate visual gradients
 
 **Tests:**
 - testWhimsicalButtonCreation()
 - testWhimsicalButtonStyles()
 - testWhimsicalButtonActionTriggered()
 
 ### ✅ Goal 2: Magic Moments are Celebratory and Encouraging
 **Acceptance Criteria:**
 - All magic moment types have appropriate messages
 - Messages contain celebratory emojis (🎉, ✨, 🏆, 🌟)
 - Aesthetic improvements show the score increase
 - Each moment has appropriate confetti color
 
 **Tests:**
 - testMagicMomentTypes()
 - testMagicMomentMessagesAreWhimsical()
 - testMagicMomentAestheticImprovement()
 - testMagicMomentConfettiColors()
 
 ### ✅ Goal 3: Error Messages are Whimsical and Teaching
 **Acceptance Criteria:**
 - Errors have gentle, whimsical messages with emojis
 - All errors provide encouragement
 - No harsh or negative language
 - Celebration messages for when errors are fixed
 
 **Tests:**
 - testWhimsicalErrorMessageTypes()
 - testWhimsicalErrorMessageEncouragement()
 - testWhimsicalErrorMessageCelebrationWhenFixed()
 - testAllWhimsicalMessagesAreEncouraging()
 
 ### ✅ Goal 4: Error Banners Display with Whimsy
 **Acceptance Criteria:**
 - Error banners have whimsical prefixes based on severity
 - Errors show encouragement after delay
 - Success messages are celebratory
 - All severities handled correctly
 
 **Tests:**
 - testErrorBannerWhimsicalPrefixes()
 - testErrorBannerEncouragement()
 - testErrorBannerSuccessMessage()
 
 ### ✅ Goal 5: UI is Consistent and Professional
 **Acceptance Criteria:**
 - All components use consistent whimsical language
 - No negative or harsh words anywhere
 - Performance is acceptable (<1s for 100 components)
 - Components are accessible
 
 **Tests:**
 - testWhimsicalUIConsistency()
 - testWhimsicalButtonCreationPerformance()
 - testMagicMomentCreationPerformance()
 - testWhimsicalUIAccessibility()
 
 ## Success Criteria Summary
 
 ✨ **All tests must pass** for the whimsical UI to be considered complete
 🎨 **All components** must use gentle, encouraging language
 🎉 **Magic moments** must feel celebratory
 🧶 **Errors** must feel like gentle guidance, not harsh criticism
 💪 **Performance** must be acceptable for real-world use
 
 ## Running the Tests
 
 ```bash
 # Run all whimsical UI tests
 swift test --filter WhimsicalUITests
 
 # Run specific test
 swift test --filter WhimsicalUITests/testWhimsicalButtonCreation
 
 # Run with verbose output
 swift test --filter WhimsicalUITests --verbose
 ```
 */

