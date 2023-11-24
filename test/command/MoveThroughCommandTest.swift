import XCTest
@testable import AeroSpace_Debug

final class MoveThroughCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testMove_swapWindows() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).nativeFocus()
            TestWindow(id: 2, parent: $0)
        }

        MoveThroughCommand(direction: .right).testRun()
        XCTAssertEqual(root.layoutDescription, .h_tiles([.window(2), .window(1)]))
    }

    func testMoveInto_findTopMostContainerWithRightOrientation() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0)
            TestWindow(id: 1, parent: $0).nativeFocus()
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow(id: 2, parent: $0)
                }
            }
        }

        MoveThroughCommand(direction: .right).testRun()
        XCTAssertEqual(
            root.layoutDescription,
            .h_tiles([
                .window(0),
                .h_tiles([
                    .window(1),
                    .h_tiles([
                        .window(2)
                    ])
                ])
            ])
        )
    }

    func testMove_mru() {
        var window3: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0)
            TestWindow(id: 1, parent: $0).nativeFocus()
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow(id: 2, parent: $0)
                    window3 = TestWindow(id: 3, parent: $0)
                }
                TestWindow(id: 4, parent: $0)
            }
        }
        window3.markAsMostRecentChild()

        MoveThroughCommand(direction: .right).testRun()
        XCTAssertEqual(
            root.layoutDescription,
            .h_tiles([
                .window(0),
                .v_tiles([
                    .h_tiles([
                        .window(1),
                        .window(2),
                        .window(3),
                    ]),
                    .window(4)
                ])
            ])
        )
    }

    func testSwap_preserveWeight() {
        let root = Workspace.get(byName: name).rootTilingContainer
        let window1 = TestWindow(id: 1, parent: root, adaptiveWeight: 1)
        let window2 = TestWindow(id: 2, parent: root, adaptiveWeight: 2)
        window2.nativeFocus()

        MoveThroughCommand(direction: .left).testRun() // todo replace all 'runWithoutRefresh' with 'run' in tests
        XCTAssertEqual(window2.hWeight, 2)
        XCTAssertEqual(window1.hWeight, 1)
    }

    func testMoveIn_newWeight() {
        var window1: Window!
        var window2: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0, adaptiveWeight: 1)
            window1 = TestWindow(id: 1, parent: $0, adaptiveWeight: 2)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                window2 = TestWindow(id: 2, parent: $0, adaptiveWeight: 1)
            }
        }
        window1.nativeFocus()

        MoveThroughCommand(direction: .right).testRun()
        XCTAssertEqual(window2.hWeight, 1)
        XCTAssertEqual(window2.vWeight, 1)
        XCTAssertEqual(window1.vWeight, 1)
        XCTAssertEqual(window1.hWeight, 1)
    }

    func testCreateImplicitContainer() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            TestWindow(id: 2, parent: $0).nativeFocus()
            TestWindow(id: 3, parent: $0)
        }

        MoveThroughCommand(direction: .up).testRun()
        XCTAssertEqual(
            workspace.layoutDescription,
            .workspace([
                .v_tiles([
                    .window(2),
                    .h_tiles([.window(1), .window(3)])
                ])
            ])
        )
    }

    func testMoveOut() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow(id: 2, parent: $0).nativeFocus()
                TestWindow(id: 3, parent: $0)
                TestWindow(id: 4, parent: $0)
            }
        }

        MoveThroughCommand(direction: .left).testRun()
        XCTAssertEqual(
            root.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
                .v_tiles([
                    .window(3),
                    .window(4),
                ])
            ])
        )
    }
}

extension TreeNode {
    var layoutDescription: LayoutDescription {
        switch genericKind {
        case .window(let window):
            return .window(window.windowId)
        case .tilingContainer(let container):
            switch container.layout {
            case .tiles:
                return container.orientation == .h
                    ? .h_tiles(container.children.map(\.layoutDescription))
                    : .v_tiles(container.children.map(\.layoutDescription))
            case .accordion:
                return container.orientation == .h
                    ? .h_accordion(container.children.map(\.layoutDescription))
                    : .v_accordion(container.children.map(\.layoutDescription))
            }
        case .workspace:
            return .workspace(workspace.children.map(\.layoutDescription))
        }
    }
}

enum LayoutDescription: Equatable {
    case workspace([LayoutDescription])
    case h_tiles([LayoutDescription])
    case v_tiles([LayoutDescription])
    case h_accordion([LayoutDescription])
    case v_accordion([LayoutDescription])
    case window(UInt32)
}
