//
//  VersionMerger.swift
//  PodsVersionsMerge
//
//  Created by Stan Sidel on 28.12.2023.
//

import Foundation

protocol VersionMergerProtocol {
    func merge(source: URL, target: URL) async throws
}

final class VersionMerger: VersionMergerProtocol {

    private let fileManager: FileManager
    private let filePermissionChecker: FilePermissionCheckerProtocol

    init(fileManager: FileManager = .default, filePermissionChecker: FilePermissionCheckerProtocol) {
        self.fileManager = fileManager
        self.filePermissionChecker = filePermissionChecker
    }

    func merge(source: URL, target: URL) async throws {
        guard await filePermissionChecker.checkAndRequestPermission(for: target) else {
            throw NSError(
                domain: "Permission Error",
                code: 0,
                userInfo: [
                    NSLocalizedDescriptionKey: "Permission to write to the folder was denied."
                ]
            )
        }

        let sourcePodfileTags = try await parsePodfileTags(source)
        try await merge(tags: sourcePodfileTags, to: target)
    }

    // MARK: - Private

    private let podLineRegex = "pod [\"']([^'\"]+)[\"'],.*(?:\\:tag\\s*=>\\s*|tag\\:\\s*)[\"']([^\"']+)[\"'].*"

    // Reads the contents of the file at the given URL and returns a dictionary with keys being pod names and values being their tags.
    // The input file contains strings in the following formats:
    // pod 'Alamofire', :git => 'https://alam', tag: '5.2.2', spec: "34"
    // pod 'Alamofire', :git => 'https://alam', :tag => "5.2.3"
    private func parsePodfileTags(_ url: URL) async throws -> [String: String] {
        // Read the file at the given URL line by line.
        // For each line, extract the pod name and the tag.
        // Store the pod name and the tag in the dictionary.
        // If the pod name already exists in the dictionary, compare the tags and store the larger one.
        // Return the dictionary.

        var result: [String: String] = [:]
        let contents = try! String(contentsOf: url)
        // Make a regex from regexString
        let regex = try! NSRegularExpression(pattern: podLineRegex)
        contents.enumerateLines { line, _ in
            // Get podName and tag from the string by matching it against the regexString.
            // The first and second match groups would be podName and tag respectively.
            let results = regex.matches(in: line, options: [], range: NSRange(line.startIndex..., in: line))

            // Check if we have at least one match and each match has at least three ranges
            // (full match, podName, and tag)
            if let match = results.first, match.numberOfRanges >= 3 {
                let podNameRange = match.range(at: 1)
                let tagRange = match.range(at: 2)

                // Convert NSRange to Range
                if let podNameRange = Range(podNameRange, in: line),
                    let tagRange = Range(tagRange, in: line)
                {
                    let podName = String(line[podNameRange])
                    let tag = String(line[tagRange])

                    result[podName] = tag
                }
            }
        }
        return result
    }

    private func merge(tags: [String: String], to url: URL) async throws {
        let regex = try NSRegularExpression(pattern: podLineRegex)

        // Create a temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tempURL)
        try FileManager.default.copyItem(at: url, to: tempURL)

        defer {
            // Remove the temp file
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Read and process each line
        let fileContent = try String(contentsOf: tempURL)
        let lines = fileContent.components(separatedBy: .newlines)
        var updatedLines = [String]()

        for line in lines {
            let range = NSRange(location: 0, length: line.utf16.count)
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                let podNameRange = Range(match.range(at: 1), in: line)!
                let tagRange = Range(match.range(at: 2), in: line)!
                let podName = String(line[podNameRange])
                let currentTag = String(line[tagRange])

                if let newTag = tags[podName], shouldUpdate(tag: currentTag, with: newTag) {
                    let newLine = line.replacingOccurrences(of: currentTag, with: newTag, range: tagRange)
                    updatedLines.append(newLine)
                } else {
                    updatedLines.append(line)
                }
            } else {
                updatedLines.append(line)
            }
        }

        // Write the updated content to the temp file
        let updatedContent = updatedLines.joined(separator: "\n")
        
        try updatedContent.write(to: tempURL, atomically: true, encoding: .utf8)

        // Replace the original file with the updated temp file
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
    }

    private func shouldUpdate(tag currentTag: String, with newTag: String) -> Bool {
        func parseVersion(_ version: String) -> [Int] {
            return version.split(separator: ".").compactMap { Int($0) }
        }
        
        let currentVersion = parseVersion(currentTag)
        let newVersion = parseVersion(newTag)

        for (current, new) in zip(currentVersion, newVersion) {
            if new > current {
                return true
            } else if new < current {
                return false
            }
        }

        return newVersion.count > currentVersion.count
    }
}
