//
//  PlaylistViewController.swift
//  AVPlayerContainerDemo
//
//  Created by Александр Алгашев on 05.10.2026.
//

import AVPlayerKit
import UIKit

/**
 Контроллер плейлиста.

 Отображает потоки вещания в таблице. Сервис плейлиста инжектируется
 владельцем — контейнером плеера, который запускает его и передаёт события
 для отрисовки.
 */
class PlaylistViewController: UITableViewController {
    /**
     Сервис плейлиста.
     */
    private let playlistService: PlaylistService
    /**
     Путь последней успешно разрешённой строки.
     */
    private var lastResolvedIndexPath: IndexPath?
    /**
     Сервис изображений.

     Загружает логотипы каналов для ячеек таблицы.
     */
    private let imageService = ImageService()

    /**
     Создаёт контроллер плейлиста.

     - Parameter service: Сервис плейлиста.
     */
    init(service: PlaylistService) {
        self.playlistService = service
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // убирает системный отступ над заголовками секций
        self.tableView.sectionHeaderTopPadding = 0
    }

    /**
     Отрисовывает событие плейлиста.

     Вызывается владельцем — контейнером плеера.

     - Parameter event: Событие плейлиста.
     */
    func handle(_ event: PlaylistEvent) {
        switch event {
        case .loaded:
            self.tableView.reloadData()
        case let .loadingFailed(error):
            self.showAlert(title: "Ошибка загрузки", message: error.localizedDescription)
        case let .streamChanged(stream, indexPath):
            self.refreshCell(at: indexPath, with: stream)
        case let .resolvedStream(stream, indexPath):
            self.refreshCell(at: indexPath, with: stream)
            switch stream.status {
            case .readyToPlay:
                // выделение и запоминание последней успешной строки — одно действие
                self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                self.lastResolvedIndexPath = indexPath
            case .failed(let error):
                self.showErrorAlert(for: stream, error: error)
                // попытка переключения не удалась: выделение возвращается
                // на последнюю успешно разрешённую строку
                self.tableView.deselectRow(at: indexPath, animated: true)
                guard let indexPath = self.lastResolvedIndexPath else { return }
                self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            case .unknown, .processing:
                break
            }
        }
    }
    /**
     Обновляет содержимое ячейки актуальными данными потока.
     - Parameter indexPath: Путь строки.
     - Parameter stream: Поток вещания.
     */
    private func refreshCell(at indexPath: IndexPath, with stream: Stream) {
        // невидимая ячейка получит актуальные данные в cellForRowAt при прокрутке
        guard let cell = self.tableView.cellForRow(at: indexPath) as? StreamCell else { return }
        cell.configure(with: stream)
        self.loadLogo(for: stream, at: indexPath, in: cell)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        self.playlistService.groups.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.playlistService.groups[section].streams.count
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header: GroupHeaderView
        let reuseHeader = tableView.dequeueReusableHeaderFooterView(withIdentifier: GroupHeaderView.reuseIdentifier)
        if let groupHeaderView = reuseHeader as? GroupHeaderView {
            header = groupHeaderView
        } else {
            header = GroupHeaderView()
        }
        header.configure(with: self.playlistService.groups[section])

        return header
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let stream = self.playlistService.stream(at: indexPath)
        let cell: StreamCell
        let reuseCell = tableView.dequeueReusableCell(withIdentifier: StreamCell.reuseIdentifier)
        if let streamCell = reuseCell as? StreamCell {
            cell = streamCell
        } else {
            cell = StreamCell(style: .default, reuseIdentifier: StreamCell.reuseIdentifier)
        }
        cell.configure(with: stream)
        self.loadLogo(for: stream, at: indexPath, in: cell)

        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        self.playlistService.requestValidation(at: indexPath)
    }

    override func tableView(
        _ tableView: UITableView,
        didEndDisplaying cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        self.playlistService.cancelValidation(at: indexPath)
        if let logoURLString = self.playlistService.stream(at: indexPath).attributes["tvg-logo"] {
            self.imageService.cancelLoading(from: logoURLString)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.playlistService.resolveStreamStatus(at: indexPath)
    }
    /**
     Показывает пользователю предупреждение.

     - Parameter title: Заголовок предупреждения.
     - Parameter message: Текст предупреждения.
     */
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    /**
     Показывает пользователю предупреждение с описанием ошибки.

     - Parameter stream: Поток вещания с ошибкой.
     - Parameter error: Ошибка.
     */
    private func showErrorAlert(for stream: Stream, error: Error) {
        self.showAlert(
            title: "Ошибка потока",
            message: "\(stream.title)\n\n\(error.localizedDescription)"
        )
    }
    /**
     Загружает логотип канала и отображает его в ячейке.

     Загрузку выполняет сервис изображений. Ячейка может быть
     переиспользована, пока логотип загружается: изображение применяется,
     только если строка всё ещё показывает тот же поток. Ошибка загрузки
     логотипа не влияет на отображение строки.

     - Parameter stream: Поток вещания.
     - Parameter indexPath: Индекс строки.
     - Parameter cell: Ячейка строки.
     */
    private func loadLogo(for stream: Stream, at indexPath: IndexPath, in cell: StreamCell) {
        guard let logoURLString = stream.attributes["tvg-logo"] else {
            cell.setLogo(nil)
            return
        }
        self.imageService.loadImage(from: logoURLString) { [weak self] result in
            guard case .success(let image) = result else { return }
            // строка могла быть переиспользована под другой поток
            guard self?.playlistService.stream(at: indexPath).attributes["tvg-logo"] == logoURLString,
                  self?.tableView.cellForRow(at: indexPath) === cell else { return }
            cell.setLogo(image)
        }
    }


}
