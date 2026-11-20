/// The phone's own volume, from 0 to 1, which its buttons move.
@MainActor
protocol SystemVolume: AnyObject {
    func setLevel(_ level: Float)
    /// Reports the level and the output it plays on once known, then at each change, until the returned closure is called.
    func observe(_ report: @escaping @MainActor (_ level: Float, _ output: String) -> Void) -> () -> Void
}

/// While started, each press of the phone's volume buttons is reported and the phone's volume put back where it was.
@MainActor
final class VolumeButtons {
    /// The buttons move the phone's volume a sixteenth at a time; iOS reports it rounded to a twentieth, which still
    /// tells every sixteenth apart.
    static let notches = 16
    /// A report spans a press, two when they come fast; more is a misread level, which must not jump the speaker.
    static let maxPressesPerReport = 2

    private let system: any SystemVolume
    private var onPress: ((Int) -> Void)?
    private var stopObserving: (() -> Void)?
    private var original: Float?
    private var held: Int?
    private var last: Int?
    private var output: String?
    private var hasMoved = false
    private var generation = 0

    init(system: any SystemVolume) {
        self.system = system
    }

    /// `onPress` gets the presses since the last report, negative for volume down.
    func start(onPress: @escaping (Int) -> Void) {
        guard stopObserving == nil else { return }
        self.onPress = onPress
        let generation = generation
        stopObserving = system.observe { [weak self] level, output in
            // A report can land after stop(), already queued on the main actor.
            guard let self, self.generation == generation else { return }
            handle(level, on: output)
        }
    }

    func stop() {
        guard let stopObserving else { return }
        if hasMoved, let original {
            system.setLevel(original)
        }
        stopObserving()
        self.stopObserving = nil
        original = nil
        held = nil
        last = nil
        output = nil
        hasMoved = false
        generation += 1
    }

    static func notch(of level: Float) -> Int {
        Int((level * Float(notches)).rounded())
    }

    /// A notch away from either end, where pressing towards it would change nothing and go unseen.
    static func heldNotch(for notch: Int) -> Int {
        min(max(notch, 1), notches - 1)
    }

    private func handle(_ level: Float, on output: String) {
        let notch = Self.notch(of: level)
        guard let held, let last, output == self.output else {
            hold(level, at: notch, on: output)
            return
        }
        self.last = notch
        // The phone coming back to the held notch is the reset below, not a press.
        guard notch != held else { return }
        if notch != last {
            onPress?(min(max(notch - last, -Self.maxPressesPerReport), Self.maxPressesPerReport))
        }
        put(held)
    }

    private func hold(_ level: Float, at notch: Int, on output: String) {
        let held = Self.heldNotch(for: notch)
        original = level
        self.output = output
        self.held = held
        last = held
        if held != notch {
            put(held)
        }
    }

    private func put(_ notch: Int) {
        hasMoved = true
        system.setLevel(Float(notch) / Float(Self.notches))
    }
}
