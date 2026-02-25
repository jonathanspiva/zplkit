import Foundation
import Testing
@testable import ZPLKitPrinter

@Suite("PrinterConfiguration Tests")
struct PrinterConfigurationTests {

    // MARK: - Enum Raw Values

    @Test("MediaType raw values match ZPL spec")
    func mediaTypeRawValues() {
        #expect(MediaType.directThermal.rawValue == "D")
        #expect(MediaType.thermalTransfer.rawValue == "T")
    }

    @Test("MediaTracking raw values match ZPL spec")
    func mediaTrackingRawValues() {
        #expect(MediaTracking.gap.rawValue == "N")
        #expect(MediaTracking.continuous.rawValue == "Y")
        #expect(MediaTracking.mark.rawValue == "M")
        #expect(MediaTracking.auto.rawValue == "A")
    }

    @Test("PrintMode raw values match ZPL spec")
    func printModeRawValues() {
        #expect(PrintMode.tearOff.rawValue == "T")
        #expect(PrintMode.peel.rawValue == "P")
        #expect(PrintMode.rewind.rawValue == "R")
        #expect(PrintMode.cutter.rawValue == "C")
    }

    @Test("SensorType raw values match ZPL spec")
    func sensorTypeRawValues() {
        #expect(SensorType.auto.rawValue == "A")
        #expect(SensorType.transmissive.rawValue == "T")
        #expect(SensorType.reflective.rawValue == "R")
    }

    @Test("PrintOrientation raw values match ZPL spec")
    func printOrientationRawValues() {
        #expect(PrintOrientation.normal.rawValue == "N")
        #expect(PrintOrientation.inverted.rawValue == "I")
    }

    @Test("PowerUpAction raw values match ZPL spec")
    func powerUpActionRawValues() {
        #expect(PowerUpAction.noMotion.rawValue == "N")
        #expect(PowerUpAction.feedToWeb.rawValue == "F")
        #expect(PowerUpAction.calibrate.rawValue == "C")
        #expect(PowerUpAction.shortCalibrate.rawValue == "S")
        #expect(PowerUpAction.feedCalibrate.rawValue == "L")
    }

    // MARK: - Empty Configuration

    @Test("Empty configuration generates no commands")
    func emptyConfigGeneratesNoCommands() {
        let config = PrinterConfiguration()
        let commands = config.zplCommands()
        #expect(commands.isEmpty)
    }

    // MARK: - Individual ZPL Command Generation

    @Test("Darkness generates ~SD immediate command")
    func darknessGeneratesImmediate() {
        let config = PrinterConfiguration().darkness(20)
        let commands = config.zplCommands()
        #expect(commands.count == 1)
        #expect(commands[0] == "~SD20")
    }

    @Test("Darkness pads single digit with leading zero")
    func darknessPadsSingleDigit() {
        let config = PrinterConfiguration().darkness(5)
        let commands = config.zplCommands()
        #expect(commands[0] == "~SD05")
    }

    @Test("Darkness clamps to 0-30 range")
    func darknessClamps() {
        let tooHigh = PrinterConfiguration().darkness(50)
        #expect(tooHigh.darkness == 30)

        let tooLow = PrinterConfiguration().darkness(-5)
        #expect(tooLow.darkness == 0)
    }

    @Test("Tear-off adjust generates ~TA immediate command")
    func tearOffAdjustGeneratesImmediate() {
        let config = PrinterConfiguration().tearOffAdjust(16)
        let commands = config.zplCommands()
        #expect(commands.count == 1)
        #expect(commands[0] == "~TA0016")
    }

    @Test("Tear-off adjust clamps to -120 to 120 range")
    func tearOffAdjustClamps() {
        let tooHigh = PrinterConfiguration().tearOffAdjust(200)
        #expect(tooHigh.tearOffAdjust == 120)

        let tooLow = PrinterConfiguration().tearOffAdjust(-200)
        #expect(tooLow.tearOffAdjust == -120)
    }

    @Test("Media type generates ^MT format command")
    func mediaTypeGeneratesFormat() {
        let config = PrinterConfiguration().mediaType(.directThermal)
        let commands = config.zplCommands()
        #expect(commands.count == 1)
        #expect(commands[0] == "^XA^MTD^XZ")
    }

    @Test("Media tracking generates ^MN format command")
    func mediaTrackingGeneratesFormat() {
        let config = PrinterConfiguration().mediaTracking(.gap)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^MNN^XZ")
    }

    @Test("Print width generates ^PW format command")
    func printWidthGeneratesFormat() {
        let config = PrinterConfiguration().printWidthDots(812)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^PW812^XZ")
    }

