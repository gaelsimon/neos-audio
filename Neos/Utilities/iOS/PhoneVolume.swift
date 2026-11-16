import AVFAudio
import MediaPlayer
import UIKit

/// The phone's volume through a volume view kept off screen in the window, which also keeps iOS from showing its own indicator.
@MainActor
final class PhoneVolume: SystemVolume {
    private lazy var volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))

    private var slider: UISlider? {
        volumeView.subviews.lazy.compactMap { $0 as? UISlider }.first
    }

    /// From iOS 18 the session's figure can stay stale after a trip to the background; the slider follows the phone
    /// once it has heard from the system.
    private var level: Float {
        let sliderLevel = slider?.value ?? 0
        return sliderLevel > 0 ? sliderLevel : AVAudioSession.sharedInstance().outputVolume
    }

    func setLevel(_ level: Float) {
        slider?.setValue(level, animated: false)
    }

    func observe(_ report: @escaping @MainActor (_ level: Float, _ output: String) -> Void) -> () -> Void {
        let session = AVAudioSession.sharedInstance()
        // Mixes with whatever else plays; while it is active the buttons move the media volume, not the ringer's.
        try? session.setCategory(.playback, options: .mixWithOthers)
        try? session.setActive(true)
        Self.keyWindow?.addSubview(volumeView)
        var observation: NSKeyValueObservation?
        let start = Task { [weak self] in
            await self?.waitForTheSlider()
            guard !Task.isCancelled, let self else { return }
            report(level, Self.output)
            observation = Self.observeLevel(of: session, report: report)
        }
        return { [volumeView] in
            start.cancel()
            observation?.invalidate()
            volumeView.removeFromSuperview()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private static func observeLevel(
        of session: AVAudioSession, report: @escaping @MainActor (Float, String) -> Void
    ) -> NSKeyValueObservation {
        session.observe(\.outputVolume, options: .new) { _, change in
            guard let level = change.newValue else { return }
            let output = Self.output
            Task { @MainActor in report(level, output) }
        }
    }

    /// The slider reads 0 until it has heard from the system, a few hundredths of a second after joining the window.
    private func waitForTheSlider() async {
        for _ in 0..<10 where (slider?.value ?? 0) == 0 {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Each output keeps its own volume, so plugging in headphones changes the level without a press.
    nonisolated private static var output: String {
        AVAudioSession.sharedInstance().currentRoute.outputs.map(\.uid).joined(separator: ",")
    }

    private static var keyWindow: UIWindow? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first
    }
}
