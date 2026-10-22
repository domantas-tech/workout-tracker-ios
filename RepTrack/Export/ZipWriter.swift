import Foundation

/// Minimal ZIP archive writer (uncompressed "stored" entries). iOS has no public zip API, and an
/// .xlsx workbook is just a zip of small XML files, so this is all the export needs.
struct ZipWriter {

    private struct Entry {
        let name: Data
        let crc: UInt32
        let size: UInt32
        let offset: UInt32
    }

    private var output = Data()
    private var entries: [Entry] = []

    /// Adds a file. Entries are written in the order they are added.
    mutating func addFile(path: String, contents: Data) {
        let name = Data(path.utf8)
        let crc = CRC32.checksum(contents)
        let entry = Entry(name: name, crc: crc, size: UInt32(contents.count), offset: UInt32(output.count))

        // Local file header
        output.appendUInt32(0x0403_4B50)
        output.appendUInt16(20) // version needed to extract (2.0)
        output.appendUInt16(0x0800) // flags: names are UTF-8
        output.appendUInt16(0) // method: stored
        output.appendUInt16(ZipWriter.dosTime)
        output.appendUInt16(ZipWriter.dosDate)
        output.appendUInt32(crc)
        output.appendUInt32(entry.size) // compressed size
        output.appendUInt32(entry.size) // uncompressed size
        output.appendUInt16(UInt16(name.count))
        output.appendUInt16(0) // extra field length
        output.append(name)
        output.append(contents)

        entries.append(entry)
    }

    /// The finished archive: entries, central directory and end record.
    func finish() -> Data {
        var archive = output
        let directoryOffset = UInt32(archive.count)
        for entry in entries {
            archive.appendUInt32(0x0201_4B50)
            archive.appendUInt16(20) // version made by
            archive.appendUInt16(20) // version needed
            archive.appendUInt16(0x0800)
            archive.appendUInt16(0)
            archive.appendUInt16(ZipWriter.dosTime)
            archive.appendUInt16(ZipWriter.dosDate)
            archive.appendUInt32(entry.crc)
            archive.appendUInt32(entry.size)
            archive.appendUInt32(entry.size)
            archive.appendUInt16(UInt16(entry.name.count))
            archive.appendUInt16(0) // extra
            archive.appendUInt16(0) // comment
            archive.appendUInt16(0) // disk number
            archive.appendUInt16(0) // internal attributes
            archive.appendUInt32(0) // external attributes
            archive.appendUInt32(entry.offset)
            archive.append(entry.name)
        }
        let directorySize = UInt32(archive.count) - directoryOffset
        archive.appendUInt32(0x0605_4B50)
        archive.appendUInt16(0) // this disk
        archive.appendUInt16(0) // disk with directory
        archive.appendUInt16(UInt16(entries.count))
        archive.appendUInt16(UInt16(entries.count))
        archive.appendUInt32(directorySize)
        archive.appendUInt32(directoryOffset)
        archive.appendUInt16(0) // comment length
        return archive
    }

    // 1 Jan 2026, 00:00 — a fixed timestamp keeps the output reproducible
    private static let dosTime: UInt16 = 0
    private static let dosDate: UInt16 = UInt16(((2026 - 1980) << 9) | (1 << 5) | 1)
}

/// CRC-32 (IEEE 802.3), as required by the ZIP format.
enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1
        }
        return c
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8(value >> 8))
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8(value >> 24))
    }
}
