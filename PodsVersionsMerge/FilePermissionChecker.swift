//
//  FilePermissionChecker.swift
//  PodsVersionsMerge
//
//  Created by Stan Sidel on 28.12.2023.
//

import Cocoa

protocol FilePermissionCheckerProtocol {
    func checkAndRequestPermission(for url: URL) async -> Bool
}

final class FilePermissionChecker: FilePermissionCheckerProtocol {

    @MainActor
    func checkAndRequestPermission(for url: URL) async -> Bool {
        let fileManager = FileManager.default
        let folderURL = url.deletingLastPathComponent()

        // Check if the application already has write permission
        if fileManager.isWritableFile(atPath: folderURL.path) {
            return true
        } else {
            // Request permission from the user
            let openPanel = NSOpenPanel()
            openPanel.message = "Please grant access to the folder to save the file."
            openPanel.prompt = "Grant Access"
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.canCreateDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.directoryURL = folderURL

            if openPanel.runModal() == .OK {
                // Check if the user granted access to the correct folder
                return openPanel.urls.first?.path == folderURL.path
            } else {
                // User denied or did not grant access
                return false
            }
        }
    }
}
