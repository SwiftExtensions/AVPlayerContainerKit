//
//  StreamStore.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 21.10.2026.
//

import AVPlayerKit
import Foundation

/**
 Хранилище потоков вещания.

 Общее для менеджера плейлиста и валидатора потоков. Владеет группами
 потоков вещания, доступ к потокам выполняется по пути строки.
 */
final class StreamStore {
    /**
     Группы потоков вещания по заголовкам групп.

     Порядок групп соответствует порядку первого появления в плейлисте.
     */
    private(set) var groups: [Group] = []

    /**
     Возвращает поток по пути строки.

     - Parameter indexPath: Путь строки: секция — группа, строка — поток в ней.
     - Returns: Поток вещания.
     */
    func stream(at indexPath: IndexPath) -> Stream {
        self.groups[indexPath.section].streams[indexPath.row]
    }
    /**
     Добавляет поток в свою группу.

     Группа с таким же заголовком пополняется потоком, при первом
     появлении заголовка создаётся новая группа в конце списка.

     - Parameter stream: Поток вещания.
     */
    func append(_ stream: Stream) {
        let title = stream.attributes["group-title"]
        if let groupIndex = self.groups.firstIndex(where: { $0.title == title }) {
            self.groups[groupIndex].streams.append(stream)
        } else {
            self.groups.append(Group(title: title, streams: [stream]))
        }
    }
    /**
     Задаёт состояние потока по пути строки.

     - Parameter status: Новое состояние.
     - Parameter indexPath: Путь строки потока.
     */
    func setStatus(_ status: Stream.Status, at indexPath: IndexPath) {
        self.groups[indexPath.section].streams[indexPath.row].status = status
    }


}

// MARK: - Коллекция проверяемых ресурсов

extension StreamStore: AVAssetStatusManageableItems {
    typealias Index = IndexPath
    func url(at index: IndexPath) -> URL {
        self.stream(at: index).url
    }
    func status(at index: IndexPath) -> AVAssetStatus {
        self.stream(at: index).status
    }


}
