//
//  HapticManager.swift
//  LocalPackage
//

#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#elseif os(macOS)
import AppKit
#endif


@MainActor
public class HapticManager {
    public static let shared = HapticManager()
    
    // 2. Keep a single persistent instance alive on iOS to eliminate latency
    #if os(iOS)
    private let iosNotificationGenerator = UINotificationFeedbackGenerator()
    #endif
    
    private init() {
        #if os(iOS)
        iosNotificationGenerator.prepare()
        #endif
    }
    
    public func trigger(_ type: UniversalFeedbackType) {
        print("Haptic: \(type)")
        #if os(iOS)
        // Instant response because the object already exists and is warm
        switch type {
        case .success: iosNotificationGenerator.notificationOccurred(.success)
        case .warning: iosNotificationGenerator.notificationOccurred(.warning)
        case .error: iosNotificationGenerator.notificationOccurred(.error)
        }
        
        #elseif os(watchOS)
        // Works natively on Apple Watch
        switch type {
        case .success: WKInterfaceDevice.current().play(.success)
        case .warning: WKInterfaceDevice.current().play(.retry)
        case .error: WKInterfaceDevice.current().play(.failure)
        }
        
        #elseif os(macOS)
        // Works natively on Mac Trackpads
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
}

public enum UniversalFeedbackType {
    case success, warning, error
}
