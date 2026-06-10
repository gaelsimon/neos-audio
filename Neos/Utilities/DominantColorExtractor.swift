import SwiftUI
import AppKit

/// Extracts dominant colors from album artwork for ambient background gradients.
/// Uses CGImage pixel sampling on a downscaled grid; no third-party deps, no CIFilter.
enum DominantColorExtractor {

    struct RGB: Hashable {
        let r: UInt8, g: UInt8, b: UInt8

        var brightness: Double {
            (Double(r) * 0.299 + Double(g) * 0.587 + Double(b) * 0.114) / 255.0
        }

        var saturation: Double {
            let rf = Double(r) / 255.0
            let gf = Double(g) / 255.0
            let bf = Double(b) / 255.0
            let maxC = max(rf, gf, bf)
            let minC = min(rf, gf, bf)
            guard maxC > 0 else { return 0 }
            return (maxC - minC) / maxC
        }
    }

    /// Extract 2-3 dominant colors from an NSImage for ambient background use.
    /// Runs on a utility thread; safe to call from .task { }.
    /// Returns colors darkened for background use (multiplied by 0.7).
    static func extractColors(from image: NSImage, count: Int = 3) async -> [Color] {
        await Task.detached(priority: .utility) {
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return defaultColors
            }

            // Downscale to 40x40 for fast sampling
            let sampleSize = 40
            let bytesPerRow = sampleSize * 4
            guard let context = CGContext(
                data: nil,
                width: sampleSize,
                height: sampleSize,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return defaultColors
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

            guard let data = context.data else {
                return defaultColors
            }

            let regionColors = sampleGridColors(from: data, bytesPerRow: bytesPerRow, sampleSize: sampleSize)
            guard !regionColors.isEmpty else { return defaultColors }

            return selectAndTone(regionColors, count: count)
        }.value
    }

    /// Divide the downscaled image into a 4x4 grid and average each cell's pixel colors.
    /// Filters out near-black and near-white regions.
    private static func sampleGridColors(from data: UnsafeMutableRawPointer, bytesPerRow: Int, sampleSize: Int) -> [RGB] {
        let pointer = data.bindMemory(to: UInt8.self, capacity: sampleSize * sampleSize * 4)
        let gridSize = 4
        let cellSize = sampleSize / gridSize
        var regionColors: [RGB] = []

        for gy in 0..<gridSize {
            for gx in 0..<gridSize {
                var rSum = 0, gSum = 0, bSum = 0, pixelCount = 0
                for y in (gy * cellSize)..<((gy + 1) * cellSize) {
                    for x in (gx * cellSize)..<((gx + 1) * cellSize) {
                        let offset = (y * sampleSize + x) * 4
                        rSum += Int(pointer[offset])
                        gSum += Int(pointer[offset + 1])
                        bSum += Int(pointer[offset + 2])
                        pixelCount += 1
                    }
                }
                let rgb = RGB(
                    r: UInt8(rSum / pixelCount),
                    g: UInt8(gSum / pixelCount),
                    b: UInt8(bSum / pixelCount)
                )
                // Filter out near-black and near-white
                if rgb.brightness > 0.08 && rgb.brightness < 0.92 {
                    regionColors.append(rgb)
                }
            }
        }

        return regionColors
    }

    /// Sort by saturation, deduplicate similar colors, and apply pastel tone mapping
    /// for soft, muted background use.
    private static func selectAndTone(_ regionColors: [RGB], count: Int) -> [Color] {
        // Sort by saturation (most vibrant first)
        let sorted = regionColors.sorted { $0.saturation > $1.saturation }

        // Deduplicate: skip colors too similar to already-selected ones
        var selected: [RGB] = []
        for rgb in sorted {
            let isDuplicate = selected.contains { existing in
                abs(Int(existing.r) - Int(rgb.r)) < 40 &&
                abs(Int(existing.g) - Int(rgb.g)) < 40 &&
                abs(Int(existing.b) - Int(rgb.b)) < 40
            }
            if !isDuplicate {
                selected.append(rgb)
                if selected.count >= count { break }
            }
        }

        // Pastel tone: desaturate and darken for a soft, muted background
        return selected.map { rgb in
            let r = Double(rgb.r) / 255.0
            let g = Double(rgb.g) / 255.0
            let b = Double(rgb.b) / 255.0
            // Blend toward mid-gray to desaturate, then darken
            let desaturation = 0.45 // 0 = original, 1 = fully gray
            let gray = (r + g + b) / 3.0
            let pr = (r * (1 - desaturation) + gray * desaturation) * 0.55
            let pg = (g * (1 - desaturation) + gray * desaturation) * 0.55
            let pb = (b * (1 - desaturation) + gray * desaturation) * 0.55
            return Color(red: pr, green: pg, blue: pb)
        }
    }

    static var defaultColors: [Color] {
        [Color(white: 0.04), Color(white: 0.075), Color(white: 0.06)]
    }
}
