//
//  PlaylistLoader.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 05.10.2026.
//

import Foundation

/**
 Загрузчик и парсер плейлиста в формате M3U.

 Разбирает плейлист построчно и выдаёт найденные потоки по мере их распознавания,
 не дожидаясь полной загрузки файла.
 */
struct PlaylistLoader {
    /**
     Парсер строки `#EXTINF`.
     */
    private let extInfParser = ExtInfParser()
    
    /**
     Загружает плейлист по указанному адресу и возвращает асинхронную
     последовательность потоков вещания.

     Элементы становятся доступны потребителю сразу после их распознавания.
     Если потребитель прекращает итерацию, сетевая задача отменяется.

     - Parameter url: Адрес плейлиста в формате M3U.
     - Returns: Асинхронная последовательность потоков вещания. Ошибка загрузки
       или разбора завершает последовательность с исключением.
     */
    func streams(from url: URL) -> AsyncThrowingStream<Stream, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.load(from: url, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // отменяем загрузку, если потребитель прекратил итерацию
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    /**
     Загружает плейлист и построчно передаёт его в парсер, выдавая распознанные
     потоки в продолжение асинхронной последовательности.

     - Parameter url: Адрес плейлиста в формате M3U.
     - Parameter continuation: Продолжение асинхронной последовательности, в которое
       выдаются распознанные потоки. По завершении загрузки последовательность
       закрывается.
     */
    private func load(
        from url: URL,
        continuation: AsyncThrowingStream<Stream, any Error>.Continuation
    ) async throws {
        let (data, _) = try await URLSession.shared.bytes(from: url)
        var currentExtInf: ExtInf?
        for try await line in data.lines {
            if let stream = self.handleLine(line, currentExtInf: &currentExtInf) {
                continuation.yield(stream)
            }
        }
        continuation.finish()
    }
    /**
     Разбирает одну строку плейлиста.

     Строка вида `#EXTINF:...` разбирается в структуру `ExtInf` и запоминается.
     Строка с адресом, следующая за ней, образует поток вещания.

     - Parameter line: Строка плейлиста.
     - Parameter currentExtInf: Разобранная строка `#EXTINF`, ожидающая своего
       адреса. Обновляется при разборе строки `#EXTINF` и сбрасывается после
       нахождения адреса.
     - Returns: Поток вещания, если строка завершает запись канала,
       иначе `nil`.
     */
    private func handleLine(_ line: String, currentExtInf: inout ExtInf?) -> Stream? {
        #if DEBUG
//        print(line)
        #endif
        var stream: Stream?
        if line.hasPrefix("#EXTINF:") {
            currentExtInf = self.extInfParser.parse(line)
        } else if let extInf = currentExtInf, line.hasPrefix("http") {
            if let url = URL(string: line) {
                stream = Stream(extInf: extInf, url: url)
            }
            currentExtInf = nil
        }

        return stream
    }


}
