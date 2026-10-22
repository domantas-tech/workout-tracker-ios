import Foundation

/// One worksheet. `rows` are written from A1 down; a nil cell is left empty. `columnWidths` are in characters.
struct XlsxSheet: Equatable {
    let name: String
    let rows: [[XlsxCell?]]
    var columnWidths: [Double] = []
}

/// Cell formats. The order must match `cellXfs` in the writer's styles, as cells refer to them by index.
enum XlsxStyle: Int, Equatable {
    case normal = 0
    case title // bold, 14pt
    case header // bold, bottom border
    case integer // #,##0
    case decimal // 0.0
    case total // bold, top border
    case totalInteger // bold, top border, #,##0
}

enum XlsxCell: Equatable {
    case text(String, style: XlsxStyle = .normal)
    case number(Double, style: XlsxStyle = .normal)
    /// `cached` is what viewers that don't recalculate (e.g. file previews) show.
    case formula(String, cached: Double, style: XlsxStyle = .normal)
    /// An empty cell that still carries a format, e.g. to continue a border.
    case blank(style: XlsxStyle)

    var style: XlsxStyle {
        switch self {
        case let .text(_, style), let .number(_, style), let .formula(_, _, style), let .blank(style):
            return style
        }
    }
}

enum XlsxError: Error, Equatable {
    case invalidSheetName(String)
}

/// Minimal .xlsx (Office Open XML) writer for a single sheet — no spreadsheet library needed.
enum XlsxWriter {

    static let mimeType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    /// The workbook containing `sheet`, as .xlsx file bytes.
    static func write(_ sheet: XlsxSheet) throws -> Data {
        let forbidden = CharacterSet(charactersIn: "[]:*?/\\")
        guard (1...31).contains(sheet.name.count), sheet.name.rangeOfCharacter(from: forbidden) == nil else {
            throw XlsxError.invalidSheetName(sheet.name)
        }
        var zip = ZipWriter()
        // Content types first: some readers expect it to be the first entry
        zip.addFile(path: "[Content_Types].xml", contents: Data(contentTypes.utf8))
        zip.addFile(path: "_rels/.rels", contents: Data(rootRels.utf8))
        zip.addFile(path: "xl/workbook.xml", contents: Data(workbookXml(sheetName: sheet.name).utf8))
        zip.addFile(path: "xl/_rels/workbook.xml.rels", contents: Data(workbookRels.utf8))
        zip.addFile(path: "xl/styles.xml", contents: Data(styles.utf8))
        zip.addFile(path: "xl/worksheets/sheet1.xml", contents: Data(sheetXml(sheet).utf8))
        return zip.finish()
    }

    /// 0 -> "A", 25 -> "Z", 26 -> "AA"
    static func columnName(_ index: Int) -> String {
        var n = index + 1
        var letters: [Character] = []
        while n > 0 {
            letters.append(Character(UnicodeScalar(UInt8(65 + (n - 1) % 26))))
            n = (n - 1) / 26
        }
        return String(letters.reversed())
    }

    static func sheetXml(_ sheet: XlsxSheet) -> String {
        var xml = xmlDeclaration
        xml += "<worksheet xmlns=\"\(mainNamespace)\">"
        if !sheet.columnWidths.isEmpty {
            xml += "<cols>"
            for (index, width) in sheet.columnWidths.enumerated() {
                let col = index + 1
                xml += "<col min=\"\(col)\" max=\"\(col)\" width=\"\(width)\" customWidth=\"1\"/>"
            }
            xml += "</cols>"
        }
        xml += "<sheetData>"
        for (rowIndex, cells) in sheet.rows.enumerated() {
            if cells.allSatisfy({ $0 == nil }) { continue }
            let row = rowIndex + 1
            xml += "<row r=\"\(row)\">"
            for (colIndex, cell) in cells.enumerated() {
                if let cell { xml += cellXml(ref: "\(columnName(colIndex))\(row)", cell: cell) }
            }
            xml += "</row>"
        }
        xml += "</sheetData></worksheet>"
        return xml
    }

