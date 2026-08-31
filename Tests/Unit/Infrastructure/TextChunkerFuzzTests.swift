//
//  TextChunkerFuzzTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[测试层]
//  核心职责：对 TextChunkerProcessor 进行真正的 Property-based Fuzz 测试。
//  使用 xorshift64 轻量随机数生成器，每次产生不同随机输入并验证「不变式」，
//  而非断言具体输出值。任何不变式失败都代表真实运行时 Bug。
//
//  【Fuzz 不变式】
//  1. 任意输入永不崩溃
//  2. 所有 chunk.text 非空字符串
//  3. startIndex 单调不递减
//  4. isCode=true 的 chunk 必须包含 ``` 字符
//

import XCTest
@testable import ZhiYu

// MARK: - 轻量随机数生成器（xorshift64，无需引入外部库）
private struct SimpleRNG {
    var state: UInt64

    mutating func nextUInt64() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        guard range.count > 0 else { return range.lowerBound }
        let count = UInt64(range.count)
        return range.lowerBound + Int(nextUInt64() % count)
    }

    mutating func nextBool() -> Bool {
        nextUInt64() % 2 == 0
    }

    mutating func nextElement<C: RandomAccessCollection>(from collection: C) -> C.Element {
        let idx = nextInt(in: 0..<collection.count)
        return collection[collection.index(collection.startIndex, offsetBy: idx)]
    }
}

// MARK: - 随机 Markdown 生成器
private func makeRandomMarkdown(rng: inout SimpleRNG, length: Int) -> String {
    // 危险字符池：含换行、标题符、代码块标记、中文、Unicode 控制字符、RTL 字符、零宽字符
    let charPool: [Character] = [
        "#", " ", "\n", "`", "[", "]", "*", "-", ">", "|",
        "A", "B", "中", "文", "字", "α", "β",
        "\u{200B}", // 零宽空格
        "\u{202E}", // RTL Override（危险：会改变渲染方向）
        "\u{0}" // NUL 字符
    ]
    let codeBlockPool = ["```", "```swift", "```python", "```\n"]
    let headerPool = ["# ", "## ", "### ", "#### "]

    var result = ""
    var pos = 0

    while pos < length {
        let choice = rng.nextInt(in: 0..<10)
        switch choice {
        case 0...3:
            // 随机单字符
            result.append(rng.nextElement(from: charPool))
            pos += 1
        case 4:
            // 插入代码块标记
            let block = rng.nextElement(from: codeBlockPool)
            result += block
            pos += block.count
        case 5:
            // 插入标题行（可能不闭合代码块就插入标题）
            let header = rng.nextElement(from: headerPool)
            result += "\n" + header + "随机标题\n"
            pos += header.count + 8
        case 6:
            // 插入换行
            result += "\n"
            pos += 1
        case 7:
            // 插入 WikiLink
            result += "[[随机链接\(rng.nextInt(in: 0..<1000))]]"
            pos += 10
        default:
            // 插入普通字符序列
            let word = String(repeating: "X", count: rng.nextInt(in: 1..<20))
            result += word
            pos += word.count
        }
    }
    return result
}

// MARK: - Fuzz 不变式验证辅助函数
private func assertChunkerInvariants(
    chunks: [TextChunkerProcessor.Chunk],
    input: String,
    seed: UInt64,
    file: StaticString = #file,
    line: UInt = #line
) {
    let context = "seed=\(seed), input前50字符='\(input.prefix(50))'"

    // 不变式 2：所有 chunk.text 不应为空字符串
    for (i, chunk) in chunks.enumerated() {
        XCTAssertFalse(
            chunk.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "不变式2违反：chunk[\(i)].text 为空字符串 [\(context)]",
            file: file, line: line
        )
    }

    // 不变式 3：startIndex 单调不递减
    for i in 1..<chunks.count {
        XCTAssertGreaterThanOrEqual(
            chunks[i].startIndex,
            chunks[i - 1].startIndex,
            "不变式3违反：startIndex 在 index \(i) 处回退 [\(context)]",
            file: file, line: line
        )
    }

    // 不变式 4：isCode=true 的 chunk 必须包含 ``` 字符
    for (i, chunk) in chunks.enumerated() where chunk.isCode {
        XCTAssertTrue(
            chunk.text.contains("```"),
            "不变式4违反：chunk[\(i)].isCode=true 但 text 不含 ``` [\(context)]",
            file: file, line: line
        )
    }
}

// MARK: - Fuzz 测试用例

@MainActor
final class TextChunkerFuzzTests: XCTestCase {

    private let chunker = TextChunkerProcessor()

