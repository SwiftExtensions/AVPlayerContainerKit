//
//  PlaybackService.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 13.11.2026.
//

import Foundation

/**
 Состояние воспроизведения потока.
 */
enum PlaybackStreamStatus {
    /**
     Воспроизведение не начиналось.
     */
    case idle
    /**
     Играет поток.
     - Parameter indexPath: Путь строки потока в плейлисте.
     - Parameter auto: Поток запущен автозапуском, а не выбором пользователя.
     */
    case playing(indexPath: IndexPath, auto: Bool)
    /**
     Сбойный автозапущенный поток: автозапуск ищет ему замену.
     - Parameter failedIndexPath: Путь строки сбойного потока в плейлисте.
     */
    case searching(failedIndexPath: IndexPath)
    /**
     Сбойный поток, выбранный пользователем: ожидается закрытие предупреждения.
     - Parameter indexPath: Путь строки сбойного потока в плейлисте.
     */
    case failed(indexPath: IndexPath)


}

/**
 Сервис воспроизведения плейлиста.

 Первый готовый к воспроизведению поток запускается автоматически; сбой
 автозапущенного потока заменяется ближайшим видимым готовым; сбой
 выбранного пользователем потока после закрытия предупреждения возвращает
 воспроизведение к прежде игравшему.

 Сервис не знает про интерфейс: воспроизведение, видимые строки
 и разрешение потока контроллеру плейлиста передаются замыканиями.
 */
final class PlaybackService {
    /**
     Сервис плейлиста.
     */
    private let playlistService: PlaylistService
    /**
     Запускает воспроизведение потока.

     - Parameter stream: Поток вещания.
     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    private let play: (Stream, IndexPath) -> Void
    /**
     Возвращает пути строк видимых ячеек в плейлисте.
     */
    private let visibleIndexPaths: () -> [IndexPath]
    /**
     Разрешает поток контроллеру плейлиста событием для выделения строки.
     */
    private let resolve: (StreamEvent) -> Void

    /**
     Состояние воспроизведения потока.
     */
    private var status: PlaybackStreamStatus = .idle
    /**
     Путь строки прежде игравшего потока.

     Куда возвращается воспроизведение при сбое потока, выбранного
     пользователем: переключение не удалось — остаёмся на прежде игравшем.
     */
    private var previousStreamIndexPath: IndexPath?

    /**
     Создаёт сервис воспроизведения плейлиста.

     - Parameter playlistService: Сервис плейлиста.
     - Parameter play: Замыкание запуска воспроизведения потока.
     - Parameter visibleIndexPaths: Замыкание путей строк видимых ячеек
       в плейлисте.
     - Parameter resolve: Замыкание разрешения потока контроллеру плейлиста
       событием для выделения строки.
     */
    init(
        playlistService: PlaylistService,
        play: @escaping (Stream, IndexPath) -> Void,
        visibleIndexPaths: @escaping () -> [IndexPath],
        resolve: @escaping (StreamEvent) -> Void
    ) {
        self.playlistService = playlistService
        self.play = play
        self.visibleIndexPaths = visibleIndexPaths
        self.resolve = resolve
    }

