//
//  Playlist.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 21.10.2026.
//

import AVFoundation
import AVPlayerKit

/**
 Плейлист.

 Хранит группы потоков вещания и их состояния, загружается из файла
 формата M3U и проверяет потоки по запросам.
 */
final class Playlist {
    /**
     Группы потоков вещания по заголовкам групп.
     
     Порядок групп соответствует порядку первого появления в плейлисте.
     */
    var groups: [Group] { self.store.groups }
    
    /**
     Хранилище потоков вещания.
     */
    private let store = StreamStore()
    /**
     Валидатор ресурсов.

     Создаётся методом `validateRequestedStreams`; до его вызова равен `nil`,
     и запросы на проверку игнорируются.
     */
    private var assetValidator: AVAssetValidator<StreamStore>?

    /**
     Загружает плейлист по указанному адресу и сохраняет все найденные потоки
     в хранилище.

     - Parameter url: Адрес плейлиста в формате M3U.
     */
    func loadPlaylist(from url: URL) async throws {
        for try await _ in self.streams(from: url) { }
    }
    /**
     Загружает плейлист по указанному адресу и возвращает асинхронную
     последовательность потоков вещания.

     Каждый поток перед выдачей потребителю добавляется в хранилище
     в свою группу.

     - Parameter url: Адрес плейлиста в формате M3U.
     - Returns: Асинхронная последовательность потоков вещания.
     */
    func streams(
        from url: URL
    ) -> AsyncThrowingMapSequence<AsyncThrowingStream<Stream, any Error>, Stream> {
        PlaylistLoader().streams(from: url).map { stream in
            self.store.append(stream)
            print(stream)

            return stream
        }
    }


}

// MARK: - Проверка потоков по запросу

extension Playlist {
    /**
     Возвращает поток по пути строки.

     - Parameter indexPath: Путь строки: секция — группа, строка — поток в ней.
     - Returns: Поток вещания.
     */
    func stream(at indexPath: IndexPath) -> Stream {
        self.store.stream(at: indexPath)
    }
    /**
     Задаёт состояние потока по пути строки.

     - Parameter status: Новое состояние.
     - Parameter indexPath: Путь строки потока.
     */
    func setStatus(_ status: Stream.Status, at indexPath: IndexPath) {
        self.store.setStatus(status, at: indexPath)
    }
    /**
     Проверяет потоки по очереди запросов и выдаёт пути строк элементов, у
     которых изменилось состояние.

     Под каждый вызов создаётся новый валидатор ресурсов с указанным временем
     ожидания проверки.

     - Parameter timeout: Максимальное время ожидания проверки одного потока
     в секундах.
     - Returns: Асинхронная последовательность путей строк изменённых элементов.
     */
    func validateRequestedStreams(
        timeout: TimeInterval = 5.0
    ) -> AsyncThrowingStream<IndexPath, any Error> {
        let validator = AVAssetValidator(items: self.store, timeout: timeout)
        self.assetValidator = validator
        return validator.changes()
    }
    /**
     Запрашивает проверку потока по пути строки.

     Если состояние потока ещё неизвестно, он ставится в очередь проверки.
     Для потоков с известным состоянием или с активным запросом запрос
     не создаётся. Если сессия проверки не запущена, запрос игнорируется.

     - Parameter indexPath: Путь строки потока.
     */
    func requestValidation(at indexPath: IndexPath) {
        self.assetValidator?.requestValidation(at: indexPath)
    }
    /**
     Отменяет запрос на проверку потока по пути строки.

     Поток удаляется из очереди, а если он проверялся в данный момент,
     проверка прерывается.

     - Parameter indexPath: Путь строки потока.
     */
    func cancelValidation(at indexPath: IndexPath) {
        self.assetValidator?.cancelValidation(at: indexPath)
    }
    /**
     Назначает поток приоритетным для проверки по пути строки.

     Текущая проверка отменяется, а её поток возвращается в очередь.
     Указанный поток проверяется следующим, остальные — после него.

     - Parameter indexPath: Путь строки потока.
     */
    func prioritizeValidation(at indexPath: IndexPath) {
        self.assetValidator?.prioritizeValidation(at: indexPath)
    }


}

// MARK: - Проверка всех потоков

extension Playlist {
    /**
     Последовательно проверяет все потоки плейлиста на возможность
     воспроизведения и выдаёт пути строк элементов, у которых изменилось
     состояние.

     В отличие от `validateRequestedStreams`, проверяет все потоки подряд,
     независимо от запросов. Для каждого потока состояние меняется дважды:
     сначала на `.processing`, затем на `.readyToPlay` или `.failed`.

     - Parameter timeout: Максимальное время ожидания проверки одного потока
     в секундах.
     - Returns: Асинхронная последовательность путей строк изменённых элементов.
     Ошибка проверки завершает последовательность с исключением.
     */
    func validateAllStreams(
        timeout: TimeInterval = 5.0
    ) -> AsyncThrowingStream<IndexPath, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.performAllValidations(
                    timeout: timeout,
                    continuation: continuation
                )
            }
            // отменяем проверку, если потребитель прекратил итерацию
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    /**
     Проверяет все потоки и выдаёт пути строк элементов, у которых изменилось
     состояние, в продолжение асинхронной последовательности.

     По завершении всех проверок последовательность закрывается. Ошибка проверки
     одного потока завершает последовательность с исключением.

     - Parameter timeout: Максимальное время ожидания проверки одного потока
       в секундах.
     - Parameter continuation: Продолжение асинхронной последовательности, в которое
       выдаются пути строк изменённых элементов.
     */
    private func performAllValidations(
        timeout: TimeInterval,
        continuation: AsyncThrowingStream<IndexPath, any Error>.Continuation
    ) async {
        do {
            for section in self.store.groups.indices {
                for row in self.store.groups[section].streams.indices {
                    try await self.validateStream(
                        at: IndexPath(row: row, section: section),
                        timeout: timeout,
                        continuation: continuation
                    )
                }
            }
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }
    /**
     Проверяет поток по указанному пути строки и выдаёт путь строки
     в продолжение асинхронной последовательности при каждом изменении
     состояния.

     Состояние меняется дважды: сначала на `.processing`, затем на
     `.readyToPlay` или `.failed`.

     - Parameter indexPath: Путь строки проверяемого потока.
     - Parameter timeout: Максимальное время ожидания проверки в секундах.
     - Parameter continuation: Продолжение асинхронной последовательности, в которое
       выдаётся путь строки при изменении состояния.
     */
    private func validateStream(
        at indexPath: IndexPath,
        timeout: TimeInterval,
        continuation: AsyncThrowingStream<IndexPath, any Error>.Continuation
    ) async throws {
        self.store.setStatus(.processing, at: indexPath)
        continuation.yield(indexPath)

        let asset = AVAsset(url: self.store.stream(at: indexPath).url)
        do {
            try await asset.validatePlayability(timeout: timeout)
            self.store.setStatus(.readyToPlay, at: indexPath)
        } catch {
            self.store.setStatus(.failed(error), at: indexPath)
        }
        continuation.yield(indexPath)
    }


}
