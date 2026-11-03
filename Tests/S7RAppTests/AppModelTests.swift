import Foundation
import Testing
import S7RCore
@testable import S7RApp

@Test @MainActor func refreshReloadsFoldersAndRemovesStaleRows() throws {
    let root = URL(fileURLWithPath: "/tmp/s7r-refresh-\(UUID().uuidString)").standardizedFileURL
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root.appendingPathComponent("nested"), withIntermediateDirectories: true)
    let first = root.appendingPathComponent("first.wav")
    let second = root.appendingPathComponent("second.mp4")
    let nested = root.appendingPathComponent("nested/third.wav")
    try Data([1]).write(to: first)
    try Data([2]).write(to: nested)
    let model = AppModel()
    model.add([root, first])
    #expect(model.inputs == [first])
    #expect(model.inputFolders.map(\.path) == [root.path])
    model.events[first.path] = ProgressEvent(first.path, .succeeded, 1)
    model.results[first.path] = JobResult(input: first.path, state: .succeeded)
    model.selection = first.path; model.preview = "old preview"
    model.refreshInputs()
    #expect(model.results[first.path]?.state == .succeeded)
    #expect(model.selection == first.path && model.preview == "old preview")
    try FileManager.default.removeItem(at: first)
    try Data([3]).write(to: second)
    model.refreshInputs()
    #expect(model.inputs == [second])
    #expect(model.events.isEmpty && model.results.isEmpty)
    #expect(model.selection == nil && model.preview.isEmpty)
    model.settings.recursive = true
    model.refreshInputs()
    #expect(Set(model.inputs) == Set([second, nested]))
    model.refreshInputs()
    #expect(model.inputs.count == 2)
    model.settings.recursive = false
    model.refreshInputs()
    #expect(model.inputs == [second])
    try FileManager.default.removeItem(at: second)
    model.refreshInputs()
    #expect(model.inputs.isEmpty && model.message.isEmpty)
    try FileManager.default.removeItem(at: root)
    model.refreshInputs()
    #expect(model.inputs.isEmpty && model.message.isEmpty)
}

@Test @MainActor func individualFilesUseTheirParentFoldersForRefresh() throws {
    let root = URL(fileURLWithPath: "/tmp/s7r-parent-\(UUID().uuidString)").standardizedFileURL
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let first = root.appendingPathComponent("first.wav")
    let second = root.appendingPathComponent("second.wav")
    try Data([1]).write(to: first)
    let model = AppModel()
    model.add([first, first])
    try Data([2]).write(to: second)
    model.running = true
    model.refreshInputs()
    #expect(model.inputs == [first])
    model.running = false
    model.refreshInputs()
    #expect(model.inputs == [first, second])
    model.clearInputs()
    model.refreshInputs()
    #expect(model.inputs.isEmpty && model.inputFolders.isEmpty)
}

@Test @MainActor func emptyFolderCanBeRefreshedAfterAddingFiles() throws {
    let root = URL(fileURLWithPath: "/tmp/s7r-empty-\(UUID().uuidString)").standardizedFileURL
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let model = AppModel()
    model.add([root])
    #expect(model.inputs.isEmpty && model.inputFolders.map(\.path) == [root.path])
    let file = root.appendingPathComponent("new.wav")
    try Data([1]).write(to: file)
    model.refreshInputs()
    #expect(model.inputs == [file])
}

@Test @MainActor func outputModeRetainsCustomFolderAndFollowsSelection() throws {
    let model = AppModel()
    #expect(model.saveBesideInput && model.outputFolder == nil)
    let first = URL(fileURLWithPath: "/private/tmp/first/sample.mp4")
    let second = URL(fileURLWithPath: "/private/tmp/second/sample.mp4")
    model.inputs = [first, second]
    #expect(model.outputFolder == first.deletingLastPathComponent())
    model.selection = second.path
    #expect(model.outputFolder == second.deletingLastPathComponent())
    model.saveBesideInput = false
    #expect(!model.settings.outputDirectory.isEmpty)
    model.settings.outputDirectory = "/private/tmp/custom-output"
    #expect(model.outputFolder?.path == "/private/tmp/custom-output")
    model.saveBesideInput = true
    #expect(model.settings.outputDirectory.isEmpty)
    model.saveBesideInput = false
    #expect(model.settings.outputDirectory == "/private/tmp/custom-output")
    let restored = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(model.settings))
    model.settings = restored
    #expect(!model.saveBesideInput)
}
