import CoreAudioKit
import os

private let log = Logger(subsystem: "me.jkca.mlxread.SystemVoiceProvider", category: "factory")

public class AudioUnitFactory: NSObject, AUAudioUnitFactory {
    var auAudioUnit: AUAudioUnit?

    public func beginRequest(with context: NSExtensionContext) {}

    @objc
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        log.info("createAudioUnit called (type \(componentDescription.componentType))")
        let unit = try MLXReadProviderAudioUnit(componentDescription: componentDescription, options: [])
        auAudioUnit = unit
        return unit
    }
}
