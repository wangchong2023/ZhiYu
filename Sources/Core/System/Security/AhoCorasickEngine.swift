//
//  AhoCorasickEngine.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：提供高效率、O(N) 复杂度的 Aho-Corasick 多模式匹配 AC 自动机算法实现。
//  用于高并发与海量词库下的敏感词、红线词与避讳词快速检出，消除 CPU 峰值与正则卡顿。
//
import Foundation

/// AC 自动机匹配结果
public struct AhoMatch: Sendable, Equatable {
    public let pattern: String
    public let startIndex: Int
    public let endIndex: Int

    public init(pattern: String, startIndex: Int, endIndex: Int) {
        self.pattern = pattern
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

/// AC 自动机 Trie 树节点
private final class AhoNode: @unchecked Sendable {
    var children: [Character: AhoNode] = [:]
    var failLink: AhoNode?
    var outputPatterns: [String] = []

    init() {}
}

/// AC 自动机多模式匹配引擎 (Aho-Corasick Automaton)
public final class AhoCorasickEngine: Sendable {

    private let root: AhoNode
    private let isBuilt: Bool

    public init(patterns: [String]) {
        self.root = AhoNode()
        let uniquePatterns = Array(Set(patterns.filter { !$0.isEmpty }))
        for pattern in uniquePatterns {
            var current = root
            for char in pattern {
                if let next = current.children[char] {
                    current = next
                } else {
                    let newNode = AhoNode()
                    current.children[char] = newNode
                    current = newNode
                }
            }
            current.outputPatterns.append(pattern)
        }

        // 广度优先遍历 (BFS) 动态构建 Fail 指针与 Output 转移
        var queue: [AhoNode] = []
        for (_, childNode) in root.children {
            childNode.failLink = root
            queue.append(childNode)
        }

        while !queue.isEmpty {
            let current = queue.removeFirst()

            for (char, childNode) in current.children {
                var fail = current.failLink
                while fail != nil && fail?.children[char] == nil {
                    fail = fail?.failLink
                }
                let targetFail = fail?.children[char] ?? root
                childNode.failLink = targetFail
                childNode.outputPatterns.append(contentsOf: targetFail.outputPatterns)
                queue.append(childNode)
            }
        }
        self.isBuilt = true
    }

    /// 在给定目标文本中搜寻所有匹配项
    /// - Parameter text: 原始文本
    /// - Returns: 包含位置与模式串的匹配列表
    public func search(in text: String) -> [AhoMatch] {
        guard isBuilt, !text.isEmpty else { return [] }

        var results: [AhoMatch] = []
        let characters = Array(text)
        var current = root

        for (idx, char) in characters.enumerated() {
            while current.children[char] == nil && current !== root {
                if let fail = current.failLink {
                    current = fail
                } else {
                    current = root
                    break
                }
            }

            if let next = current.children[char] {
                current = next
            } else {
                current = root
            }

            for pattern in current.outputPatterns {
                let patternLen = pattern.count
                let startIdx = idx - patternLen + 1
                let match = AhoMatch(pattern: pattern, startIndex: startIdx, endIndex: idx)
                results.append(match)
            }
        }
        return results
    }

    /// 快速检查目标文本是否包含任何敏感词（包含即返回 true）
    /// - Parameter text: 原始文本
    /// - Returns: 是否命中了任何模式串
    public func containsAny(in text: String) -> Bool {
        guard isBuilt, !text.isEmpty else { return false }

        let characters = Array(text)
        var current = root

        for char in characters {
            while current.children[char] == nil && current !== root {
                if let fail = current.failLink {
                    current = fail
                } else {
                    current = root
                    break
                }
            }

            if let next = current.children[char] {
                current = next
            } else {
                current = root
            }

            if !current.outputPatterns.isEmpty {
                return true
            }
        }
        return false
    }
}
