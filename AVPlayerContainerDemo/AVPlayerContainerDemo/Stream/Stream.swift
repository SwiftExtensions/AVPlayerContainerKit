//
//  Stream.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 05.10.2026.
//

import AVPlayerKit
import Foundation

/**
 Поток вещания (канал) из плейлиста.
 */
struct Stream {
    /**
     Название канала из строки `#EXTINF`.
     */
    let title: String
    /**
     Адрес потока.
     */
    let url: URL
    /**
     Длительность потока из строки `#EXTINF` в секундах.

     Для «живых» трансляций обычно равна `-1`.
     */
    let duration: String?
    /**
     Атрибуты строки `#EXTINF`, например `tvg-id`, `tvg-logo`, `group-title`.
     */
    let attributes: [String: String]
    /**
     Текущее состояние потока.
     */
    var status: Status

    /**
     Создаёт поток вещания.

     - Parameter title: Название канала из строки `#EXTINF`.
     - Parameter url: Адрес потока.
     - Parameter duration: Длительность потока из строки `#EXTINF`.
     - Parameter attributes: Атрибуты строки `#EXTINF`.
     - Parameter status: Текущее состояние потока.
     */
    init(
        title: String,
        url: URL,
        duration: String?,
        attributes: [String: String],
        status: Status
    ) {
        self.title = title
        self.url = url
        self.duration = duration
        self.attributes = attributes
        self.status = status
    }
}

// MARK: - Удобный инициализатор

extension Stream {
    /**
     Создаёт поток вещания из разобранной строки `#EXTINF` и адреса
     со состоянием по умолчанию.

     - Parameter extInf: Разобранная строка `#EXTINF`.
     - Parameter url: Адрес потока.
     */
    init(extInf: ExtInf, url: URL) {
        self.init(
            title: extInf.title,
            url: url,
            duration: extInf.duration,
            attributes: extInf.attributes,
            status: .unknown
        )
    }
    
    
}

extension Stream {
    /**
     Состояние потока вещания.
     */
    typealias Status = AVAssetStatus


}

extension Stream.Status {
    /**
     Эмодзи, обозначающее состояние потока.

     Для состояний без визуального обозначения (`unknown`, `processing`)
     возвращается `nil`.
     */
    var emoji: String? {
        switch self {
        case .unknown:     nil
        case .readyToPlay: "🟢"
        case .failed:      "🔴"
        case .processing:  nil
        }


    }


}
