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
                name: "Take a moment",
                steps: ["Close your eyes", "Take a deep breath", "Relax your shoulders"],
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
                name: "20-20-20 Rule",
                steps: [
                    "Find an object 20 feet away",
                    "Focus on it for 20 seconds",
                    "Blink naturally"
                ],
                symbolName: "eye"
            ),
            HealthTip(
                name: "Eye Rolling",
                steps: [
                    "Close your eyes gently",
                    "Roll eyes clockwise 5 times",
                    "Roll counter-clockwise 5 times",
                    "Open and blink"
                ],
                symbolName: "arrow.clockwise"
            ),
            HealthTip(
                name: "Palming",
                steps: [
                    "Rub your hands together",
                    "Close your eyes",
                    "Place warm palms over eyes",
                    "Relax for 10 seconds"
                ],
                symbolName: "hands.clap"
            ),
            HealthTip(
                name: "Near-Far Focus",
                steps: [
                    "Hold thumb 10 inches away",
                    "Focus on it for 5 seconds",
                    "Look at distant object for 5 seconds",
                    "Repeat 5 times"
                ],
                symbolName: "arrow.left.and.right"
            ),

            // Neck & Shoulder
            HealthTip(
                name: "Neck Rolls",
                steps: [
                    "Sit up straight",
                    "Lower chin to chest",
                    "Roll head to the right",
                    "Roll to center, then left"
                ],
                symbolName: "figure.walk"
            ),
            HealthTip(
                name: "Shoulder Shrugs",
                steps: [
                    "Raise shoulders toward ears",
                    "Hold for 3 seconds",
                    "Release and let drop",
                    "Repeat 5 times"
                ],
                symbolName: "figure.strengthtraining.traditional"
            ),

            // Breathing
            HealthTip(
                name: "Box Breathing",
                steps: [
                    "Inhale for 4 seconds",
                    "Hold for 4 seconds",
                    "Exhale for 4 seconds",
                    "Hold for 4 seconds"
                ],
                symbolName: "rectangle"
            ),
            HealthTip(
                name: "Deep Belly Breathing",
                steps: [
                    "Place hand on belly",
                    "Inhale deeply through nose",
                    "Feel belly rise",
                    "Exhale slowly through mouth"
                ],
                symbolName: "wind"
            ),

            // Posture
            HealthTip(
                name: "Shoulder Blade Squeeze",
                steps: [
                    "Sit or stand tall",
                    "Squeeze shoulder blades together",
                    "Hold for 5 seconds",
                    "Release and repeat 5 times"
                ],
                symbolName: "figure.stand"
            ),
            HealthTip(
                name: "Chin Tucks",
                steps: [
                    "Look straight ahead",
                    "Pull chin straight back",
                    "Hold for 3 seconds",
                    "Release and repeat 10 times"
                ],
                symbolName: "figure.seated.side.air.lowering.one.hand.arm"
            ),

            // Hand & Wrist
            HealthTip(
                name: "Wrist Circles",
                steps: [
                    "Extend arm forward",
                    "Rotate wrist clockwise 10 times",
                    "Rotate counter-clockwise 10 times",
                    "Repeat with other hand"
                ],
                symbolName: "hand.raised"
            ),
            HealthTip(
                name: "Finger Stretches",
                steps: [
                    "Extend arm with palm up",
                    "Pull fingers back gently",
                    "Hold for 10 seconds",
                    "Repeat with palm down"
                ],
                symbolName: "hand.point.up"
            )
        ]
    }
}