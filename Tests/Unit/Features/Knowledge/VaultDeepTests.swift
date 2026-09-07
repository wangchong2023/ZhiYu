//
//  VaultDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：VaultLifecycleAndSwitchingTests.swift, VaultLifecycleManagerTests.swift
//

import Dependencies
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class VaultDeepTests: XCTestCase {

    private var service: VaultService!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        service = VaultService.shared
        service.vaults.removeAll()
        service.selectedVaultID = nil
    }

    override func tearDown() async throws {
        service.vaults.removeAll()
        service.selectedVaultID = nil
        service = nil
        try await super.tearDown()
    }

    func firstVault() -> Vault {
        guard let vault = service.vaults.first else {
            XCTFail("vaults 不应为空")
            return Vault(id: UUID(), name: "", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        }
        return vault
    }

    func testSelectVault_UpdatesSelectedVaultIDAndPostsNotification() {
        let service = VaultService.shared
        let vault = Vault(
            id: UUID(),
            name: "个人知识库",
            createdAt: Date(),
            updatedAt: Date(),
            pageCount: 5,
            icon: "📚"
        )

        let exp = expectation(forNotification: .vaultWillSwitch, object: nil, handler: nil)

        service.selectVault(vault)

        XCTAssertEqual(service.selectedVaultID, vault.id, "选中的保险库 ID 应当被即时更新")
        wait(for: [exp], timeout: 1.0)
    }

    func testExitVault_ClearsSelectionAndReleasesConnection() {
        let service = VaultService.shared
        service.selectedVaultID = UUID()

        let exp = expectation(forNotification: .vaultWillSwitch, object: nil, handler: nil)

        service.exitVault()

        XCTAssertNil(service.selectedVaultID, "退出后选中的保险库 ID 应当为 nil")
        wait(for: [exp], timeout: 1.0)
    }

    func testCreateVault_AppendsNewVaultToList() {
        let service = VaultService.shared
        let initialCount = service.vaults.count

        service.createVault(name: "调研笔记本", icon: "🔬", description: "项目调研资料")

        XCTAssertEqual(service.vaults.count, initialCount + 1, "创建后保险库列表应当自增")
        XCTAssertTrue(service.vaults.contains(where: { $0.name == "调研笔记本" }))
    }

    func testDeleteCurrentVault_PostsVaultWillSwitchNotification() {
        let service = VaultService.shared
        let vaultID = UUID()
        let vault = Vault(id: vaultID, name: "临时保险库", createdAt: Date(), updatedAt: Date(), pageCount: 0)
        service.vaults.append(vault)
        service.selectedVaultID = vaultID

        let exp = expectation(forNotification: .vaultWillSwitch, object: nil, handler: nil)

        service.deleteVault(id: vaultID)

        XCTAssertNil(service.selectedVaultID, "删除当前选中保险库后 selectedVaultID 应为 nil")
        wait(for: [exp], timeout: 1.0)
    }

    func testCreateVaultAppendsToList() {
        service.createVault(name: "新笔记本", icon: "book", description: "描述")
        XCTAssertEqual(service.vaults.count, 1)
        XCTAssertEqual(service.vaults.first?.name, "新笔记本")
    }

    func testCreateVaultGeneratesUniqueID() {
        service.createVault(name: "A")
        service.createVault(name: "B")
        XCTAssertNotEqual(service.vaults[0].id, service.vaults[1].id)
    }

    func testCreateVaultDefaultIconDescriptionNil() {
        service.createVault(name: "默认")
        XCTAssertNil(service.vaults.first?.icon)
        XCTAssertNil(service.vaults.first?.description)
    }

    func testCreateVaultPageCountZero() {
        service.createVault(name: "空本")
        XCTAssertEqual(service.vaults.first?.pageCount, 0)
    }

    func testCreateVaultSetsSeededFlag() {
        service.createVault(name: "标记测试")
        let id = firstVault().id
        let key = "\(AppConstants.Keys.Storage.seededVaultPrefix)\(id.uuidString)"
        // P2-1 迁移：从 DI 容器获取隔离的 KeyStore 实例检查值，而非 UserDefaults.standard
        let keyStore = ServiceContainer.shared.resolve((any KeyStoreProtocol).self)
        XCTAssertTrue(keyStore.bool(forKey: key), "createVault 应设置 seeded 标记")
    }

    func testUpdateVaultUpdatesFields() {
        service.createVault(name: "原名", icon: "old", description: "旧描述")
        let id = firstVault().id

        service.updateVault(id: id, name: "新名", icon: "new", description: "新描述")

        let updated = service.vaults.first { $0.id == id }
        XCTAssertEqual(updated?.name, "新名")
        XCTAssertEqual(updated?.icon, "new")
        XCTAssertEqual(updated?.description, "新描述")
    }

    func testUpdateVaultUpdatesTimestamp() {
        service.createVault(name: "时间测试")
        let id = firstVault().id
        let originalUpdatedAt = firstVault().updatedAt

        // 等待一小段时间确保时间戳不同
        Thread.sleep(forTimeInterval: 0.01)
        service.updateVault(id: id, name: "更新", icon: nil, description: nil)

        let updated = service.vaults.first { $0.id == id }
        guard let updated = service.vaults.first(where: { $0.id == id }) else {
            XCTFail("未找到更新后的 vault")
            return
        }
        XCTAssertGreaterThan(updated.updatedAt, originalUpdatedAt)
    }

    func testUpdateVaultNonExistentIDNoCrash() {
        service.updateVault(id: UUID(), name: "不存在", icon: nil, description: nil)
        XCTAssertTrue(service.vaults.isEmpty)
    }

    func testRenameVaultUpdatesName() {
        service.createVault(name: "旧名", icon: "icon", description: "desc")
        let id = firstVault().id

        service.renameVault(id: id, newName: "新名")

        let renamed = service.vaults.first { $0.id == id }
        XCTAssertEqual(renamed?.name, "新名")
        // icon/description 不变
        XCTAssertEqual(renamed?.icon, "icon")
        XCTAssertEqual(renamed?.description, "desc")
    }

    func testRenameVaultNonExistentIDNoCrash() {
        service.renameVault(id: UUID(), newName: "不存在")
        XCTAssertTrue(service.vaults.isEmpty)
    }

    func testSelectVaultSetsSelectedID() {
        service.createVault(name: "选中测试")
        let vault = firstVault()

        service.selectVault(vault)

        XCTAssertEqual(service.selectedVaultID, vault.id)
    }

    func testExitVaultClearsSelectedID() {
        service.createVault(name: "退出测试")
        let vault = firstVault()
        service.selectVault(vault)
        XCTAssertEqual(service.selectedVaultID, vault.id)

        service.exitVault()

        XCTAssertNil(service.selectedVaultID)
    }

    func testDeleteVaultRemovesFromList() {
        service.createVault(name: "待删")
        let id = firstVault().id

        service.deleteVault(id: id)

        XCTAssertTrue(service.vaults.isEmpty)
    }

    func testDeleteVaultClearsSelectedWhenDeletingSelected() {
        service.createVault(name: "选中待删")
        let vault = firstVault()
        service.selectVault(vault)
        XCTAssertEqual(service.selectedVaultID, vault.id)

        service.deleteVault(id: vault.id)

        XCTAssertNil(service.selectedVaultID)
    }

    func testDeleteVaultKeepsSelectedWhenDeletingOther() {
        service.createVault(name: "A")
        service.createVault(name: "B")
        let a = service.vaults[0]
        let b = service.vaults[1]
        service.selectVault(a)

        service.deleteVault(id: b.id)

        XCTAssertEqual(service.selectedVaultID, a.id)
        XCTAssertEqual(service.vaults.count, 1)
    }

    func testDeleteVaultNonExistentIDNoCrash() {
        service.deleteVault(id: UUID())
        XCTAssertTrue(service.vaults.isEmpty)
    }

}
