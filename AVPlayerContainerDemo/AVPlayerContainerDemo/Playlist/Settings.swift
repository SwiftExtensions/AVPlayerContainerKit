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
     Ключ настройки «скрывать нерабочие потоки».
     */
    private static let hidesFailedStreamsKey = "hidesFailedStreams"

    /**
     Скрывает нерабочие потоки (с ошибкой) из отображения плейлиста.
     */
    var isFailedStreamsHidden: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hidesFailedStreamsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hidesFailedStreamsKey) }
    }


}


