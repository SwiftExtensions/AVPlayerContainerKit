# AVPlayerContainerKit

Синтаксический сахар для быстрой интеграции [AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayers).

Контейнер размещает на экране два контроллера — плеер и вспомогательный (например, плейлист). В портретной ориентации плеер занимает часть экрана, в альбомной разворачивается на весь. Плеер можно показывать и скрывать с анимацией сдвига, вспомогательный контроллер при этом подстраивается под оставшееся место. Поддерживается «картинка в картинке».

## Требования

- iOS 15+
- Swift 5.6+

## Установка

Подключение через [Swift Package Manager](https://www.swift.org/package-manager/):

``` swift
dependencies: [
    .package(url: "git@github.com:SwiftExtensions/AVPlayerContainerKit.git", from: "1.0.0")
]
```

Пакет автоматически подтягивает зависимости — `AVPlayerKit` (включая продукт `AVPlayerUI`) и `ActivityLabel`.

## Пример интеграции

``` swift
import UIKit
import AVPlayerContainerKit

final class PlayerContainerViewController: AVPlayerContainerViewController<UIViewController> {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Вспомогательный контроллер представления
        let secondaryViewController = UIViewController()
        // Добавить контроллеры представлений в контейнер
        self.addChilds(
            playerViewController: UIViewController(),
            secondaryViewController: secondaryViewController,
            isPlayerViewControllerPresented: true
        )
    }


}

extension UINavigationController {
    // Для скрытия HomeIndicator в случае использования UINavigationController
    open override var childForHomeIndicatorAutoHidden: UIViewController? {
        self.topViewController
    }
    
    
}
```

## Пример интеграции с плеером

``` swift
import AVFoundation
import UIKit

import AVPlayerContainerKit

final class PlayerContainerViewController: AVPlayerContainerViewController<PlayerViewController> {
    // Представление плеера
    var playerView: PlayerView! {
        self.playerViewController.playerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Вспомогательный контроллер представления
        let secondaryViewController = UIViewController()
        // Добавить контроллеры представлений в контейнер
        self.addChildWithDefaultPlayerViewController(
            secondaryViewController: secondaryViewController,
            isPlayerViewControllerPresented: true
        )
        // Добавить плеер
        self.setupPlayer()
    }
    
    private func setupPlayer() {
        let player = AVPlayer(urlString: "URL_TO_STREAM")
        self.playerView.player = player
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.playerView.player?.play()
    }


}

extension UINavigationController {
    // Для автоматического управления HomeIndicator в случае использования UINavigationController
    open override var childForHomeIndicatorAutoHidden: UIViewController? {
        self.topViewController
    }
    
    
}
```

## Картинка в картинке

``` swift
// Включить кнопку «картинка в картинке» в элементы управления плеера
self.enablePictureInPicture()
```

## Демо-приложение

В репозитории находится демо-приложение [AVPlayerContainerDemo](AVPlayerContainerDemo) — пример интеграции библиотеки в реальном приложении: загрузка и разбор плейлистов (M3U), отображение групп и потоков, воспроизведение через плеер.

Для запуска откройте `AVPlayerContainerDemo/AVPlayerContainerDemo.xcodeproj`. Пакет подключён как локальная зависимость, дополнительная настройка не требуется. При сборке демо-приложение не влияет на библиотеку: SPM использует только продукт `AVPlayerContainerKit`, объявленный в `Package.swift`.
