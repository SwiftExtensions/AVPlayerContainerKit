//
//  PlaylistService.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 22.10.2026.
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
     - Parameter indexPath: Путь строки потока в таблице.
     */
    case streamChanged(_ stream: Stream, indexPath: IndexPath)
    /**
     Запрошенный поток разрешён итоговым состоянием: готов к воспроизведению
     или не удалось проверить.

     - Parameter stream: Поток вещания с итоговым состоянием.
     - Parameter indexPath: Путь строки потока в таблице.
     */
    case resolvedStream(_ stream: Stream, indexPath: IndexPath)


}

/**
 Сервис плейлиста.

 Оркестрирует работу плейлиста: загружает его по адресу, начинает проверку
 непроверенных потоков и обрабатывает запросы на воспроизведение потоков.
 О ходе работы сообщает событиями.
 */
final class PlaylistService {
    /**
     Группы потоков вещания плейлиста.
     */
    var groups: [Group] { self.playlist.groups }
    /**
     Последовательность событий плейлиста.
     */
    var events: AsyncStream<PlaylistEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }
    
    /**
     Плейлист.
     */
    private let playlist = Playlist()
    
    /**
     Путь строки потока с приоритетной проверкой.
     */
    private var priorityIndexPath: IndexPath?
    /**
     Продолжение последовательности событий плейлиста.
     */
    private var eventContinuation: AsyncStream<PlaylistEvent>.Continuation?
    /**
     Задача работы сервиса.
     */
    private var workTask: Task<Void, Never>?

    /**
     Запускает работу: загружает плейлист по указанному адресу, сообщает
     о загрузке и начинает проверку непроверенных потоков.
     - Parameter url: Адрес плейлиста в формате M3U.
     */
    func start(url: URL) {
        self.workTask = Task { [weak self] in
            await self?.run(url: url)
        }
    }
    /**
     Возвращает поток по пути строки.
     - Parameter indexPath: Путь строки: секция — группа, строка — поток в ней.
     - Returns: Поток вещания.
     */
    func stream(at indexPath: IndexPath) -> Stream {
        self.playlist.stream(at: indexPath)
    }
    /**
     Запрашивает проверку потока по пути строки.
     - Parameter indexPath: Путь строки потока.
     */
    func requestValidation(at indexPath: IndexPath) {
        self.playlist.requestValidation(at: indexPath)
    }
    /**
     Отменяет запрос на проверку потока по пути строки.
     - Parameter indexPath: Путь строки потока.
     */
    func cancelValidation(at indexPath: IndexPath) {
        self.playlist.cancelValidation(at: indexPath)
    }
    /**
     Разрешает статус потока по пути строки.

     Непроверенный поток проверяется вне очереди и разрешается событием
     после проверки. Для потока с ошибкой назначается повторная внеочередная
     проверка. Готовый к воспроизведению поток разрешается сразу.

     - Parameter indexPath: Путь строки потока.
     */
    func resolveStreamStatus(at indexPath: IndexPath) {
        let stream = self.playlist.stream(at: indexPath)
        switch stream.status {
        case .unknown, .failed:
            // статус потока с ошибкой сбрасывается для повторной проверки
            if case .failed = stream.status {
                self.playlist.setStatus(.unknown, at: indexPath)
            }
            // непроверенный поток проверяется вне очереди
            self.playlist.prioritizeValidation(at: indexPath)
            // поток будет разрешён событием после проверки
            self.priorityIndexPath = indexPath
        case .readyToPlay:
            self.emit(.resolvedStream(stream, indexPath: indexPath))
        case .processing:
            break
        }
    }
    /**
     Выполняет работу сервиса: загрузку плейлиста и обработку изменений
     состояния потоков.

     - Parameter url: Адрес плейлиста в формате M3U.
     */
    private func run(url: URL) async {
        do {
            try await self.playlist.loadPlaylist(from: url)
            self.emit(.loaded)
            for try await indexPath in self.playlist.validateRequestedStreams() {
                self.handleStatusChange(at: indexPath)
            }
        } catch {
            self.emit(.loadingFailed(error))
        }
    }
    /**
     Обрабатывает изменение состояния потока и формирует событие.

     Для потока с запросом на воспроизведение сообщается событие
     воспроизведения, для остальных — событие изменения состояния.

     - Parameter indexPath: Путь строки потока.
     */
    private func handleStatusChange(at indexPath: IndexPath) {
        let stream = self.playlist.stream(at: indexPath)
        switch stream.status {
        case .readyToPlay, .failed:
            // запрошенный поток разрешается событием после проверки
            if self.priorityIndexPath == indexPath {
                self.priorityIndexPath = nil
                self.emit(.resolvedStream(stream, indexPath: indexPath))
            } else {
                self.emit(.streamChanged(stream, indexPath: indexPath))
            }
        case .unknown, .processing:
            self.emit(.streamChanged(stream, indexPath: indexPath))
        }
    }
    /**
     Выдаёт событие в последовательность событий плейлиста.

     - Parameter event: Событие плейлиста.
     */
    private func emit(_ event: PlaylistEvent) {
        self.eventContinuation?.yield(event)
    }


}
