import Compression
import Foundation
import Testing
@testable import MoiFinansy

struct ReceiptParserTests {
    let calendar = TestCalendar.calendar

    @Test func parsesTypicalReceipt() {
        let text = """
        ООО «KORVON MARKET»
        ИНН 123456789
        Кассовый чек № 4521
        Хлеб 1 x 5.00
        Молоко 2 x 12.50
        ИТОГО: 30.00
        Наличные 50.00
        Сдача 20.00
        22.10.2026 18:45
        """
        let result = ReceiptParser.parse(text, calendar: calendar)
        #expect(result.total == 30)
        #expect(result.merchant == "ООО «KORVON MARKET")
        #expect(result.date == TestCalendar.date(2026, 10, 22, 18, 45))
    }

    @Test func totalOnNextLine() {
        let text = "CAFE RAVSHAN\nПлов 35,00\nЧай 5,00\nК оплате\n40,00 TJS"
        #expect(ReceiptParser.parse(text, calendar: calendar).total == 40)
    }

    @Test func englishTotalAndDateOnly() {
        let text = "GLOBUS\nItem 10.00\nTOTAL 1 250,50\n05.09.2026"
        let result = ReceiptParser.parse(text, calendar: calendar)
        #expect(result.total == dec("1250.5"))
        #expect(result.date == TestCalendar.date(2026, 9, 5))
    }
}

struct CSVParserTests {
    @Test func semicolonWithQuotes() {
        let rows = CSVParser.parse("Дата;Описание;Сумма\n22.10.2026;\"Кафе; Равшан\";-45,00\n23.10.2026;\"Он сказал \"\"привет\"\"\";300\n")
        #expect(rows.count == 3)
        #expect(rows[1] == ["22.10.2026", "Кафе; Равшан", "-45,00"])
        #expect(rows[2][1] == "Он сказал \"привет\"")
    }

    @Test func commaDelimiter() {
        let rows = CSVParser.parse("date,amount,details\r\n2026-10-22,-12.50,NETFLIX")
        #expect(rows == [["date", "amount", "details"], ["2026-10-22", "-12.50", "NETFLIX"]])
    }
}

struct XLSXReaderTests {
    /// Минимальный zip: stored или deflate.
    private func zip(_ files: [(String, String)], deflate: Bool) -> Data {
        var local = Data()
        var central = Data()
        func append16(_ value: Int, to data: inout Data) { data.append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)]) }
        func append32(_ value: Int, to data: inout Data) { append16(value & 0xFFFF, to: &data); append16(value >> 16 & 0xFFFF, to: &data) }
        for (name, content) in files {
            let raw = [UInt8](content.utf8)
            var payload = raw
            if deflate {
                var buffer = [UInt8](repeating: 0, count: raw.count + 64)
                let size = compression_encode_buffer(&buffer, buffer.count, raw, raw.count, nil, COMPRESSION_ZLIB)
                payload = Array(buffer.prefix(size))
            }
            let offset = local.count
            let nameBytes = [UInt8](name.utf8)
            append32(0x0403_4B50, to: &local); append16(20, to: &local); append16(0, to: &local); append16(deflate ? 8 : 0, to: &local)
            append32(0, to: &local); append32(0, to: &local)
            append32(payload.count, to: &local); append32(raw.count, to: &local)
            append16(nameBytes.count, to: &local); append16(0, to: &local)
            local.append(contentsOf: nameBytes); local.append(contentsOf: payload)

            append32(0x0201_4B50, to: &central); append16(20, to: &central); append16(20, to: &central); append16(0, to: &central)
            append16(deflate ? 8 : 0, to: &central); append32(0, to: &central); append32(0, to: &central)
            append32(payload.count, to: &central); append32(raw.count, to: &central)
            append16(nameBytes.count, to: &central); append16(0, to: &central); append16(0, to: &central)
            append16(0, to: &central); append16(0, to: &central); append32(0, to: &central); append32(offset, to: &central)
            central.append(contentsOf: nameBytes)
        }
        var end = Data()
        append32(0x0605_4B50, to: &end); append16(0, to: &end); append16(0, to: &end)
        append16(files.count, to: &end); append16(files.count, to: &end)
        append32(central.count, to: &end); append32(local.count, to: &end); append16(0, to: &end)
        return local + central + end
    }

    private let shared = #"<sst><si><t>Дата</t></si><si><t>Сумма</t></si><si><r><t>Кафе </t></r><r><t>Равшан</t></r></si></sst>"#
    private let sheet = #"<worksheet><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row><row r="2"><c r="A2"><v>46317</v></c><c r="B2"><v>-45.5</v></c><c r="C2" t="s"><v>2</v></c></row><row r="3"><c r="A3" t="inlineStr"><is><t>23.10.2026</t></is></c><c r="C3" t="inlineStr"><is><t>Такси</t></is></c></row></sheetData></worksheet>"#

    @Test(arguments: [false, true])
    func readsFirstSheet(deflate: Bool) throws {
        let data = zip([("xl/sharedStrings.xml", shared), ("xl/worksheets/sheet1.xml", sheet)], deflate: deflate)
        let rows = try XLSXReader.rows(from: data)
        #expect(rows[0] == ["Дата", "Сумма"])
        #expect(rows[1] == ["46317", "-45.5", "Кафе Равшан"])
        #expect(rows[2] == ["23.10.2026", "", "Такси"])
    }

    @Test func columnLetters() {
        #expect(XLSXReader.columnIndex("A1") == 0)
        #expect(XLSXReader.columnIndex("C12") == 2)
        #expect(XLSXReader.columnIndex("AA3") == 26)
    }

    @Test func rejectsGarbage() {
        #expect(throws: XLSXReader.ReadError.self) { try XLSXReader.rows(from: Data("hello".utf8)) }
    }
}

