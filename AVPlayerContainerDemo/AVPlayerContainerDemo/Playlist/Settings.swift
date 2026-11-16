//
//  Settings.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 12.11.2026.
//

import Foundation
import UserDefaultsKit

/**
 Настройки отображения плейлиста.

 Хранятся в стандартных настройках пользователя.
 */
struct Settings {
    /**
     Время проверки потока по умолчанию в секундах.
     */
    static let defaultValidationTimeout: TimeInterval = 5.0
    
    /**
     Скрывает нерабочие потоки (с ошибкой) из отображения плейлиста.
     */
    @UserDefault(key: .hidesFailedStreams, defaultValue: false)
    var isFailedStreamsHidden: Bool
    /**
     Максимальное время ожидания проверки одного потока в секундах.
     */
    @UserDefault(key: .validationTimeout, defaultValue: Self.defaultValidationTimeout)
    var validationTimeout: TimeInterval

    /**
     Создаёт настройки со значениями из стандартных настроек пользователя.
     */
    init() { }


}

// MARK: - Ключи настроек

private extension UserDefaults.Key {
    /**
     Ключ настройки «скрывать нерабочие потоки».
     */
    static let hidesFailedStreams: Self = "hidesFailedStreams"
    /**
     Ключ настройки «время проверки потока».
     */
    static let validationTimeout: Self = "validationTimeout"


}