    private static func cellXml(ref: String, cell: XlsxCell) -> String {
        let style = cell.style.rawValue
        switch cell {
        case let .text(text, _):
            return "<c r=\"\(ref)\" s=\"\(style)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(text))</t></is></c>"
        case let .number(value, _):
            if value.isFinite {
                return "<c r=\"\(ref)\" s=\"\(style)\"><v>\(Format.plainNumber(value))</v></c>"
            }
            return "<c r=\"\(ref)\" s=\"\(style)\"/>"
        case let .formula(formula, cached, _):
            var xml = "<c r=\"\(ref)\" s=\"\(style)\"><f>\(escape(formula))</f>"
            if cached.isFinite { xml += "<v>\(Format.plainNumber(cached))</v>" }
            return xml + "</c>"
        case .blank:
            return "<c r=\"\(ref)\" s=\"\(style)\"/>"
        }
    }

    static func escape(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.utf8.count)
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "\t", "\n", "\r": result.unicodeScalars.append(scalar)
            default:
                // XML 1.0 forbids the other control characters
                if scalar.value >= 0x20 { result.unicodeScalars.append(scalar) }
            }
        }
        return result
    }

    private static func workbookXml(sheetName: String) -> String {
        xmlDeclaration + "<workbook xmlns=\"\(mainNamespace)\" xmlns:r=\"\(relNamespace)\">"
            + "<sheets><sheet name=\"\(escape(sheetName))\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>"
    }

    private static let xmlDeclaration = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
    private static let mainNamespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    private static let relNamespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    private static let packageRelNamespace = "http://schemas.openxmlformats.org/package/2006/relationships"

    private static let contentTypes = xmlDeclaration
        + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
        + "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
        + "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
        + "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>"
        + "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        + "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>"
        + "</Types>"

    private static let rootRels = xmlDeclaration
        + "<Relationships xmlns=\"\(packageRelNamespace)\">"
        + "<Relationship Id=\"rId1\" Type=\"\(relNamespace)/officeDocument\" Target=\"xl/workbook.xml\"/>"
        + "</Relationships>"

    private static let workbookRels = xmlDeclaration
        + "<Relationships xmlns=\"\(packageRelNamespace)\">"
        + "<Relationship Id=\"rId1\" Type=\"\(relNamespace)/worksheet\" Target=\"worksheets/sheet1.xml\"/>"
        + "<Relationship Id=\"rId2\" Type=\"\(relNamespace)/styles\" Target=\"styles.xml\"/>"
        + "</Relationships>"

    // Fonts: 0 regular, 1 bold, 2 bold 14pt. Borders: 0 none, 1 bottom, 2 top. numFmt 3 is the built-in "#,##0".
    private static let styles = xmlDeclaration
        + "<styleSheet xmlns=\"\(mainNamespace)\">"
        + "<numFmts count=\"1\"><numFmt numFmtId=\"164\" formatCode=\"0.0\"/></numFmts>"
        + "<fonts count=\"3\">"
        + "<font><sz val=\"11\"/><name val=\"Calibri\"/></font>"
        + "<font><b/><sz val=\"11\"/><name val=\"Calibri\"/></font>"
        + "<font><b/><sz val=\"14\"/><name val=\"Calibri\"/></font>"
        + "</fonts>"
        + "<fills count=\"2\"><fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill></fills>"
        + "<borders count=\"3\">"
        + "<border><left/><right/><top/><bottom/><diagonal/></border>"
        + "<border><left/><right/><top/><bottom style=\"thin\"/><diagonal/></border>"
        + "<border><left/><right/><top style=\"thin\"/><bottom/><diagonal/></border>"
        + "</borders>"
        + "<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>"
        + "<cellXfs count=\"7\">"
        + "<xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>"
        + "<xf numFmtId=\"0\" fontId=\"2\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyFont=\"1\"/>"
        + "<xf numFmtId=\"0\" fontId=\"1\" fillId=\"0\" borderId=\"1\" xfId=\"0\" applyFont=\"1\" applyBorder=\"1\"/>"
        + "<xf numFmtId=\"3\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyNumberFormat=\"1\"/>"
        + "<xf numFmtId=\"164\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyNumberFormat=\"1\"/>"
        + "<xf numFmtId=\"0\" fontId=\"1\" fillId=\"0\" borderId=\"2\" xfId=\"0\" applyFont=\"1\" applyBorder=\"1\"/>"
        + "<xf numFmtId=\"3\" fontId=\"1\" fillId=\"0\" borderId=\"2\" xfId=\"0\" applyNumberFormat=\"1\" applyFont=\"1\" applyBorder=\"1\"/>"
        + "</cellXfs>"
        + "<cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles>"
        + "</styleSheet>"
}
