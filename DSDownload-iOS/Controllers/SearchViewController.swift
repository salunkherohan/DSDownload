//
//  SearchViewController.swift
//  DSDownload-iOS
//
//  Created by Thomas Brichart on 25/04/2020.
//

import Foundation
import RealmSwift
import RxSwift
import RxCocoa
import RxRealm

class SearchViewController: UITableViewController {
    
    let searchController = UISearchController(searchResultsController: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search torrent"
        searchController.searchBar.delegate = self
        
        
        navigationItem.searchController = searchController
        definesPresentationContext = true
        
        configureObservers()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showResultDetails" {
            guard let destinationNav = segue.destination as? UINavigationController else { return }
            guard let destination = destinationNav.viewControllers.first as? SearchDetailsViewController else { return }
            guard let cell = sender as? UITableViewCell else { return }
            guard let cellIndex = self.tableView?.indexPath(for: cell) else { return }
            
            destination.itemID = items[cellIndex.row].result_id
        }
    }
    
    // MARK: Private
    
    private let dataManager = DBManager.shared
    private let sessionManager = SessionManager.shared
    private let searchManager = SearchManager.shared
    
    private let disposeBag = DisposeBag()
    
    private var items: [Item] {
        return dataManager.realmContent.objects(Item.self).sorted(by: { $0.peers > $1.peers })
    }
    
    private func configureObservers() {
        // Session observer
        sessionManager.state.subscribe(onNext: { [weak self] _ in
            DispatchQueue.main.async {
                self?.sessionDidChange()
            }
        }).disposed(by: disposeBag)
        
        // Search manager state observer
        searchManager.state.subscribe(onNext: { [weak self] _ in
            DispatchQueue.main.async {
                self?.tableView?.reloadData()
            }
        }).disposed(by: disposeBag)
        
        // Tasks observer
        Observable.changeset(from: dataManager.realmContent.objects(Item.self)).subscribe(onNext: { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.tableView?.reloadData()
            }
        }).disposed(by: disposeBag)
    }
    
    private func sessionDidChange() {
        guard sessionManager.state.value == SessionManager.State.notConnected.rawValue else { return }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Loading
    
    private func startLoading() {
        if let selectedRowIndex = tableView?.indexPathForSelectedRow {
            tableView?.deselectRow(at: selectedRowIndex, animated: true)
        }
        
        tableView?.isUserInteractionEnabled = false
    }
    
    private func endLoading() {
        tableView?.isUserInteractionEnabled = true
    }
    
    private func add(magnet: String) {
        startLoading()
        
        if !magnet.hasPrefix("magnet:") {
            showErrorMessage("Magnet link format error")
            endLoading()
        } else {
            let taskManager = TaskManager.shared
            
            taskManager.add(magnet) { [weak self] (result) in
                DispatchQueue.main.async {
                    self?.endLoading()
                    
                    guard !result else {
                        self?.dismiss(animated: true, completion: nil)
                        return
                    }
                    
                    self?.showErrorMessage("An error occurred")
                }
            }
        }
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let keyword = searchController.searchBar.text else { return }
        
        let searchManager = SearchManager.shared
        
        searchManager.search(keyword)
    }
}

extension SearchViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        
        let identifier = "searchCell"
        
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) ?? UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateFormatter.timeZone = .current
        
        cell.textLabel?.text = item.title
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = "\(Tools.prettyPrintNumber(item.size))b - S/L: \(item.peers)/\(item.leechs) - \(dateFormatter.string(from: item.date))"
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(gestureRecognizer:)))
        cell.addGestureRecognizer(longPressGesture)
        
        return cell
    }
    
    @objc func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        let actionSheet = UIAlertController(title: nil, message: "Choose action", preferredStyle: .actionSheet)
        
        let addAction = UIAlertAction(title: "Add to tasks", style: .default, handler: { [weak self] _ in
            if let cell = gestureRecognizer.view as? UITableViewCell {
                guard let indexPath = self?.tableView.indexPath(for: cell) else { return }
                guard let item = self?.items[indexPath.row] else { return }
                
                self?.add(magnet: item.dlurl)
            }
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            actionSheet.dismiss(animated: true, completion: nil)
        })
        
        actionSheet.addAction(addAction)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch searchManager.state.value {
        case SearchManager.State.searchRunning.rawValue:
            return "Search in progress"
        case SearchManager.State.searchFinished.rawValue:
            return "Search finished"
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "showResultDetails", sender: tableView.cellForRow(at: indexPath))
    }
}
