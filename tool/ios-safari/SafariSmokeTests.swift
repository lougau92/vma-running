import Vision
import XCTest

final class SafariSmokeTests: XCTestCase {
    func testWorkoutRendersInSafari() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")

        addTeardownBlock {
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Safari workout"
            screenshot.lifetime = .keepAlways
            self.add(screenshot)
        }

        safari.launch()
        let addressPosition = try XCTUnwrap(
            waitForText(["Search or enter website", "Search or enter website name"], timeout: 30),
            "Safari's address bar did not appear"
        )
        safari.coordinate(withNormalizedOffset: CGVector(dx: addressPosition.x, dy: addressPosition.y)).tap()
        let keyboard = safari.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10), "Safari's keyboard did not appear")
        guard keyboard.exists else { return }
        safari.typeText("https://lougau92.github.io/vma-running/\n")

        // Flutter draws its web UI on a canvas. Read the rendered labels directly
        // so the test runs with Safari's default accessibility settings.
        let tabNames = ["Workout", "Entrainement", "Entraînement", "Training"]
        let tabPosition = try XCTUnwrap(
            waitForText(tabNames, below: 0.6, timeout: 90),
            "The workout tab did not render"
        )
        safari.coordinate(withNormalizedOffset: CGVector(dx: tabPosition.x, dy: tabPosition.y)).tap()

        let workoutLabels = ["Session content", "Contenu de la séance", "Inhoud sessie",
                             "Export to watch", "Exporter vers une montre",
                             "Exporteren naar horloge"]
        let loadDeadline = Date().addingTimeInterval(90)
        while Date() < loadDeadline {
            if try textPosition(workoutLabels) != nil { return }
            safari.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
                .press(forDuration: 0.05, thenDragTo:
                    safari.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
            Thread.sleep(forTimeInterval: 1)
        }
        XCTFail("Safari did not render the workout content or watch export control")
    }

    private func waitForText(_ labels: [String], below minimumY: CGFloat = 0, timeout: TimeInterval) throws -> CGPoint? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let position = try textPosition(labels, below: minimumY) { return position }
            Thread.sleep(forTimeInterval: 1)
        }
        return nil
    }

    private func textPosition(_ labels: [String], below minimumY: CGFloat = 0) throws -> CGPoint? {
        let request = VNRecognizeTextRequest()
        try VNImageRequestHandler(data: XCUIScreen.main.screenshot().pngRepresentation)
            .perform([request])
        for observation in request.results ?? [] {
            let center = CGPoint(x: observation.boundingBox.midX,
                                 y: 1 - observation.boundingBox.midY)
            guard center.y > minimumY,
                  let line = observation.topCandidates(1).first?.string,
                  labels.contains(where: { line.compare($0, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame })
            else { continue }
            return center
        }
        return nil
    }
}
