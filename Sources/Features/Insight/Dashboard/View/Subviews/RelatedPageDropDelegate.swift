//
//  RelatedPageDropDelegate.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：仪表盘：页面列表、知识统计、每周洞察、回链视图。
//
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
/// 相关页面排序拖拽代理
struct RelatedPageDropDelegate: DropDelegate {
    let item: KnowledgePage
    @Binding var page: KnowledgePage

    /// 执行Drop
    /// - Parameter info: info
    /// - Returns: 是否成功
    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    /// dropEntered
    /// - Parameter info: info
    func dropEntered(info: DropInfo) {
        guard let fromItem = info.itemProviders(for: [.text]).first else { return }
        
        fromItem.loadObject(ofClass: NSString.self) { (uuidString, _) in
            guard let uuidString = uuidString as? String,
                  let fromID = UUID(uuidString: uuidString),
                  fromID != item.id else { return }
            
            DispatchQueue.main.async {
                let fromIndex = page.relatedPageIDs.firstIndex(of: fromID)
                let toIndex = page.relatedPageIDs.firstIndex(of: item.id)
                
                if let from = fromIndex, let to = toIndex {
                    withAnimation {
                        page.relatedPageIDs.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                    }
                }
            }
        }
    }
}
#endif