    @Test("Label length generates ^LL format command")
    func labelLengthGeneratesFormat() {
        let config = PrinterConfiguration().labelLengthDots(406)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^LL406^XZ")
    }

    @Test("Print speed generates ^PR format command")
    func printSpeedGeneratesFormat() {
        let config = PrinterConfiguration().printSpeedIPS(6)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^PR6^XZ")
    }

    @Test("Print speed with slew and backfeed")
    func printSpeedWithSlewAndBackfeed() {
        var config = PrinterConfiguration()
        config.printSpeedIPS = 6
        config.slewSpeedIPS = 8
        config.backfeedSpeedIPS = 4
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^PR6,8,4^XZ")
    }

    @Test("Character encoding generates ^CI format command")
    func characterEncodingGeneratesFormat() {
        let config = PrinterConfiguration().characterEncoding(28)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^CI28^XZ")
    }

    @Test("Print mode generates ^MM format command")
    func printModeGeneratesFormat() {
        let config = PrinterConfiguration().printMode(.cutter)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^MMC^XZ")
    }

    @Test("Sensor type generates ^JS format command")
    func sensorTypeGeneratesFormat() {
        let config = PrinterConfiguration().sensorType(.reflective)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^JSR^XZ")
    }

    @Test("Orientation generates ^PO format command")
    func orientationGeneratesFormat() {
        let config = PrinterConfiguration().orientation(.inverted)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^POI^XZ")
    }

    @Test("Label home generates ^LH format command")
    func labelHomeGeneratesFormat() {
        let config = PrinterConfiguration().labelHome(x: 10, y: 20)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^LH10,20^XZ")
    }

    @Test("Label top shift generates ^LT format command")
    func labelTopShiftGeneratesFormat() {
        let config = PrinterConfiguration().labelTopShift(50)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^LT50^XZ")
    }

    @Test("Label shift generates ^LS format command")
    func labelShiftGeneratesFormat() {
        let config = PrinterConfiguration().labelShift(25)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^LS25^XZ")
    }

    @Test("Power-up action generates ^MF format command")
    func powerUpActionGeneratesFormat() {
        let config = PrinterConfiguration().powerUpAction(.calibrate)
        let commands = config.zplCommands()
        // When only powerUpAction is set, headCloseAction defaults to same value
        #expect(commands[0] == "^XA^MFC,C^XZ")
    }

    @Test("Power-up and head close actions generate ^MF with both params")
    func powerUpAndHeadCloseGeneratesFormat() {
        let config = PrinterConfiguration()
            .powerUpAction(.feedToWeb)
            .headCloseAction(.calibrate)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^MFF,C^XZ")
    }

    @Test("Reprint after error generates ^JZ format command")
    func reprintAfterErrorGeneratesFormat() {
        let enabled = PrinterConfiguration().reprintAfterError(true)
        #expect(enabled.zplCommands()[0] == "^XA^JZY^XZ")

        let disabled = PrinterConfiguration().reprintAfterError(false)
        #expect(disabled.zplCommands()[0] == "^XA^JZN^XZ")
    }

    @Test("Printer name generates ^JN format command")
    func printerNameGeneratesFormat() {
        let config = PrinterConfiguration().printerName("Warehouse-01")
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^JNWarehouse-01^XZ")
    }

    @Test("Max label length generates ^ML format command")
    func maxLabelLengthGeneratesFormat() {
        let config = PrinterConfiguration().maxLabelLengthDots(2400)
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^ML2400^XZ")
    }

    @Test("Field rotation generates ^FW format command")
    func fieldRotationGeneratesFormat() {
        let config = PrinterConfiguration().fieldRotation("R")
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^FWR^XZ")
    }

    // MARK: - Immediate vs Format Command Ordering

    @Test("Immediate commands come before format block")
    func immediateBeforeFormat() {
        var config = PrinterConfiguration()
        config.darkness = 20
        config.mediaType = .directThermal
        config.printWidthDots = 812

        let commands = config.zplCommands()
        #expect(commands.count == 2)
        #expect(commands[0] == "~SD20")
        #expect(commands[1].hasPrefix("^XA"))
        #expect(commands[1].hasSuffix("^XZ"))
        #expect(commands[1].contains("^MTD"))
        #expect(commands[1].contains("^PW812"))
    }

    @Test("Multiple immediate commands are concatenated")
    func multipleImmediatesConcatenated() {
        var config = PrinterConfiguration()
        config.darkness = 20
        config.tearOffAdjust = 16

        let commands = config.zplCommands()
        #expect(commands.count == 1)
        #expect(commands[0] == "~SD20~TA0016")
    }

