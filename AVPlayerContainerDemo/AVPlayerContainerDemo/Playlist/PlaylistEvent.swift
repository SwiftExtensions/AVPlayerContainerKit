//
//  PlaylistEvent.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 12.11.2026.
//

import Foundation

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
     Состояние потока изменилось.

     - Parameter stream: Поток вещания с актуальным состоянием.
     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    case streamChanged(_ stream: Stream, indexPath: IndexPath)
    /**
     Запрошенный поток разрешён итоговым состоянием: готов к воспроизведению
     или не удалось проверить.

     - Parameter stream: Поток вещания с итоговым состоянием.
     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    case resolvedStream(_ stream: Stream, indexPath: IndexPath)
    /**
     Плейлист изменился: таблица перезагружается целиком.
     */
    case playlistChanged


}


