import SwiftUI
import UniformTypeIdentifiers

/// An .xlsx file handed to the system "Save to Files" dialog.
struct XlsxDocument: FileDocument {
    static let contentType: UTType = UTType("org.openxmlformats.spreadsheetml.sheet")
        ?? UTType(filenameExtension: "xlsx", conformingTo: .data)
        ?? .data

    static var readableContentTypes: [UTType] { [contentType] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