    // MARK: - Preset Configurations

    @Test("Direct thermal preset has expected fields")
    func directThermalPreset() {
        let config = PrinterConfiguration.directThermal(
            widthDots: 812,
            lengthDots: 406
        )

        #expect(config.mediaType == .directThermal)
        #expect(config.mediaTracking == .gap)
        #expect(config.printWidthDots == 812)
        #expect(config.labelLengthDots == 406)
        #expect(config.darkness == 15)
        #expect(config.printSpeedIPS == 4)
        #expect(config.characterEncoding == 28)
        #expect(config.printMode == .tearOff)
    }

    @Test("Thermal transfer preset has expected fields")
    func thermalTransferPreset() {
        let config = PrinterConfiguration.thermalTransfer(
            widthDots: 812,
            lengthDots: 1218
        )

        #expect(config.mediaType == .thermalTransfer)
        #expect(config.mediaTracking == .gap)
        #expect(config.printWidthDots == 812)
        #expect(config.labelLengthDots == 1218)
        #expect(config.darkness == 15)
        #expect(config.printSpeedIPS == 4)
        #expect(config.characterEncoding == 28)
        #expect(config.printMode == .tearOff)
    }

    @Test("Presets accept custom darkness and speed")
    func presetsAcceptCustomValues() {
        let config = PrinterConfiguration.directThermal(
            widthDots: 812,
            lengthDots: 406,
            darkness: 25,
            speedIPS: 6
        )

        #expect(config.darkness == 25)
        #expect(config.printSpeedIPS == 6)
    }

    @Test("Direct thermal preset generates correct ZPL")
    func directThermalPresetZPL() {
        let config = PrinterConfiguration.directThermal(
            widthDots: 812,
            lengthDots: 406
        )

        let commands = config.zplCommands()
        #expect(commands.count == 2)

        // Immediate: darkness
        #expect(commands[0] == "~SD15")

        // Format block should contain all format commands
        let format = commands[1]
        #expect(format.hasPrefix("^XA"))
        #expect(format.hasSuffix("^XZ"))
        #expect(format.contains("^CI28"))
        #expect(format.contains("^MTD"))
        #expect(format.contains("^MNN"))
        #expect(format.contains("^MMT"))
        #expect(format.contains("^PW812"))
        #expect(format.contains("^LL406"))
        #expect(format.contains("^PR4"))
    }

    // MARK: - Modifier Chaining (Immutability)

    @Test("Modifier chaining returns new values, does not mutate original")
    func modifierChainingImmutability() {
        let original = PrinterConfiguration()
        let modified = original.darkness(20).printWidthDots(812)

        // Original should be unchanged
        #expect(original.darkness == nil)
        #expect(original.printWidthDots == nil)

        // Modified should have new values
        #expect(modified.darkness == 20)
        #expect(modified.printWidthDots == 812)
    }

    @Test("Chained modifiers accumulate correctly")
    func chainedModifiersAccumulate() {
        let config = PrinterConfiguration()
            .mediaType(.directThermal)
            .mediaTracking(.gap)
            .printWidthDots(812)
            .labelLengthDots(406)
            .darkness(20)
            .printSpeedIPS(6)
            .printMode(.tearOff)
            .printerName("Test")

        #expect(config.mediaType == .directThermal)
        #expect(config.mediaTracking == .gap)
        #expect(config.printWidthDots == 812)
        #expect(config.labelLengthDots == 406)
        #expect(config.darkness == 20)
        #expect(config.printSpeedIPS == 6)
        #expect(config.printMode == .tearOff)
        #expect(config.printerName == "Test")
    }

    @Test("Preset can be further customized with modifiers")
    func presetWithModifiers() {
        let config = PrinterConfiguration.directThermal(
            widthDots: 812,
            lengthDots: 406
        )
        .printerName("Warehouse-01")
        .printMode(.cutter)

        #expect(config.mediaType == .directThermal)
        #expect(config.printerName == "Warehouse-01")
        #expect(config.printMode == .cutter)
    }

    // MARK: - Codable Roundtrip

    @Test("PrinterConfiguration Codable roundtrip with all fields")
    func codableRoundtrip() throws {
        var config = PrinterConfiguration()
        config.mediaType = .directThermal
        config.mediaTracking = .gap
        config.printWidthDots = 812
        config.labelLengthDots = 406
        config.darkness = 20
        config.printSpeedIPS = 6
        config.characterEncoding = 28
        config.printMode = .tearOff
        config.sensorType = .transmissive
        config.orientation = .normal
        config.fieldRotation = "N"
        config.slewSpeedIPS = 8
        config.backfeedSpeedIPS = 4
        config.tearOffAdjust = 16
        config.labelHomeX = 0
        config.labelHomeY = 0
        config.labelTopShift = 10
        config.labelShift = 5
        config.powerUpAction = .feedToWeb
        config.headCloseAction = .calibrate
        config.reprintAfterError = true
        config.printerName = "Test-Printer"
        config.maxLabelLengthDots = 2400

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(PrinterConfiguration.self, from: data)

        #expect(decoded == config)
    }