struct StatementImporterTests {
    let calendar = TestCalendar.calendar

    @Test func guessesHeaderMapping() {
        let table = [["Дата операции", "Описание", "Сумма", "Валюта"], ["22.10.2026 20:52", "YANDEX GO", "-45,00", "TJS"]]
        let mapping = StatementImporter.guessMapping(table)
        #expect(mapping.hasHeader)
        #expect(mapping.dateColumn == 0)
        #expect(mapping.descriptionColumn == 1)
        #expect(mapping.amountColumn == 2)
        let rows = StatementImporter.rows(table, mapping: mapping, calendar: calendar)
        #expect(rows.count == 1)
        #expect(rows[0].amount == -45)
        #expect(rows[0].description == "YANDEX GO")
        #expect(rows[0].date == TestCalendar.date(2026, 10, 22, 20, 52))
    }

    @Test func debitCreditColumns() {
        let table = [["Дата", "Назначение", "Расход", "Приход"], ["22.10.2026", "Магазин", "120,00", ""], ["23.10.2026", "Зарплата", "", "25 000,00"]]
        let mapping = StatementImporter.guessMapping(table)
        let rows = StatementImporter.rows(table, mapping: mapping, calendar: calendar)
        #expect(rows.map(\.amount) == [-120, 25_000])
    }

    @Test func excelSerialDate() {
        #expect(StatementImporter.parseDate("46317", calendar: calendar) == calendar.startOfDay(for: TestCalendar.date(2026, 10, 22)))
    }

    @Test func amounts() {
        #expect(StatementImporter.parseAmount("-1 250,50 TJS") == dec("-1250.5"))
        #expect(StatementImporter.parseAmount("(45.00)") == -45)
        #expect(StatementImporter.parseAmount("−12,5") == dec("-12.5"))
        #expect(StatementImporter.parseAmount("abc") == nil)
    }

    @Test func pdfTextToTable() {
        let text = "Выписка по карте 4*4242\n22.10.2026 20:52 YANDEX GO -45.00\n23.10.2026 Пополнение +300.00\nИтого: что-то"
        let table = StatementImporter.table(fromText: text)
        #expect(table.count == 3)
        #expect(table[1] == ["22.10.2026 20:52", "YANDEX GO", "-45.00"])
        let rows = StatementImporter.rows(table, mapping: StatementImporter.guessMapping(table), calendar: calendar)
        #expect(rows.map(\.amount) == [-45, 300])
    }
}
