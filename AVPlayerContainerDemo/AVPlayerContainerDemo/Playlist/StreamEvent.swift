//
//  StreamEvent.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 13.11.2026.
//

import Foundation

/**
 События потока вещания для отображения.
 */
enum StreamEvent {
    /**
     Состояние потока изменилось.

     - Parameter stream: Поток вещания с актуальным состоянием.
     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    case changed(_ stream: Stream, indexPath: IndexPath)
    /**
     Запрошенный поток разрешён итоговым состоянием: готов к воспроизведению
     или не удалось проверить.

     - Parameter stream: Поток вещания с итоговым состоянием.
     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    case resolved(_ stream: Stream, indexPath: IndexPath)


}


