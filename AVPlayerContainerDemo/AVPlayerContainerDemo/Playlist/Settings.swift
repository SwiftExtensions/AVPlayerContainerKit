//
//  Settings.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 12.11.2026.
//

import Foundation

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
     Ключ настройки «скрывать нерабочие потоки».
     */
    private static let hidesFailedStreamsKey = "hidesFailedStreams"
    /**
     Ключ настройки «время проверки потока».
     */
    private static let validationTimeoutKey = "validationTimeout"

    /**
     Скрывает нерабочие потоки (с ошибкой) из отображения плейлиста.
     */
    var isFailedStreamsHidden: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hidesFailedStreamsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hidesFailedStreamsKey) }
    }
    /**
     Максимальное время ожидания проверки одного потока в секундах.
     */
    var validationTimeout: TimeInterval {
        get {
            UserDefaults.standard.object(forKey: Self.validationTimeoutKey) as? TimeInterval
                ?? Self.defaultValidationTimeout
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.validationTimeoutKey) }
    }


}


