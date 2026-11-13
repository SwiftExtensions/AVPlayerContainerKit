//
//  PlayerContainerViewController.swift
//  AVPlayerContainerDemo
//
//  Created by Лайм HD on 04.08.2022.
//

import AVKit
import UIKit
import AVPlayerKit
import AVPlayerContainerKit

/**
 Контейнер плеера.

 Точка сборки приложения: владеет сервисом плейлиста, запускает его
 и раздаёт его события детям — контроллеру плейлиста для отрисовки
 и плееру для воспроизведения.
 */
final class PlayerContainerViewController: AVPlayerContainerViewController<PlayerViewController> {
    /**
     Сервис плейлиста.
     */
    private let playlistService = PlaylistService()
    /**
     Контроллер плейлиста.
     */
    private weak var playlistViewController: PlaylistViewController?
    /**
     Путь строки воспроизводимого в данный момент потока.
     */
    private var currentStreamIndexPath: IndexPath?
    /**
     Текущий поток запущен автозапуском, а не выбором пользователя.

     При ошибке воспроизведения автозапущенный поток заменяется следующим
     готовым к воспроизведению.
     */
    private var isAutoplayedStream = false
    /**
     Воспроизведение текущего потока завершилось ошибкой.

     Пока ошибка не заменена новым потоком, автозапуск продолжается:
     ставший готовым к воспроизведению поток запускается автоматически.
     */
    private var isCurrentStreamFailed = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .playlistBackground
        let playlistViewController = PlaylistViewController(service: self.playlistService)
        self.playlistViewController = playlistViewController
        playlistViewController.view.backgroundColor = .playlistBackground
        self.addChildWithDefaultPlayerViewController(
            secondaryViewController: playlistViewController,
            isPlayerViewControllerPresented: false
        )
        self.playerViewController.playerView.player = AVPlayer()
        self.playerViewController.playbackErrorDelegate = self
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
        self.startPlaylist()
    }

    // MARK: - Actions

    /**
     Открывает настройки модально.

     Настройки — вспомогательный экран: презентация вместо push сохраняет
     историю навигации, а `formSheet` на планшетах показывает форму
     центрированной карточкой.
     */
    @objc private func showSettings() {
        let controller = UINavigationController(
            rootViewController: SettingsViewController(service: self.playlistService)
        )
        controller.modalPresentationStyle = .formSheet
        self.present(controller, animated: true)
    }
    /**
     Запускает работу сервиса плейлиста и наблюдение за его событиями.
     */
    private func startPlaylist() {
        let playlistURLString = "https://iptv-org.github.io/iptv/languages/rus.m3u"
        let url = URL(string: playlistURLString)!
        // подписка на события раньше старта, чтобы не потерять первые события
        self.observePlaylistEvents()
        self.playlistService.start(url: url)
    }
    /**
     Запускает наблюдение за событиями плейлиста и раздаёт их по назначению.
     */
    private func observePlaylistEvents() {
        Task { [weak self] in
            guard let events = self?.playlistService.events else { return }
            for await event in events {
                self?.handle(event)
            }
        }
    }
    /**
     Обрабатывает событие плейлиста.

     Отрисовку выполняет контроллер плейлиста. Готовый к воспроизведению
     запрошенный поток запускается в плеере.

     - Parameter event: Событие плейлиста.
     */
    private func handle(_ event: PlaylistEvent) {
        // отрисовку выполняет контроллер плейлиста
        self.playlistViewController?.handle(event)
        switch event {
        case .loaded, .loadingFailed, .playlistChanged:
            let count = self.playlistService.groups.reduce(0) { $0 + $1.streams.count }
            self.title = count > 0
            ? "Player Container Demo (\(count))"
            : "Player Container Demo"
        case let .resolvedStream(stream, indexPath):
            guard case .readyToPlay = stream.status else { return }
            // поток запущен выбором пользователя: автозапуск завершён
            self.isAutoplayedStream = false
            if self.isPlayerPresented {
                self.play(stream: stream, at: indexPath)
            } else {
                self.updatePlayerState(isPlayerPresented: true) {
                    self.play(stream: stream, at: indexPath)
                }
            }
        case let .streamChanged(stream, indexPath):
            // готовый к воспроизведению поток запускается автоматически,
            // пока плеер не показан или текущий поток завершился ошибкой
            guard case .readyToPlay = stream.status else { return }
            if self.isPlayerPresented, !self.isCurrentStreamFailed { return }
            self.autoplay(stream: stream, at: indexPath)
        }
    }
    /**
     Запускает автозапуск потока.

     Поток запускается в плеере и разрешается контроллеру плейлиста
     событием для выделения строки.

     - Parameter stream: Поток вещания.
     - Parameter indexPath: Путь строки потока.
     */
    private func autoplay(stream: Stream, at indexPath: IndexPath) {
        self.isAutoplayedStream = true
        if self.isPlayerPresented {
            self.play(stream: stream, at: indexPath)
        } else {
            self.updatePlayerState(isPlayerPresented: true) {
                self.play(stream: stream, at: indexPath)
            }
        }
        // автозапущенный поток разрешён: контроллеру плейлиста
        // передаётся дополнительное событие разрешения
        let event = PlaylistEvent.resolvedStream(stream, indexPath: indexPath)
        self.playlistViewController?.handle(event)
    }
    /**
     Запускает воспроизведение потока.

     Путь строки запоминается: по нему поток помечается ошибкой,
     если воспроизведение не удастся.

     - Parameter stream: Поток вещания.
     - Parameter indexPath: Путь строки потока.
     */
    private func play(stream: Stream, at indexPath: IndexPath) {
        print("Playing stream: \(stream)")
        self.currentStreamIndexPath = indexPath
        self.isCurrentStreamFailed = false
        self.playerViewController.player?.replaceCurrentItem(with: stream.url)
        self.playerViewController.player?.play()
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

// MARK: - PlayerViewController.PlaybackErrorDelegate

extension PlayerContainerViewController: PlayerViewController.PlaybackErrorDelegate {
    func playerViewController(
        _ playerViewController: PlayerViewController,
        player: AVPlayer,
        didFailWith error: (any Error)?
    ) {
        self.handlePlaybackError(error)
    }
    func playerViewController(
        _ playerViewController: PlayerViewController,
        playerItem: AVPlayerItem,
        didFailWith error: (any Error)?
    ) {
        self.handlePlaybackError(error)
    }
    /**
     Обрабатывает ошибку воспроизведения текущего потока.

     Обработка переносится на главный поток: наблюдение за плеером может
     сообщить об ошибке из любого потока.

     Автозапущенный поток помечается ошибкой и заменяется ближайшим готовым
     к воспроизведению следующим за ним. Для потока, запущенного выбором
     пользователя, сообщается только ошибка.

     - Parameter error: Ошибка воспроизведения. `nil`, если система
       не сообщила причину.
     */
    private func handlePlaybackError(_ error: (any Error)?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let indexPath = self.currentStreamIndexPath else { return }
            self.isCurrentStreamFailed = true
            self.playlistService.streamPlaybackFailed(error, at: indexPath)
            // автозапущенный поток заменяется ближайшим готовым среди видимых
            // строк; если готовых нет, замена найдётся при прокрутке списка
            guard self.isAutoplayedStream else { return }
            let visibleIndexPaths = self.playlistViewController?.visiblePlaylistIndexPaths ?? []
            guard let next = self.nextReadyStream(after: indexPath, among: visibleIndexPaths)
            else { return }
            self.autoplay(stream: next.stream, at: next.indexPath)
        }
    }


}

extension UINavigationController {
    open override var childForHomeIndicatorAutoHidden: UIViewController? {
        self.topViewController
    }
    
    
}
