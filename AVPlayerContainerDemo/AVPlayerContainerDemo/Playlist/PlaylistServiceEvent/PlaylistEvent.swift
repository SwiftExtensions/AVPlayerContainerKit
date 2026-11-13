//
//  PlaylistEvent.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 12.11.2026.
//

/**
 События плейлиста для отображения.
 */
enum PlaylistEvent {
    /**
     Плейлист загружен.
     */
    case loaded
    /**
     Плейлист не удалось загрузить.

     - Parameter error: Ошибка загрузки.
     */
    case loadingFailed(Error)
    /**
     Плейлист изменился: таблица перезагружается целиком.
     */
    case playlistChanged


}


