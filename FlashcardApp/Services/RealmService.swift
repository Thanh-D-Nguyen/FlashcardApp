import RealmSwift
import Foundation

class RealmService {
    private let databaseName = "flash_card.realm"
    private let databaseVersion: UInt64 = 001
    static let shared = RealmService()
    var realm: Realm!
    
    var copyProgress: ((Double) -> Void)?
    
    init() { }
    
    func copyBundleData(completion: @escaping ((URL) -> Void)) {
        let bundlePathString = Bundle.main.path(forResource: databaseName, ofType: nil)!
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
                print("Error: \(error.localizedDescription)")
            }
            
        }
    }
    
    func configuration() {
        print("configuration-----")
        copyBundleData(completion: { [unowned self] url in
            let configuration = Realm.Configuration(fileURL: url,
                                                    schemaVersion: databaseVersion,
                                                    migrationBlock: RealmService.migrate)
            do {
                self.realm = try Realm(configuration: configuration)
                Realm.Configuration.defaultConfiguration = configuration
            } catch {
                fatalError("Database initial error!")
            }
        })
    }
    
    static func migrate(migration: Migration, oldVersion: UInt64) {
        
    }
    
    private func inLibrarayFolder(fileName: String) -> URL {
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0], isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
