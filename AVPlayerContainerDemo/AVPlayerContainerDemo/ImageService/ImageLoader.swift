//
//  ImageLoader.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 23.10.2026.
//

import SharedTaskKit
import UIKit

/**
 Загрузчик изображений.

 Загружает изображения по адресам: запросы с одинаковым адресом делят
 одну загрузку, число одновременных загрузок ограничено очередью,
 а загрузка отменяется, когда у адреса не остаётся активных запросов.
 Оркестрацией занимается `SharedTasks` из пакета `SharedTaskKit`,
 загрузчик лишь описывает, как по адресу получить изображение.

 Актор: запросы изображений приходят из многих задач одновременно,
 поэтому доступ к пулу сериализован изоляцией актора.
 */
actor ImageLoader {
    /**
     Пул задач загрузки по адресам.

     Дедуплицирует загрузки с одинаковым адресом, ограничивает число
     одновременных загрузок и отменяет задачу, когда у адреса не
     остаётся активных запросов.
     */
    private let imageTasks: SharedTasks<URL, UIImage>

    /**
     Создаёт загрузчик изображений.

     - Parameter maxLoadingTasks: Максимальное число одновременных
       загрузок. Задачи сверх лимита встают в очередь и запускаются,
       когда место освобождается.
     */
    init(maxLoadingTasks: Int = 10) {
        self.imageTasks = SharedTasks(
            maxConcurrentTasks: maxLoadingTasks,
            operation: { url in try await Self.loadImage(from: url) }
        )
    }

    /**
     Загружает изображение по адресу.

     Каждый вызов — отдельный запрос: загрузки с тем же адресом делят
     одну задачу, а отмена вызывающей задачи снимает ожидание только
     этого запроса.

     - Parameter url: Адрес изображения.
     - Returns: Загруженное изображение.
     - Throws: Ошибка сетевой загрузки или неподходящего формата данных.
     */
    func image(from url: URL) async throws -> UIImage {
        try await self.imageTasks.value(for: url)
    }
    /**
     Загружает данные изображения и декодирует их.

     - Parameter url: Адрес изображения.
     - Returns: Загруженное изображение.
     - Throws: Ошибка сетевой загрузки или некорректного ответа сервера.
     */
    private static func loadImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw URLError(.badServerResponse)
        }

        return image
    }


}

