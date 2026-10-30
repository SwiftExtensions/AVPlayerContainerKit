//
//  ExtInf.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 23.10.2026.
//

import Foundation

/**
 Строка `#EXTINF` плейлиста в формате M3U.

 Промежуточное представление записи канала: разобранная строка без адреса,
 который указывается следующей строкой плейлиста.
 */
struct ExtInf {
    /**
     Название канала.
     */
    let title: String
    /**
     Длительность потока из строки `#EXTINF` в секундах.

     Для «живых» трансляций обычно равна `-1`.
     */
    let duration: String?
    /**
     Атрибуты строки `#EXTINF`, например `tvg-id`, `tvg-logo`, `group-title`.
     */
    let attributes: [String: String]


}
