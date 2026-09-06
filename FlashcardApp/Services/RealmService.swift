import RealmSwift
import Foundation

class RealmService {
    private let databaseName = "flash_card.realm"
    private let databaseVersion: UInt64 = 001
    static let shared = RealmService()
    var realm: Realm!
    
    var copyProgress: ((Double) -> Void)?
    
    init() { }
    
    func copyBundleData(completion: @escaping ((URL) -> Void), onError: ((AppError) -> Void)? = nil) {
        guard let bundlePathString = Bundle.main.path(forResource: databaseName, ofType: nil) else {
            logger.error("Bundle database file not found")
            onError?(.databaseInitializationFailed("Bundle database file not found"))
            return
        }
        let sourcePath = URL(fileURLWithPath: bundlePathString)
        let destinationUrl = inLibrarayFolder(fileName: databaseName)
        print(destinationUrl)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationUrl.path) {
            completion(destinationUrl)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.copyProgress?(100.0)
            }
            return
        }
        DispatchQueue.global(qos: .background).async {
            do {
                let sourceData = try Data(contentsOf: sourcePath)
                let sourceSize = sourceData.count
                let progress = Progress(totalUnitCount: Int64(sourceSize))
                let bufferSize = 1024 * 1024
                var copiedSize: Int = 0
                if !fileManager.fileExists(atPath: destinationUrl.path) {
                    let created = fileManager.createFile(atPath: destinationUrl.path, contents: nil, attributes: nil)
                    if !created {
                        throw NSError(domain: "FileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not create file at path \(destinationUrl.path)"])
                    }
                }
                let fileHandle = try FileHandle(forReadingFrom: sourcePath)
                let destinationHandle = try FileHandle(forWritingTo: destinationUrl)
                defer {
                    fileHandle.closeFile()
                    destinationHandle.closeFile()
                }
                while copiedSize < sourceSize {
                    let bytesToCopy = min(bufferSize, sourceSize - copiedSize)
                    let data = fileHandle.readData(ofLength: bytesToCopy)
                    destinationHandle.write(data)
                    copiedSize += bytesToCopy
                    progress.completedUnitCount = Int64(copiedSize)
                    let progressPercentage = progress.fractionCompleted * 100.0
                    DispatchQueue.main.async {
                        self.copyProgress?(progressPercentage)
                        if progressPercentage >= 100.0 {
                            completion(destinationUrl)
                        }
                    }
                }
            } catch let error {
                logger.error("Error copying bundle data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    onError?(.databaseInitializationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func configuration(onError: ((AppError) -> Void)? = nil) {
        logger.debug("configuration-----")
        copyBundleData(completion: { [unowned self] url in
            let configuration = Realm.Configuration(fileURL: url,
                                                    schemaVersion: databaseVersion,
                                                    migrationBlock: RealmService.migrate)
            do {
                self.realm = try Realm(configuration: configuration)
                Realm.Configuration.defaultConfiguration = configuration
            } catch {
                logger.error("Database initial error: \(error.localizedDescription)")
                onError?(.databaseInitializationFailed(error.localizedDescription))
            }
        }, onError: onError)
    }
    
    static func migrate(migration: Migration, oldVersion: UInt64) {
        
    }
    
    private func inLibrarayFolder(fileName: String) -> URL {
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0], isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
