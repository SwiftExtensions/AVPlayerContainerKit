//
//  PlaylistService.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 22.10.2026.
//

import Foundation

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
     Нерабочие потоки (с ошибкой) скрыты из отображения плейлиста.

     Настройка сохраняется в настройках отображения плейлиста.
     */
    var isFailedStreamsHidden: Bool { self.filter.isFailedStreamsHidden }
    /**
     Отфильтрованные группы потоков вещания для отображения в таблице.

     При включённой настройке «скрывать нерабочие потоки» из групп исключаются
     потоки с ошибкой, а опустевшие группы не отображаются.
     */
    var filteredGroups: [Group] {
        self.filter.filterGroups(for: self.playlist.groups)
    }
    /**
     Снимки состояния групп плейлиста для отображения в таблице.

     При включённой настройке «скрывать нерабочие потоки» исключаются строки
     потоков с ошибкой, а опустевшие группы не отображаются.
     */
    var groupSnapshots: [GroupSnapshot] {
        self.filter.groupSnapshots(for: self.playlist.groups)
    }
    /**
     Последовательность событий плейлиста.
     */
    var events: AsyncStream<PlaylistEvent> {
        self.eventChannel.stream()
    }

    /**
     Плейлист.
     */
    private let playlist = Playlist()
    /**
     Отображение плейлиста.
     */
    private var filter = PlaylistFilter()
    /**
     Канал событий плейлиста.
     */
    private let eventChannel = EventChannel<PlaylistEvent>()

    /**
     Путь строки потока с приоритетной проверкой.
     */
    private var priorityIndexPath: IndexPath?
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
     Скрывает или показывает нерабочие потоки и сообщает о перезагрузке
     плейлиста.

     - Parameter hidden: Новое значение настройки.
     */
    func setFailedStreamsHidden(_ hidden: Bool) {
        guard self.filter.isFailedStreamsHidden != hidden else { return }
        self.filter.isFailedStreamsHidden = hidden
        self.emit(.playlistChanged)
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
     Сообщает об ошибке воспроизведения потока.

     Поток помечается состоянием `.failed`, и его изменение сообщается
     событием. Если поток был запрошен пользователем, он разрешается
     событием `resolvedStream` — контроллер плейлиста покажет предупреждение
     об ошибке и вернёт выделение на последнюю успешную строку.

     - Parameter error: Ошибка воспроизведения. `nil`, если система
       не сообщила причину.
     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    func streamPlaybackFailed(_ error: (any Error)?, at indexPath: IndexPath) {
        let failure = error ?? UnknownPlaybackError()
        self.playlist.setStatus(.failed(failure), at: indexPath)
        self.handleStatusChange(at: indexPath)
    }
    /**
     Разрешает статус потока по пути строки.

     Непроверенный поток проверяется вне очереди и разрешается событием
     после проверки. Для потока с ошибкой назначается повторная внеочередная
     проверка. Готовый к воспроизведению поток разрешается сразу.

     - Parameter indexPath: Путь строки потока в плейлисте.
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
     Скрытый поток не отображается: его исчезновение или появление меняет
     структуру таблицы — сообщается событие перезагрузки.

     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    private func handleStatusChange(at indexPath: IndexPath) {
        let stream = self.playlist.stream(at: indexPath)
        if self.filter.isHidden(stream) {
            self.emit(.playlistChanged)
            return
        }
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
     Выдаёт событие в канал событий плейлиста.

     - Parameter event: Событие плейлиста.
     */
    private func emit(_ event: PlaylistEvent) {
        self.eventChannel.emit(event)
    }


}
