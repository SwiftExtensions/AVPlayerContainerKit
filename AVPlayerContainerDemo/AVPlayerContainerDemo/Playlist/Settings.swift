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
     Время запуска потока по умолчанию в секундах.
     */
    static let defaultPlaybackTimeout: TimeInterval = 15.0

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
     Максимальное время ожидания запуска воспроизведения потока
     в секундах.
     */
    @UserDefault(key: .playbackTimeout, defaultValue: Self.defaultPlaybackTimeout)
    var playbackTimeout: TimeInterval

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
    /**
     Ключ настройки «время запуска потока».
     */
    static let playbackTimeout: Self = "playbackTimeout"


}

