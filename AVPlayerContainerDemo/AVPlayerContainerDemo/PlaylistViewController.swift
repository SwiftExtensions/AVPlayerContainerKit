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

 Отображает потоки вещания в таблице с источником данных на снимках
 состояния: изменения структуры плейлиста — скрытие нерабочих потоков,
 появление и исчезновение групп — анимируются автоматически.
 Сервис плейлиста инжектируется владельцем — контейнером плеера, который
 запускает его и передаёт события для отрисовки.
 */
class PlaylistViewController: UITableViewController {
    /**
     Сервис плейлиста.
     */
    private let playlistService: PlaylistService
    /**
     Путь строки последней успешно разрешённой строки в плейлисте.
     */
    private var lastResolvedIndexPath: IndexPath?
    /**
     Сервис изображений.

     Загружает логотипы каналов для ячеек таблицы.
     */
    private let imageService = ImageService()
    /**
     Источник данных таблицы на снимках состояния.

     Секции — индексы групп плейлиста, элементы — пути строк потоков
     в плейлисте.
     */
    private lazy var dataSource = UITableViewDiffableDataSource<Int, IndexPath>(
        tableView: self.tableView
    ) { [weak self] tableView, indexPath, playlistIndexPath in
        let cell = tableView.dequeueReusableCell(
            withIdentifier: StreamCell.reuseIdentifier,
            for: indexPath
        )
        if let streamCell = cell as? StreamCell {
            self?.configure(streamCell, at: playlistIndexPath)
        }

        return cell
    }

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
        self.tableView.register(StreamCell.self, forCellReuseIdentifier: StreamCell.reuseIdentifier)
        self.dataSource.defaultRowAnimation = .fade
    }

    /**
     Отрисовывает событие плейлиста.

     Вызывается владельцем — контейнером плеера.

     - Parameter event: Событие плейлиста.
     */
    func handle(_ event: PlaylistEvent) {
        switch event {
        case .loaded, .playlistChanged:
            self.applySnapshot()
        case let .loadingFailed(error):
            self.showAlert(title: "Ошибка загрузки", message: error.localizedDescription)
        case let .streamChanged(_, indexPath):
            self.refreshVisibleCell(at: indexPath)
        case let .resolvedStream(stream, indexPath):
            self.refreshVisibleCell(at: indexPath)
            switch stream.status {
            case .readyToPlay:
                // выделение и запоминание последней успешной строки — одно действие
                if let displayIndexPath = self.dataSource.indexPath(for: indexPath) {
                    self.tableView.selectRow(at: displayIndexPath, animated: true, scrollPosition: .none)
                }
                self.lastResolvedIndexPath = indexPath
            case .failed(let error):
                self.showErrorAlert(for: stream, error: error)
                // попытка переключения не удалась: выделение возвращается
                // на последнюю успешно разрешённую строку
                if let displayIndexPath = self.dataSource.indexPath(for: indexPath) {
                    self.tableView.deselectRow(at: displayIndexPath, animated: true)
                }
                guard let lastResolvedIndexPath else { return }
                let displayIndexPath = self.dataSource.indexPath(for: lastResolvedIndexPath)
                guard let displayIndexPath else { return }
                
                self.tableView.selectRow(at: displayIndexPath, animated: true, scrollPosition: .none)
            case .unknown, .processing:
                break
            }
        }
    }
    /**
     Применяет к таблице снимок состояния из отображаемых групп плейлиста.
     */
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, IndexPath>()
        for groupSnapshot in self.playlistService.groupSnapshots {
            let section = groupSnapshot.playlistSection
            snapshot.appendSections([section])
            snapshot.appendItems(
                groupSnapshot.playlistRows.map { IndexPath(row: $0, section: section) }
            )
        }
        self.dataSource.apply(snapshot, animatingDifferences: true)
    }
    /**
     Обновляет видимую ячейку потока актуальными данными.

     Ячейка обновляется на месте, без пересоздания: пересоздание через
     `reloadItems` вызывало бы `didEndDisplaying` и отмену собственной
     проверки потока. Невидимая ячейка получит актуальные данные
     в поставщике ячеек при прокрутке.

     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    private func refreshVisibleCell(at indexPath: IndexPath) {
        let displayIndexPath = self.dataSource.indexPath(for: indexPath)
        guard let displayIndexPath else { return }
        let cell = self.tableView.cellForRow(at: displayIndexPath) as? StreamCell
        guard let cell else { return }
        
        let stream = self.playlistService.stream(at: indexPath)
        cell.configure(with: stream)
        self.loadLogo(for: stream, at: indexPath, in: cell)
    }
    /**
     Настраивает ячейку потока актуальными данными.

     - Parameter cell: Ячейка строки.
     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    private func configure(_ cell: StreamCell, at indexPath: IndexPath) {
        let stream = self.playlistService.stream(at: indexPath)
        cell.configure(with: stream)
        self.loadLogo(for: stream, at: indexPath, in: cell)
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header: GroupHeaderView
        let reuseHeader = tableView.dequeueReusableHeaderFooterView(withIdentifier: GroupHeaderView.reuseIdentifier)
        if let groupHeaderView = reuseHeader as? GroupHeaderView {
            header = groupHeaderView
        } else {
            header = GroupHeaderView()
        }
        header.configure(with: self.playlistService.filteredGroups[section])

        return header
    }

    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        guard let storeIndexPath = self.dataSource.itemIdentifier(for: indexPath) else { return }
        self.playlistService.requestValidation(at: storeIndexPath)
    }

    override func tableView(
        _ tableView: UITableView,
        didEndDisplaying cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        guard let storeIndexPath = self.dataSource.itemIdentifier(for: indexPath) else { return }
        self.playlistService.cancelValidation(at: storeIndexPath)
        if let logoURLString = self.playlistService.stream(at: storeIndexPath).attributes["tvg-logo"] {
            self.imageService.cancelLoading(from: logoURLString)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let storeIndexPath = self.dataSource.itemIdentifier(for: indexPath) else { return }
        self.playlistService.resolveStreamStatus(at: storeIndexPath)
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
     - Parameter indexPath: Путь строки потока в плейлисте.
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
            guard let displayIndexPath = self?.tableView.indexPath(for: cell) else { return }
            guard self?.dataSource.itemIdentifier(for: displayIndexPath) == indexPath,
                  self?.tableView.cellForRow(at: displayIndexPath) === cell else { return }
            cell.setLogo(image)
        }
    }


}


