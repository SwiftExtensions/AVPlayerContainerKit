# AVPlayerContainerKit

Синтактический сахар для быстрой интеграции [AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayers).

## Пример интеграции

``` swift
import UIKit
import AVPlayerContainerKit

class PlayerContainerViewController: AVPlayerContainerViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Контроллер представления списка потоков
        let streams = UIViewController()
        // Добавить контроллеры представлений в контейнер
        self.addChildWithDefaultPlayerViewController(
            streamsViewController: streams, 
            isPlayerViewControllerPresented: true)
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
import UIKit
import AVFoundation
import AVPlayerKit
import AVPlayerContainerKit

class PlayerContainerViewController: AVPlayerContainerViewController {
    // Представление плеера
    var playerView: PlayerView! {
        (self.playerViewController as! PlayerViewController).playerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Контроллер представления списка потоков
        let streams = UIViewController()
        // Добавить контроллеры представлений в контейнер
        self.addChildWithDefaultPlayerViewController(
            streamsViewController: streams,
            isPlayerViewControllerPresented: true)
        // Добавить плеер
        self.setupPlayer()
    }
    
    private func setupPlayer() {
        let player = AVPlayer(urlString: URL_TO_STREAM)
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