    /**
     Обрабатывает событие потока вещания.

     Готовый к воспроизведению запрошенный поток запускается в плеере.

     - Parameter event: Событие потока вещания.
     */
    func handle(_ event: StreamEvent) {
        switch event {
        case let .resolved(stream, indexPath):
            // поток разрешён выбором пользователя: автозапуск завершён
            guard case .readyToPlay = stream.status else { return }
            
            // запоминаем играющий поток: при сбое выбранного к нему возврат
            if case .playing(let currentIndexPath, _) = self.status {
                self.previousStreamIndexPath = currentIndexPath
            }
            self.status = .playing(indexPath: indexPath, auto: false)
            self.play(stream, indexPath)
        case let .changed(stream, indexPath):
            // готовый к воспроизведению поток запускается автоматически,
            // пока воспроизведение не начиналось или автозапуск ищет замену
            // сбойному потоку; выбор пользователя автозапуск не возобновляет
            guard case .readyToPlay = stream.status else { return }
            
            switch self.status {
            case .idle, .searching:
                self.autoplay(stream: stream, at: indexPath)
            case .playing, .failed:
                break
            }
        }
    }
    /**
     Обрабатывает ошибку воспроизведения текущего потока.

     Автозапущенный поток заменяется ближайшим готовым к воспроизведению
     среди видимых строк; для выбранного пользователем воспроизведение
     возвращается к прежде игравшему после закрытия предупреждения о сбое.

     - Parameter error: Ошибка воспроизведения. `nil`, если система
       не сообщила причину.
     */
    func streamPlaybackFailed(_ error: (any Error)?) {
        switch self.status {
        case let .playing(indexPath, auto: true):
            self.status = .searching(failedIndexPath: indexPath)
            self.playlistService.streamPlaybackFailed(error, at: indexPath)
            // замена ближайшим готовым среди видимых строк; если готовых нет,
            // замена найдётся при прокрутке списка
            let candidates = self.visibleIndexPaths()
            if let next = self.nextReadyStream(after: indexPath, among: candidates) {
                self.autoplay(stream: next.stream, at: next.indexPath)
            }
        case let .playing(indexPath, auto: false):
            self.status = .failed(indexPath: indexPath)
            self.playlistService.streamPlaybackFailed(error, at: indexPath)
            // возврат к прежде игравшему после закрытия предупреждения о сбое
        case .idle, .searching, .failed:
            break
        }
    }
    /**
     Обрабатывает закрытие предупреждения о сбойном потоке.

     Сбойный поток убирается с экрана. Если его переключение сорвалось,
     воспроизведение возвращается к прежде игравшему потоку.

     - Parameter indexPath: Путь строки сбойного потока в плейлисте.
     */
    func streamFailureDismissed(at indexPath: IndexPath) {
        self.playlistService.hideFailedStream(at: indexPath)
        // возврат к прежде игравшему — только если переключение состоялось
        // и сорвалось; при сбое проверки играющий поток не менялся
        guard case .failed = self.status else { return }
        self.resumePreviousStreamIfNeeded()
    }

    /**
     Запускает автозапуск потока.

     Поток запускается в плеере и разрешается контроллеру плейлиста
     событием для выделения строки.

     - Parameter stream: Поток вещания.
     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    private func autoplay(stream: Stream, at indexPath: IndexPath) {
        self.status = .playing(indexPath: indexPath, auto: true)
        self.play(stream, indexPath)
        // автозапущенный поток разрешён: контроллеру плейлиста
        // передаётся дополнительное событие разрешения
        self.resolve(.resolved(stream, indexPath: indexPath))
    }
    /**
     Возобновляет воспроизведение прежде игравшего потока.

     Вызывается при сбое воспроизведения потока, выбранного пользователем:
     переключение не удалось, воспроизведение возвращается к прежде игравшему
     потоку, если он готов к воспроизведению. Сбойный поток остаётся
     на экране до выбора другого канала пользователем.
     */
    private func resumePreviousStreamIfNeeded() {
        guard let previousIndexPath = self.previousStreamIndexPath else { return }
        self.previousStreamIndexPath = nil
        let stream = self.playlistService.stream(at: previousIndexPath)
        guard case .readyToPlay = stream.status else { return }
        
        self.status = .playing(indexPath: previousIndexPath, auto: false)
        self.play(stream, previousIndexPath)
        // контроллеру плейлиста сообщается разрешение для выделения строки
        self.resolve(.resolved(stream, indexPath: previousIndexPath))
    }
    /**
     Возвращает ближайший готовый к воспроизведению поток после указанного
     пути строки среди переданных путей строк.

     - Parameter indexPath: Путь строки сбойного потока в плейлисте.
     - Parameter candidates: Пути строк потоков-кандидатов в плейлисте.
     - Returns: Поток вещания с путём строки в плейлисте; `nil`, если готовых
       к воспроизведению потоков среди кандидатов после указанного нет.
     */
    private func nextReadyStream(
        after indexPath: IndexPath,
        among candidates: [IndexPath]
    ) -> (stream: Stream, indexPath: IndexPath)? {
        for candidate in candidates.sorted() where candidate > indexPath {
            let stream = self.playlistService.stream(at: candidate)
            if case .readyToPlay = stream.status {
                return (stream, candidate)
            }
        }
        return nil
    }


}


