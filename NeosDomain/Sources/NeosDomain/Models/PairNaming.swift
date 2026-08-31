import Foundation

// A configured pair reports its leader's name, so the room name comes from what members share.

let channelSuffixWords: Set<String> = ["left", "right", "l", "r"]
private let nameSeparators: Set<Character> = ["-", "–", "—", "_", "+", "/", ","]

public extension SpeakerGroup {
    /// Room name for a collapsed pair; the group's own name when it is already meaningful.
    var collapsedDisplayName: String {
        let groupName = name.trimmingCharacters(in: .whitespaces)
        let leaderName = leader?.name.trimmingCharacters(in: .whitespaces) ?? ""
        guard groupName.isEmpty || groupName == leaderName else { return groupName }

        let shared = sharedLeadingWords(of: players.map(\.name))
        if !shared.isEmpty, shared != leaderName { return shared }

        let stripped = strippingChannelSuffix(leaderName)
        if !stripped.isEmpty { return stripped }

        return groupName.isEmpty ? leaderName : groupName
    }
}

/// Leading words every name shares: "Kitchen Left" + "Kitchen Right" → "Kitchen".
func sharedLeadingWords(of names: [String]) -> String {
    let wordLists = names.map(nameWords)
    guard let reference = wordLists.first, !reference.isEmpty, wordLists.count > 1 else { return "" }

    var shared: [String] = []
    for (index, word) in reference.enumerated() {
        let matchesEverywhere = wordLists.allSatisfy { list in
            index < list.count && list[index].caseInsensitiveCompare(word) == .orderedSame
        }
        guard matchesEverywhere else { break }
        shared.append(word)
    }
    return shared.joined(separator: " ")
}

/// Drops a trailing channel word: "Kitchen Left" → "Kitchen".
func strippingChannelSuffix(_ name: String) -> String {
    var words = nameWords(name)
    guard words.count > 1, let last = words.last,
          channelSuffixWords.contains(last.lowercased()) else {
        return name.trimmingCharacters(in: .whitespaces)
    }
    words.removeLast()
    return words.joined(separator: " ")
}

private func nameWords(_ name: String) -> [String] {
    name.split { $0.isWhitespace || nameSeparators.contains($0) }.map(String.init)
}
