//
//  ImageLoader.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 23.10.2026.
//

import UIKit

/**
 Загрузчик изображений.

 Пока только загружает изображения по адресам. В дальнейшем будет
 хранить их в кэше.

 Актор: задачи загрузки запрашиваются многими ячейками одновременно,
 поэтому словарь задач защищён от гонки изоляцией актора.
 */
actor ImageLoader {
    /**
     Задачи загрузки изображений по адресам.
     */
    private var loadingTasks: [URL: Task<UIImage, Swift.Error>] = [:]

    /**
     Загружает изображение по адресу.

     Если загрузка с этим адресом уже идёт, возвращается результат
     существующей задачи — новая не запускается.

     - Parameter url: Адрес изображения.
     - Returns: Загруженное изображение.
     - Throws: Ошибка сетевой загрузки или неподходящего формата данных.
     */
    func image(from url: URL) async throws -> UIImage {
        let task = self.loadingTasks[url] ?? self.startLoading(from: url)
        self.loadingTasks[url] = task
        // отменённая задача не удаляется: запись могла быть заменена новой
        defer {
            if !task.isCancelled {
                self.loadingTasks[url] = nil
            }
        }

        return try await task.value
    }
    /**
     Создаёт задачу загрузки изображения.

     - Parameter url: Адрес изображения.
     - Returns: Созданная задача загрузки.
     */
    private func startLoading(from url: URL) -> Task<UIImage, Swift.Error> {
        Task<UIImage, Swift.Error> {
            try await self.loadImage(from: url)
        }
    }
    /**
     Загружает данные изображения и декодирует их.

     - Parameter url: Адрес изображения.
     - Returns: Загруженное изображение.
     - Throws: Ошибка сетевой загрузки или некорректного ответа сервера.
     */
    private func loadImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw URLError(.badServerResponse)
        }

        return image
    }
    /**
     Отменяет загрузку изображения по адресу.

     - Parameter url: Адрес изображения.
     */
    func cancelLoading(from url: URL) {
        self.loadingTasks[url]?.cancel()
        self.loadingTasks[url] = nil
    }


}