    // MARK: - Fuzz F1：200 次随机输入验证全部不变式
    //
    // 这是真正的 Property-based Fuzz：每次循环生成不同随机文本，
    // 若任何一次触发不变式违反，测试 FAIL 并报告种子值（可复现）。
    func testFuzz_RandomMarkdown_AllInvariantsHold() {
        let baseSeed = UInt64(Date().timeIntervalSinceReferenceDate * 1000)
        var failCount = 0

        for i in 0..<200 {
            let seed = baseSeed &+ UInt64(i) &* 6364136223846793005 &+ 1442695040888963407
            var rng = SimpleRNG(state: seed == 0 ? 1 : seed)
            let length = rng.nextInt(in: 10..<2000)
            let input = makeRandomMarkdown(rng: &rng, length: length)

            // 不变式 1：不崩溃（若崩溃则 XCTest 自动 FAIL）
            let chunks = chunker.split(text: input)

            // 不变式 2-4 验证
            let chunksCopy = chunks
            for (j, chunk) in chunksCopy.enumerated() where chunk.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failCount += 1
                XCTFail("不变式2违反：chunk[\(j)].text 为空 [seed=\(seed), i=\(i)]")
                break
            }
            for k in 1..<chunksCopy.count where chunksCopy[k].startIndex < chunksCopy[k - 1].startIndex {
                failCount += 1
                XCTFail("不变式3违反：startIndex 回退 [seed=\(seed), i=\(i), k=\(k)]")
                break
            }
            for (j, chunk) in chunksCopy.enumerated() where chunk.isCode && !chunk.text.contains("```") {
                failCount += 1
                XCTFail("不变式4违反：isCode=true 但无 ``` [seed=\(seed), i=\(i), j=\(j)]")
                break
            }

            if failCount >= 3 { break } // 发现 3 个 Bug 后停止，避免报告洪水
        }
    }

    // MARK: - Fuzz F2：从危险种子语料库出发做变异（Corpus-based Fuzz）
    //
    // 真实 Fuzz 工具（如 libFuzzer）的工作方式：从已知危险输入出发，
    // 随机翻转/插入/删除字节，验证不变式仍然成立。
    func testFuzz_CorpusMutation_InvariantsHold() {
        // 10 个已知危险种子
        let corpus = [
            "# 标题\n```swift\nfunc foo() {\n    print(\"unclosed\")\n// 未闭合代码块！",
            String(repeating: "# 连续标题\n", count: 100),
            "[[[[[[嵌套链接]]]]]]",
            "---\nfrontmatter: 混入分块器\n---\n正文",
            "\u{202E}RTL字符反转\u{202C}",
            String(repeating: "A", count: 2000), // 超长单行
            "```\n```\n```\n```\n交替代码块",
            "## H2\n### H3\n#### H4\n##### H5\n###### H6\n正文",
            "\u{0}\u{1}\u{2}控制字符\u{7F}",
            String(repeating: "中文内容\n", count: 200)
        ]

        let baseSeed = UInt64(42)
        for (corpusIdx, seed) in corpus.enumerated() {
            var rng = SimpleRNG(state: UInt64(corpusIdx + 1) &* 2654435761)
            var mutated = Array(seed.utf8)

            for mutationRound in 0..<50 {
                guard !mutated.isEmpty else { break }

                // 随机选择变异操作
                let op = rng.nextInt(in: 0..<4)
                switch op {
                case 0: // 随机翻转一个字节
                    let idx = rng.nextInt(in: 0..<mutated.count)
                    mutated[idx] ^= UInt8(rng.nextInt(in: 1..<256))
                case 1: // 随机插入一个字节
                    let idx = rng.nextInt(in: 0..<mutated.count + 1)
                    mutated.insert(UInt8(rng.nextInt(in: 0..<256)), at: idx)
                case 2: // 随机删除一个字节
                    if mutated.count > 1 {
                        let idx = rng.nextInt(in: 0..<mutated.count)
                        mutated.remove(at: idx)
                    }
                default: // 随机替换一段为换行
                    let idx = rng.nextInt(in: 0..<mutated.count)
                    mutated[idx] = 10 // '\n'
                }

                // 将字节序列转为 String（允许 lossy 解码）
                let mutatedStr = String(bytes: mutated, encoding: .utf8) ?? (String(bytes: mutated, encoding: .isoLatin1) ?? "")

                // 不变式 1：不崩溃
                let chunks = chunker.split(text: mutatedStr)

                // 不变式 2-4
                assertChunkerInvariants(
                    chunks: chunks,
                    input: mutatedStr,
                    seed: baseSeed &+ UInt64(corpusIdx) &* 100 &+ UInt64(mutationRound)
                )
            }
        }
    }

    // MARK: - Fuzz F3：边界尺寸 Fuzz（专门压测 overlap 计算）
    //
    // 围绕 chunkSize 附近 ±50 随机变化文本长度，触发 overflow flush 边界。
    func testFuzz_NearChunkSizeBoundary_OverlapCalculationStable() {
        let chunkSize = ProcessorConstants.TextChunker.defaultChunkSize
        let baseSeed = UInt64(12345)

        for i in 0..<100 {
            var rng = SimpleRNG(state: baseSeed &+ UInt64(i))
            let targetLength = chunkSize + rng.nextInt(in: -50..<50)
            guard targetLength > 0 else { continue }

            // 构造恰好在边界附近的文本（全字母，不含换行，强制触发溢出）
            let line1 = String(repeating: "B", count: max(1, targetLength))
            let input = line1 + "\n更多内容触发第二块"

            let chunks = chunker.split(text: input)

            assertChunkerInvariants(
                chunks: chunks,
                input: input,
                seed: baseSeed &+ UInt64(i)
            )
        }
    }
}
