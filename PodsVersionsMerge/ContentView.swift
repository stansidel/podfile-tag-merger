//
//  ContentView.swift
//  PodsVersionsMerge
//
//  Created by Stan Sidel on 28.12.2023.
//

import SwiftUI

// Content view with two fields for selecting files. The first field is named "Source Podfile", the second one is named "Target Podfile". Both fields are required.
// Both fields allow to select files named "Podfile" without an extension. When a file is selected, it's store in the corresponding @State variable.
// Under the fields there's a button "Merge" that runs a merge command with the selected files as parameters.

struct ContentView: View {
    @State private var sourcePodfile: URL?
    @State private var targetPodfile: URL?
    @State private var output: String = ""
    @State private var error: String = ""
    @State private var isRunning: Bool = false

    private let versionMerger: VersionMergerProtocol

    init(
        versionMerger: VersionMergerProtocol = VersionMerger(
            filePermissionChecker: FilePermissionChecker()
        )
    ) {
        self.versionMerger = versionMerger
    }

    var body: some View {
        VStack {
            HStack {
                Text("Source Podfile: \(sourcePodfile?.path ?? "None")")
                Spacer()
                Button("Select") {
                    sourcePodfile = selectFile()
                }
            }
            .padding()
            HStack {
                Text("Target Podfile: \(targetPodfile?.path ?? "None")")
                Spacer()
                Button("Select") {
                    targetPodfile = selectFile()
                }
            }
            .padding()
            Button("Merge") {
                merge()
            }
            .disabled(sourcePodfile == nil || targetPodfile == nil || isRunning)
            .padding()
            Text(output)
                .padding()
            Text(error)
                .foregroundColor(.red)
                .padding()
        }
        .padding()
    }

    private func selectFile() -> URL? {
        let dialog = NSOpenPanel()
        dialog.title = "Choose a Podfile"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false

        if dialog.runModal() == .OK {
            return dialog.url
        } else {
            return nil
        }
    }

    private func merge() {
        guard let sourcePodfile = sourcePodfile, let targetPodfile = targetPodfile else {
            return
        }

        isRunning = true
        output = ""
        error = ""
        Task {
            do {
                try await versionMerger.merge(source: sourcePodfile, target: targetPodfile)
                await MainActor.run {
                    self.output = "Updated"
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
            await MainActor.run {
                isRunning = false
            }
        }
    }
}

#Preview {
    ContentView()
}
