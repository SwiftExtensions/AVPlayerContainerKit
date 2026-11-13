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
     Пути строк видимых ячеек в плейлисте, в порядке отображения сверху вниз.
     */
    var visiblePlaylistIndexPaths: [IndexPath] {
        self.dataSource.normalized(self.indexPathsForVisibleRows).sorted()
    }
    
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
     Пути строк видимых ячеек в таблице.
     */
    private var indexPathsForVisibleRows: [IndexPath] {
        self.tableView.indexPathsForVisibleRows ?? []
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
        // выделение играющего потока сохраняется при возврате с других экранов
        self.clearsSelectionOnViewWillAppear = false
        self.tableView.register(StreamCell.self, forCellReuseIdentifier: StreamCell.reuseIdentifier)
        self.tableView.register(
            GroupHeaderView.self,
            forHeaderFooterViewReuseIdentifier: GroupHeaderView.reuseIdentifier
        )
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
        case let .streamChanged(stream, indexPath):
            self.refreshVisibleCell(at: indexPath)
            // отмена проверки делает поток непроверенным: если его строка
            // всё ещё видима, запрос проверки возобновляется
            if case .unknown = stream.status {
                self.requestValidationIfVisible(at: indexPath)
            }
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
        self.refreshVisibleHeaders()
        // строки, вошедшие в экран из-за изменения структуры, могли не получить
        // запросов на проверку — возобновляем их для всех видимых строк
        for playlistIndexPath in self.dataSource.normalized(self.indexPathsForVisibleRows) {
            self.playlistService.requestValidation(at: playlistIndexPath)
        }
    }
    /**
     Обновляет заголовки видимых секций актуальными группами.

     Вызывается после изменения структуры таблицы: количество потоков
     в заголовках групп могло измениться.
     */
    private func refreshVisibleHeaders() {
        let sections = Set(self.indexPathsForVisibleRows.map { $0.section })
        for displaySection in sections {
            guard let header = self.tableView.headerView(forSection: displaySection) as? GroupHeaderView
            else { continue }
            header.configure(with: self.playlistService.filteredGroups[displaySection])
        }
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
     Запрашивает проверку потока, если его строка видима в таблице.

     - Parameter indexPath: Путь строки потока в плейлисте.
     */
    private func requestValidationIfVisible(at indexPath: IndexPath) {
        let displayIndexPath = self.dataSource.indexPath(for: indexPath)
        let indexPathsForVisibleRows = self.indexPathsForVisibleRows
        guard let displayIndexPath,
              indexPathsForVisibleRows.contains(displayIndexPath)
        else { return }

        self.playlistService.requestValidation(at: indexPath)
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
        let header = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: GroupHeaderView.reuseIdentifier
        )
        guard let groupHeaderView = header as? GroupHeaderView else { return nil }
        groupHeaderView.configure(with: self.playlistService.filteredGroups[section])

        return groupHeaderView
    }

    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        guard let playlistIndexPath = self.dataSource.normalized(indexPath) else { return }
        self.playlistService.requestValidation(at: playlistIndexPath)
    }

    override func tableView(
        _ tableView: UITableView,
        didEndDisplaying cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        guard let playlistIndexPath = self.dataSource.normalized(indexPath) else { return }
        self.playlistService.cancelValidation(at: playlistIndexPath)
        if let logoURLString = self.playlistService.stream(at: playlistIndexPath).attributes["tvg-logo"] {
            self.imageService.cancelLoading(from: logoURLString)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let playlistIndexPath = self.dataSource.normalized(indexPath) else { return }
        self.playlistService.resolveStreamStatus(at: playlistIndexPath)
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
            guard self?.dataSource.normalized(displayIndexPath) == indexPath,
                  self?.tableView.cellForRow(at: displayIndexPath) === cell else { return }
            cell.setLogo(image)
        }
    }


}

// MARK: - UITableViewDiffableDataSource

extension UITableViewDiffableDataSource where SectionIdentifierType == Int, ItemIdentifierType == IndexPath {
    /**
     Приводит путь строки таблицы к идентификатору элемента.

     Идентификатор элемента — путь строки в плейлисте. `nil`, если путь строки
     не соответствует элементу.

     - Parameter indexPath: Путь строки в таблице.
     - Returns: Идентификатор элемента.
     */
    func normalized(_ indexPath: IndexPath) -> IndexPath? {
        self.itemIdentifier(for: indexPath)
    }
    /**
     Приводит пути строк таблицы к идентификаторам элементов.

     Идентификаторы элементов — пути строк в плейлисте. Пути строк, не
     соответствующие элементам, отбрасываются.

     - Parameter indexPaths: Пути строк в таблице.
     - Returns: Идентификаторы элементов.
     */
    func normalized(_ indexPaths: [IndexPath]) -> [IndexPath] {
        indexPaths.compactMap { self.itemIdentifier(for: $0) }
    }


}


