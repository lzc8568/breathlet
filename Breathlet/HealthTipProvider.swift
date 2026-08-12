import Foundation

@MainActor
final class HealthTipProvider {
    static let shared = HealthTipProvider()

    private var currentIndex: Int = 0
    private var tips: [HealthTip] = []

    private init() {
        loadTips()
    }

    func getNextTip() -> HealthTip {
        guard !tips.isEmpty else {
            return HealthTip(
                name: NSLocalizedString("Take a moment", comment: ""),
                steps: [
                    NSLocalizedString("Close your eyes", comment: ""),
                    NSLocalizedString("Take a deep breath", comment: ""),
                    NSLocalizedString("Relax your shoulders", comment: "")
                ],
                symbolName: "figure.mind.and.body"
            )
        }

        let tip = tips[currentIndex]
        currentIndex = (currentIndex + 1) % tips.count
        return tip
    }

    private func loadTips() {
        tips = [
            // Eye Exercises
            HealthTip(
                name: NSLocalizedString("20-20-20 Rule", comment: ""),
                steps: [
                    NSLocalizedString("Find an object 20 feet away", comment: ""),
                    NSLocalizedString("Focus on it for 20 seconds", comment: ""),
                    NSLocalizedString("Blink naturally", comment: "")
                ],
                symbolName: "eye"
            ),
            HealthTip(
                name: NSLocalizedString("Eye Rolling", comment: ""),
                steps: [
                    NSLocalizedString("Close your eyes gently", comment: ""),
                    NSLocalizedString("Roll eyes clockwise 5 times", comment: ""),
                    NSLocalizedString("Roll counter-clockwise 5 times", comment: ""),
                    NSLocalizedString("Open and blink", comment: "")
                ],
                symbolName: "arrow.clockwise"
            ),
            HealthTip(
                name: NSLocalizedString("Palming", comment: ""),
                steps: [
                    NSLocalizedString("Rub your hands together", comment: ""),
                    NSLocalizedString("Close your eyes", comment: ""),
                    NSLocalizedString("Place warm palms over eyes", comment: ""),
                    NSLocalizedString("Relax for 10 seconds", comment: "")
                ],
                symbolName: "hands.clap"
            ),
            HealthTip(
                name: NSLocalizedString("Near-Far Focus", comment: ""),
                steps: [
                    NSLocalizedString("Hold thumb 10 inches away", comment: ""),
                    NSLocalizedString("Focus on it for 5 seconds", comment: ""),
                    NSLocalizedString("Look at distant object for 5 seconds", comment: ""),
                    NSLocalizedString("Repeat 5 times", comment: "")
                ],
                symbolName: "arrow.left.and.right"
            ),

            // Neck & Shoulder
            HealthTip(
                name: NSLocalizedString("Neck Rolls", comment: ""),
                steps: [
                    NSLocalizedString("Sit up straight", comment: ""),
                    NSLocalizedString("Lower chin to chest", comment: ""),
                    NSLocalizedString("Roll head to the right", comment: ""),
                    NSLocalizedString("Roll to center, then left", comment: "")
                ],
                symbolName: "figure.walk"
            ),
            HealthTip(
                name: NSLocalizedString("Shoulder Shrugs", comment: ""),
                steps: [
                    NSLocalizedString("Raise shoulders toward ears", comment: ""),
                    NSLocalizedString("Hold for 3 seconds", comment: ""),
                    NSLocalizedString("Release and let drop", comment: ""),
                    NSLocalizedString("Repeat 5 times", comment: "")
                ],
                symbolName: "figure.strengthtraining.traditional"
            ),

            // Breathing
            HealthTip(
                name: NSLocalizedString("Box Breathing", comment: ""),
                steps: [
                    NSLocalizedString("Inhale for 4 seconds", comment: ""),
                    NSLocalizedString("Hold for 4 seconds", comment: ""),
                    NSLocalizedString("Exhale for 4 seconds", comment: ""),
                    NSLocalizedString("Hold for 4 seconds", comment: "")
                ],
                symbolName: "rectangle"
            ),
            HealthTip(
                name: NSLocalizedString("Deep Belly Breathing", comment: ""),
                steps: [
                    NSLocalizedString("Place hand on belly", comment: ""),
                    NSLocalizedString("Inhale deeply through nose", comment: ""),
                    NSLocalizedString("Feel belly rise", comment: ""),
                    NSLocalizedString("Exhale slowly through mouth", comment: "")
                ],
                symbolName: "wind"
            ),

            // Posture
            HealthTip(
                name: NSLocalizedString("Shoulder Blade Squeeze", comment: ""),
                steps: [
                    NSLocalizedString("Sit or stand tall", comment: ""),
                    NSLocalizedString("Squeeze shoulder blades together", comment: ""),
                    NSLocalizedString("Hold for 5 seconds", comment: ""),
                    NSLocalizedString("Release and repeat 5 times", comment: "")
                ],
                symbolName: "figure.stand"
            ),
            HealthTip(
                name: NSLocalizedString("Chin Tucks", comment: ""),
                steps: [
                    NSLocalizedString("Look straight ahead", comment: ""),
                    NSLocalizedString("Pull chin straight back", comment: ""),
                    NSLocalizedString("Hold for 3 seconds", comment: ""),
                    NSLocalizedString("Release and repeat 10 times", comment: "")
                ],
                symbolName: "figure.seated.side.air.lowering.one.hand.arm"
            ),

            // Hand & Wrist
            HealthTip(
                name: NSLocalizedString("Wrist Circles", comment: ""),
                steps: [
                    NSLocalizedString("Extend arm forward", comment: ""),
                    NSLocalizedString("Rotate wrist clockwise 10 times", comment: ""),
                    NSLocalizedString("Rotate counter-clockwise 10 times", comment: ""),
                    NSLocalizedString("Repeat with other hand", comment: "")
                ],
                symbolName: "hand.raised"
            ),
            HealthTip(
                name: NSLocalizedString("Finger Stretches", comment: ""),
                steps: [
                    NSLocalizedString("Extend arm with palm up", comment: ""),
                    NSLocalizedString("Pull fingers back gently", comment: ""),
                    NSLocalizedString("Hold for 10 seconds", comment: ""),
                    NSLocalizedString("Repeat with palm down", comment: "")
                ],
                symbolName: "hand.point.up"
            )
        ]
    }
}
