//
//  AsyncOperation.swift
//  DSDownload
//
//  Created by Thomas LE GRAVIER on 17/10/2019.
//

import Foundation

class AsyncOperation<T: Decodable>: Operation {
    
    enum Result<T> {
        case success(T)
        case failure(ResultError)
    }
    
    enum ResultError: Error {
        case requestError
        case other(String)
    }
    
    let delay: TimeInterval
    
    override var isAsynchronous: Bool { return true }
    override var isExecuting: Bool { return state == .executing }
    override var isFinished: Bool { return state == .finished }
    
    private(set) var result: Result<T>? {
        didSet {
            guard result != nil else {return}
            state = .finished
        }
    }
    
    private var state = State.ready {
        willSet {
            willChangeValue(forKey: state.keyPath)
            willChangeValue(forKey: newValue.keyPath)
        }
        didSet {
            didChangeValue(forKey: state.keyPath)
            didChangeValue(forKey: oldValue.keyPath)
        }
    }
    
    enum State: String {
        case ready = "Ready"
        case executing = "Executing"
        case finished = "Finished"
        fileprivate var keyPath: String { return "is" + self.rawValue }
    }
    
    init(delay: TimeInterval? = nil) {
        self.delay = delay ?? 0
    }
    
    override func start() {
        if isCancelled {
            state = .finished
        } else {
            state = .ready
            main()
        }
    }
    
    override func main() {
        if isCancelled {
            state = .finished
        } else {
            state = .executing
            let queue = DispatchQueue(label: "com.asyncOperation")
            queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.blockOperation?({
                    self?.result = $0
                })
            }
        }
    }
    
    override func cancel() {
        blockOperation = nil
        state = .finished
    }
    
    func setBlockOperation(_ operation: @escaping (_ endHandler: @escaping (_ result: Result<T>?) -> Void) -> Void) {
        blockOperation = operation
    }
    
    /* Mark: Private */
    
    private var blockOperation: ((_ endHandler: @escaping (_ result: Result<T>?) -> Void) -> Void)?

}