    @Test("PrinterConfiguration Codable roundtrip with empty config")
    func codableRoundtripEmpty() throws {
        let config = PrinterConfiguration()

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(PrinterConfiguration.self, from: data)

        #expect(decoded == config)
    }

    @Test("Enum types are Codable")
    func enumsCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for value in MediaType.allCases {
            let data = try encoder.encode(value)
            let decoded = try decoder.decode(MediaType.self, from: data)
            #expect(decoded == value)
        }

        for value in MediaTracking.allCases {
            let data = try encoder.encode(value)
            let decoded = try decoder.decode(MediaTracking.self, from: data)
            #expect(decoded == value)
        }

        for value in PrintMode.allCases {
            let data = try encoder.encode(value)
            let decoded = try decoder.decode(PrintMode.self, from: data)
            #expect(decoded == value)
        }

        for value in SensorType.allCases {
            let data = try encoder.encode(value)
            let decoded = try decoder.decode(SensorType.self, from: data)
            #expect(decoded == value)
        }

        for value in PrintOrientation.allCases {
            let data = try encoder.encode(value)
            let decoded = try decoder.decode(PrintOrientation.self, from: data)
            #expect(decoded == value)
        }

        for value in PowerUpAction.allCases {
            let data = try encoder.encode(value)
            let decoded = try decoder.decode(PowerUpAction.self, from: data)
            #expect(decoded == value)
        }
    }

    // MARK: - Network Configuration

    @Test("Network config generates ^ND format command")
    func networkConfigGeneratesFormat() {
        let config = PrinterConfiguration().networkConfig(
            ip: "192.168.1.100",
            subnet: "255.255.255.0",
            gateway: "192.168.1.1"
        )
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^ND192.168.1.100,255.255.255.0,192.168.1.1,N^XZ")
    }

    @Test("DHCP generates ^NDY format command")
    func dhcpGeneratesFormat() {
        let config = PrinterConfiguration().dhcp()
        let commands = config.zplCommands()
        #expect(commands[0] == "^XA^NDY^XZ")
    }

    // MARK: - Save Parameter

    @Test("zplCommands(save: true) appends ^JUS to format block")
    func saveAppendsJUS() {
        let config = PrinterConfiguration().mediaType(.directThermal)
        let commands = config.zplCommands(save: true)
        #expect(commands.count == 1)
        #expect(commands[0] == "^XA^MTD^JUS^XZ")
    }

    @Test("zplCommands(save: true) creates format block for immediate-only config")
    func saveCreatesFormatBlockForImmediateOnly() {
        let config = PrinterConfiguration().darkness(20)
        let commands = config.zplCommands(save: true)
        // Should have immediate command and a format block with just ^JUS
        #expect(commands.count == 2)
        #expect(commands[0] == "~SD20")
        #expect(commands[1] == "^XA^JUS^XZ")
    }

    @Test("zplCommands(save: false) does not append ^JUS")
    func noSaveDoesNotAppendJUS() {
        let config = PrinterConfiguration().mediaType(.directThermal)
        let commands = config.zplCommands(save: false)
        #expect(commands.count == 1)
        #expect(commands[0] == "^XA^MTD^XZ")
    }

    @Test("zplCommands(save: true) with empty config generates just ^JUS block")
    func saveWithEmptyConfig() {
        let config = PrinterConfiguration()
        let commands = config.zplCommands(save: true)
        #expect(commands.count == 1)
        #expect(commands[0] == "^XA^JUS^XZ")
    }

    @Test("zplCommands(save: true) with mixed commands includes ^JUS in format block")
    func saveWithMixedCommands() {
        var config = PrinterConfiguration()
        config.darkness = 20
        config.mediaType = .thermalTransfer
        config.printWidthDots = 832

        let commands = config.zplCommands(save: true)
        #expect(commands.count == 2)
        #expect(commands[0] == "~SD20")
        #expect(commands[1].hasPrefix("^XA"))
        #expect(commands[1].hasSuffix("^XZ"))
        #expect(commands[1].contains("^MTT"))
        #expect(commands[1].contains("^PW832"))
        #expect(commands[1].contains("^JUS"))
    }
}
