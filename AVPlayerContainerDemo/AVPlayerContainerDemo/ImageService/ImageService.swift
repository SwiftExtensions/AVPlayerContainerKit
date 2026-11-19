//
//  ImageService.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 23.10.2026.
//

import UIKit

/**
 Сервис изображений.

 Обёртка над загрузчиком `ImageLoader`: принимает адрес строкой
 и преобразует его в `URL`. Загруженные изображения хранит в кэше.

 Создаётся владельцем — контроллером плейлиста, который загружает
 логотипы каналов для ячеек таблицы.
 */
final class ImageService {
    /**
     Кэш изображений по адресам.

     `NSCache` потокобезопасен и сам вытесняет старые записи
     при нехватке памяти.
     */
    private let cache = NSCache<NSURL, UIImage>()
    /**
     Загрузчик изображений.
     */
    private let loader = ImageLoader()

    /**
     Создаёт сервис изображений.

     Ограничивает кэш сотней изображений.
     */
    init() {
        self.cache.countLimit = 100
    }

    /**
     Загружает изображение по адресу.

     Сначала изображение ищется в кэше. Если загрузка с этим адресом
     уже идёт, возвращается результат существующей задачи — новая
     не запускается. Загруженное изображение сохраняется в кэш.

     - Parameter urlString: Адрес изображения.
     - Returns: Загруженное изображение.
     - Throws: Ошибка некорректного адреса, сетевой загрузки
       или неподходящего формата данных.
     */
    func image(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        if let cachedImage = self.cache.object(forKey: url as NSURL) {
            return cachedImage
        }
        let image = try await self.loader.image(from: url)
        self.cache.setObject(image, forKey: url as NSURL)
        return image
    }
    /**
     Загружает изображение по адресу и сообщает результат.

     Результат доставляется на главном акторе, поэтому в блоке можно
     обновлять интерфейс. Отмена возвращаемой задачи снимает ожидание
     только этого запроса: загрузка продолжается, пока у адреса есть
     другие запросы.

     - Parameter urlString: Адрес изображения.
     - Parameter completion: Результат загрузки: изображение или ошибка.
     - Returns: Задача загрузки изображения с сообщением результата.
     */
    @discardableResult
    func loadImage(
        from urlString: String,
        completion: @escaping @MainActor (Result<UIImage, any Error>) -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                completion(.success(try await self.image(from: urlString)))
            } catch {
                completion(.failure(error))
            }
        }
    }


}
