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
 и раздаёт его события детям — контроллеру плейлиста для отрисовки,
 политике воспроизведения и плееру.
 */
final class PlayerContainerViewController: AVPlayerContainerViewController<PlayerViewController> {
    /**
     Сервис плейлиста.
     */
    private let playlistService = PlaylistService()
    /**
     Сервис изображений для загрузки логотипов каналов.
     */
    private let imageService = ImageService()
    /**
     Оверлей переключения канала поверх плеера.
     */
    private let channelOverlayView = ChannelOverlayView()
    /**
     Контроллер плейлиста.
     */
    private weak var playlistViewController: PlaylistViewController?
    /**
     Политика воспроизведения плейлиста.
     */
    private lazy var playbackService = PlaybackService(
        playlistService: self.playlistService,
        play: { [weak self] stream, indexPath in
            self?.startPlayback(stream: stream, at: indexPath)
        },
        visibleIndexPaths: { [weak self] in
            self?.playlistViewController?.visiblePlaylistIndexPaths ?? []
        },
        resolve: { [weak self] event in
            self?.playlistViewController?.handle(event)
        }
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .playlistBackground
        let playlistViewController = PlaylistViewController(service: self.playlistService)
        self.playlistViewController = playlistViewController
        playlistViewController.view.backgroundColor = .playlistBackground
        playlistViewController.onStreamFailureDismissed = { [weak self] indexPath in
            self?.playbackService.streamFailureDismissed(at: indexPath)
        }
        self.addChildWithDefaultPlayerViewController(
            secondaryViewController: playlistViewController,
            isPlayerViewControllerPresented: false
        )
        self.playerViewController.playerView.player = AVPlayer()
        self.playerViewController.playbackErrorDelegate = self
        self.setupChannelOverlayView()
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

     Отрисовку выполняет контроллер плейлиста, воспроизведением управляет
     политика воспроизведения.

     - Parameter event: Событие плейлиста.
     */
    /**
     Обрабатывает событие сервиса плейлиста.

     Отрисовку выполняет контроллер плейлиста, воспроизведением управляет
     сервис воспроизведения.

     - Parameter event: Событие сервиса плейлиста.
     */
    private func handle(_ event: PlaylistServiceEvent) {
        switch event {
        case let .playlist(playlistEvent):
            // отрисовку выполняет контроллер плейлиста
            self.playlistViewController?.handle(playlistEvent)
            self.updateTitle()
        case let .stream(streamEvent):
            // отрисовку выполняет контроллер плейлиста,
            // воспроизведением управляет сервис воспроизведения
            self.playlistViewController?.handle(streamEvent)
            self.playbackService.handle(streamEvent)
        }
    }
    /**
     Обновляет заголовок с количеством доступных потоков.

     Считаются видимые (отфильтрованные) группы. Изменение выполняется
     плавным переходом.
     */
    private func updateTitle() {
        let count = self.playlistService.filteredGroups.reduce(0) { $0 + $1.streams.count }
        let title = count > 0 ? "Player Container Demo (\(count))" : "Player Container Demo"
        guard self.title != title else { return }
        let navigationBar = self.navigationController?.navigationBar
        guard let navigationBar else {
            self.title = title
            return
        }

        UIView.transition(
            with: navigationBar,
            duration: 0.25,
            options: [.transitionCrossDissolve, .beginFromCurrentState],
            animations: { self.title = title }
        )
    }
    /**
     Запускает воспроизведение потока.

     Если плеер не показан, сначала показывает его.

     - Parameter stream: Поток вещания.
     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    private func startPlayback(stream: Stream, at indexPath: IndexPath) {
        print("\(Self.self).\(#function)+\(#line) Playing stream: \(stream)")
        if self.isPlayerPresented {
            self.performPlayback(stream: stream, at: indexPath)
            return
        }
        
        self.updatePlayerState(isPlayerPresented: true) {
            self.performPlayback(stream: stream, at: indexPath)
        }
    }
    /**
     Запускает воспроизведение потока в плеере.
     - Parameter stream: Поток вещания.
     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    private func performPlayback(stream: Stream, at indexPath: IndexPath) {
        self.playerViewController.player?.replaceCurrentItem(with: stream.url)
        self.playerViewController.player?.play()
        self.showChannelOverlay(for: stream)
    }
    /**
     Добавляет оверлей переключения канала по центру вью плеера.
     */
    private func setupChannelOverlayView() {
        let overlayView = self.channelOverlayView
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        let playerView = self.playerViewController.view!
        playerView.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.centerXAnchor.constraint(equalTo: playerView.centerXAnchor),
            overlayView.centerYAnchor.constraint(equalTo: playerView.centerYAnchor),
            overlayView.widthAnchor.constraint(
                lessThanOrEqualTo: playerView.widthAnchor,
                multiplier: 0.8
            )
        ])
    }
    /**
     Показывает оверлей переключения канала.

     Название отображается сразу. Логотип загружается по адресу
     из атрибута `tvg-logo` и добавляется, когда придёт из сети.

     - Parameter stream: Поток вещания, переключённый на воспроизведение.
     */
    private func showChannelOverlay(for stream: Stream) {
        self.channelOverlayView.show(stream: stream)
        guard let logoURLString = stream.attributes["tvg-logo"] else { return }
        self.imageService.loadImage(from: logoURLString) { [weak self] result in
            guard case .success(let image) = result else { return }
            self?.channelOverlayView.setLogo(image, for: stream.url)
        }
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

     - Parameter error: Ошибка воспроизведения. `nil`, если система
       не сообщила причину.
     */
    private func handlePlaybackError(_ error: (any Error)?) {
        DispatchQueue.main.async { [weak self] in
            self?.playbackService.streamPlaybackFailed(error)
        }
    }


}

extension UINavigationController {
    open override var childForHomeIndicatorAutoHidden: UIViewController? {
        self.topViewController
    }


}
