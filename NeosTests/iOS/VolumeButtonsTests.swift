import Testing
@testable import Neos

@MainActor
private final class FakeSystemVolume: SystemVolume {
    private(set) var level: Float
    private(set) var setLevels: [Float] = []
    private(set) var isObserved = false
    private var report: (@MainActor (Float) -> Void)?

    init(level: Float) {
        self.level = level
    }

    func setLevel(_ level: Float) {
        setLevels.append(level)
        self.level = level
    }

    func observe(_ report: @escaping @MainActor (Float) -> Void) -> () -> Void {
        isObserved = true
        self.report = report
        return { [weak self] in
            self?.isObserved = false
            self?.report = nil
        }
    }

    /// The level as iOS reports it: rounded to a twentieth.
    func report(_ level: Float) {
        self.level = level
        report?((level * 20).rounded() / 20)
    }
}

@MainActor
struct VolumeButtonsTests {
    private static let notch = 1 / Float(VolumeButtons.notches)

    /// Holds the buttons too, which the fake only references weakly through its report.
    @MainActor
    private final class Rig {
        let system: FakeSystemVolume
        var presses: [Int] = []
        private let buttons: VolumeButtons

        init(level: Float, reportsLevel: Bool = true) {
            system = FakeSystemVolume(level: level)
            buttons = VolumeButtons(system: system)
            buttons.start { [unowned self] in presses.append($0) }
            if reportsLevel {
                system.report(level)
            }
        }

        func press(_ notches: Int) {
            system.report(system.level + Float(notches) * notch)
        }

        func stop() {
            buttons.stop()
        }

        func start(onPress: @escaping (Int) -> Void) {
            buttons.start(onPress: onPress)
        }
    }

    private static let seven: Float = 7 * notch

    @Test func aPressUpIsReported() {
        let rig = Rig(level: Self.seven)

        rig.press(1)

        #expect(rig.presses == [1])
    }

    @Test func aPressDownIsReported() {
        let rig = Rig(level: Self.seven)

        rig.press(-1)

        #expect(rig.presses == [-1])
    }

    @Test func thePhoneIsPutBackAfterAPress() {
        let rig = Rig(level: Self.seven)

        rig.press(1)

        #expect(rig.system.level == Self.seven)
    }

    @Test func theResetEchoingBackIsNoPress() {
        let rig = Rig(level: Self.seven)

        rig.press(1)
        rig.system.report(Self.seven)

        #expect(rig.presses == [1])
    }

    @Test func aPressLandingBeforeTheResetCountsOnce() {
        let rig = Rig(level: Self.seven)

        rig.press(1)
        rig.system.report(Self.seven + 2 * Self.notch)

        #expect(rig.presses == [1, 1])
    }

    @Test func twoPressesInOneReportCountTwice() {
        let rig = Rig(level: Self.seven)

        rig.press(2)

        #expect(rig.presses == [2])
    }

    @Test func aMisreadLevelMovesTheSpeakerTwoPressesAtMost() {
        let rig = Rig(level: Self.seven)

        rig.press(6)

        #expect(rig.presses == [VolumeButtons.maxPressesPerReport])
    }

    @Test func theFirstReportIsTheLevelNotAPress() {
        let rig = Rig(level: Self.seven, reportsLevel: false)

        rig.system.report(0.5)

        #expect(rig.presses.isEmpty)
    }

    @Test func aPhoneAtFullVolumeIsHeldANotchBelow() {
        let rig = Rig(level: 1)

        #expect(rig.system.setLevels == [1 - Self.notch])
    }

    @Test func aSilentPhoneIsHeldANotchAbove() {
        let rig = Rig(level: 0)

        #expect(rig.system.setLevels == [Self.notch])
    }

    @Test func aPhoneBetweenTheEndsKeepsItsVolume() {
        let rig = Rig(level: 0.45)

        #expect(rig.system.setLevels.isEmpty)
    }

    @Test func stoppingGivesThePhoneItsVolumeBack() {
        let rig = Rig(level: 1)

        rig.stop()

        #expect(rig.system.level == 1)
    }

    @Test func stoppingAfterAPressGivesThePhoneItsExactVolumeBack() {
        let rig = Rig(level: 0.45)
        rig.press(1)

        rig.stop()

        #expect(rig.system.level == 0.45)
    }

    @Test func stoppingWithoutAPressLeavesThePhoneAlone() {
        let rig = Rig(level: 0.45)

        rig.stop()

        #expect(rig.system.setLevels.isEmpty)
    }

    @Test func stoppingEndsTheReports() {
        let rig = Rig(level: Self.seven)

        rig.stop()
        rig.press(1)

        #expect(!rig.system.isObserved)
        #expect(rig.presses.isEmpty)
    }

    @Test func startingTwiceKeepsTheFirstStart() {
        let rig = Rig(level: Self.seven)
        var second: [Int] = []

        rig.start { second.append($0) }
        rig.press(1)

        #expect(rig.presses == [1])
        #expect(second.isEmpty)
    }

    @Test func stoppingWithoutAStartChangesNothing() {
        let system = FakeSystemVolume(level: 0)

        VolumeButtons(system: system).stop()

        #expect(system.setLevels.isEmpty)
    }

    @Test(arguments: 0...VolumeButtons.notches)
    func aRoundedReportStillGivesItsNotch(notch: Int) {
        let rounded = (Float(notch) * Self.notch * 20).rounded() / 20

        #expect(VolumeButtons.notch(of: rounded) == notch)
    }
}

@MainActor
struct PhoneVolumeTests {
    @Test func observingCanBeStoppedBeforeTheLevelIsKnown() {
        let volume = PhoneVolume()
        var reports = 0

        let stop = volume.observe { _ in reports += 1 }
        stop()

        #expect(reports == 0)
    }

    @Test func theLevelIsReportedOnceKnown() async {
        let volume = PhoneVolume()
        var reports: [Float] = []

        let stop = volume.observe { reports.append($0) }
        for _ in 0..<40 where reports.isEmpty {
            try? await Task.sleep(for: .milliseconds(50))
        }
        volume.setLevel(reports.first ?? 0)
        stop()

        #expect(reports.count == 1)
        #expect(reports.allSatisfy { (0...1).contains($0) })
    }
}
