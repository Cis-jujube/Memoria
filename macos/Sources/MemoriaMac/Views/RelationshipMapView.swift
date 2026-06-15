import SwiftUI
import MemoriaCore

struct RelationshipMapView: View {
    @ObservedObject var store: DashboardStore
    @State private var centerID = "me"
    @State private var editingRelationshipDraft: RelationshipEdgeDraft?

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }

    private var centerName: String {
        if centerID == "me" {
            return isChinese ? "我" : "Me"
        }
        return store.people.first { $0.id == centerID }?.displayName ?? centerID
    }

    private var graph: TwoHopRelationshipGraph {
        TwoHopRelationshipGraph.make(
            centerID: centerID,
            centerName: centerName,
            people: store.people,
            edges: store.relationshipEdges,
            priorities: store.relationshipTagPriorities
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if store.people.isEmpty {
                    EmptyState(
                        systemImage: "point.3.connected.trianglepath.dotted",
                        title: isChinese ? "还没有关系节点" : "No relationship nodes",
                        detail: isChinese ? "确认记忆、联系人和提醒之后，星图会自动形成。" : "Confirmed memories, people, and reminders will form this map."
                    )
                    .frame(minHeight: 420)
                } else {
                    RelationshipMapCanvas(graph: graph) { edgeID in
                        editRelationship(edgeID: edgeID)
                    }
                        .aspectRatio(1.55, contentMode: .fit)
                        .frame(minHeight: 260, maxHeight: 520)
                        .memoriaCard()

                    edgeList
                }
            }
            .padding(24)
        }
        .onAppear {
            if centerID != "me", !store.people.contains(where: { $0.id == centerID }) {
                centerID = "me"
            }
        }
        .sheet(item: $editingRelationshipDraft) { draft in
            RelationshipEdgeEditorSheet(
                draft: draft,
                language: store.settings.language,
                onCancel: {
                    editingRelationshipDraft = nil
                },
                onSave: { draft in
                    store.updateRelationshipEdge(
                        draft.edge,
                        targetName: draft.targetName,
                        label: draft.label,
                        relationKind: draft.relationKind,
                        strength: draft.strength,
                        tags: draft.tags,
                        manualPrimaryTag: draft.manualPrimaryTag
                    )
                    editingRelationshipDraft = nil
                },
                onDelete: { edge in
                    store.deleteRelationshipEdge(edge)
                    editingRelationshipDraft = nil
                }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isChinese ? "关系星图" : "Relationship Map")
                        .font(.largeTitle.weight(.semibold))

                    Text(isChinese ? "由已确认记忆自动整理；星图本身不再二次审批，你可以在朋友档案里编辑关系边。" : "Updated automatically from confirmed memories. The map has no second approval step; edit relationship edges in friend dossiers.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Picker(isChinese ? "中心" : "Center", selection: $centerID) {
                    Text(isChinese ? "我" : "Me").tag("me")
                    ForEach(store.people) { person in
                        Text(person.displayName).tag(person.id)
                    }
                }
                .frame(width: 220)
            }

            HStack(spacing: 8) {
                MapSummaryPill(label: isChinese ? "中心" : "Center", value: centerName)
                MapSummaryPill(label: isChinese ? "节点" : "Nodes", value: "\(max(graph.nodes.count - 1, 0))")
                MapSummaryPill(label: isChinese ? "关系" : "Edges", value: "\(graph.edges.count)")
                if graph.hiddenEdgeCount > 0 {
                    MapSummaryPill(label: isChinese ? "更多" : "More", value: "\(graph.hiddenEdgeCount)")
                }
            }
        }
    }

    private var edgeList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isChinese ? "两层关系边" : "Two-hop relationship edges")
                .font(.headline)

            if graph.edges.isEmpty {
                Text(isChinese ? "当前中心还没有关系边。新的朋友档案记忆确认后，星图会自动更新；确定无来源但很明确的关系，也可以手动补充。" : "This center has no relationship edges yet. Friend dossier memories update the map automatically after review; certain source-light relationships can still be added manually.")
                    .foregroundStyle(.secondary)
                    .memoriaCard()
            } else {
                ForEach(graph.edges) { edge in
                    Button {
                        editRelationship(edgeID: edge.id)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(edge.sourceName) -> \(edge.targetName)")
                                    .font(.headline)
                                Text(edge.displayTag)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if edge.isAIInferred {
                                Label(isChinese ? "确认记忆派生" : "From approved memory", systemImage: "checkmark.seal")
                                    .font(.caption)
                                    .foregroundStyle(Color.memoriaGold)
                            } else if edge.isEditable {
                                Label(isChinese ? "可编辑" : "Editable", systemImage: "pencil")
                                    .font(.caption)
                                    .foregroundStyle(Color.memoriaSage)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!edge.isEditable)
                    .memoriaCard()
                }
            }
        }
    }

    private func editRelationship(edgeID: String) {
        guard let edge = store.relationshipEdges.first(where: { $0.id == edgeID }) else {
            return
        }
        editingRelationshipDraft = RelationshipEdgeDraft(edge: edge, priorities: store.relationshipTagPriorities)
    }
}

private struct RelationshipMapCanvas: View {
    let graph: TwoHopRelationshipGraph
    let onEditEdge: (String) -> Void

    var body: some View {
        GeometryReader { proxy in
            let layout = graph.layout(in: proxy.size)

            ZStack {
                Canvas { context, _ in
                    for edge in layout.edges {
                        guard let source = layout.nodes[edge.sourceID],
                              let target = layout.nodes[edge.targetID] else {
                            continue
                        }
                        var path = Path()
                        path.move(to: source.point)
                        path.addLine(to: target.point)
                        context.stroke(
                            path,
                            with: .color(edge.depth == 1 ? Color.memoriaSage.opacity(0.55) : Color.primary.opacity(0.18)),
                            style: StrokeStyle(lineWidth: CGFloat(edge.depth == 1 ? max(1.3, 2 * layout.metrics.scale) : max(0.8, 1.2 * layout.metrics.scale)))
                        )
                    }
                }

                ForEach(layout.edges) { edge in
                    if edge.showsLabel {
                        edgeLabel(edge, layout: layout)
                            .position(edge.labelPoint)
                    }
                }

                ForEach(layout.nodes.values.sorted { lhs, rhs in
                    lhs.depth == rhs.depth ? lhs.name < rhs.name : lhs.depth < rhs.depth
                }) { node in
                    RelationshipMapNodeView(node: node)
                        .position(node.point)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.memoriaSage.opacity(0.08), Color.memoriaGold.opacity(0.06), Color.primary.opacity(0.025)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
    }

    @ViewBuilder
    private func edgeLabel(_ edge: PositionedRelationshipGraphEdge, layout: PositionedRelationshipGraph) -> some View {
        let label = Text(edge.displayTag)
            .font(.system(size: max(9, 10 * layout.metrics.scale), weight: .medium))
            .lineLimit(1)
            .frame(maxWidth: CGFloat(layout.metrics.labelMaxWidth))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.background)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(edge.isEditable ? Color.memoriaSage.opacity(0.32) : Color.primary.opacity(0.08), lineWidth: 1)
            }

        if edge.isEditable {
            Button {
                onEditEdge(edge.id)
            } label: {
                label
            }
            .buttonStyle(.plain)
            .help("Edit relationship")
        } else {
            label
        }
    }
}

private struct RelationshipMapNodeView: View {
    let node: PositionedRelationshipNode

    var body: some View {
        VStack(spacing: 5) {
            Text(node.initials)
                .font(.system(size: node.depth == 0 ? max(14, 17 * node.scale) : max(10, 12 * node.scale), weight: .bold))
                .foregroundStyle(node.depth == 2 ? Color.memoriaInk : .white)
                .frame(width: node.size, height: node.size)
                .background(node.depth == 0 ? Color.memoriaInk : node.depth == 1 ? Color.memoriaSage : Color.memoriaGold.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(node.depth == 0 ? 0 : 0.08), lineWidth: 1)
                }

            Text(node.name)
                .font(.system(size: max(10, 12 * node.scale), weight: node.depth == 0 ? .semibold : .medium))
                .lineLimit(1)
                .frame(maxWidth: node.labelMaxWidth)
        }
        .padding(.horizontal, max(5, 8 * node.scale))
        .padding(.vertical, max(4, 6 * node.scale))
        .background(node.depth == 0 ? Color.clear : Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MapSummaryPill: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
    }
}

private struct TwoHopRelationshipGraph {
    let nodes: [RelationshipNode]
    let edges: [RelationshipGraphEdge]
    let hiddenEdgeCount: Int

    static func make(
        centerID: String,
        centerName: String,
        people: [FriendPerson],
        edges: [RelationshipEdge],
        priorities: [RelationshipTagPriority],
        maxVisibleEdges: Int = 26
    ) -> TwoHopRelationshipGraph {
        let peopleByID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
        let sortedEdges = edges.sorted { lhs, rhs in
            if lhs.sourceMemoryID != nil, rhs.sourceMemoryID == nil { return true }
            if lhs.sourceMemoryID == nil, rhs.sourceMemoryID != nil { return false }
            if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
            return lhs.label < rhs.label
        }
        let graphSourceEdges = centerID == "me"
            ? selfEdges(centerName: centerName, people: people) + sortedEdges
            : sortedEdges

        let firstHopIDs = Set(graphSourceEdges.compactMap { edge -> String? in
            if edge.sourceID == centerID { return edge.targetID }
            if edge.targetID == centerID { return edge.sourceID }
            return nil
        })

        var visibleEdges = graphSourceEdges.filter { edge in
            edge.sourceID == centerID ||
                edge.targetID == centerID ||
                firstHopIDs.contains(edge.sourceID) ||
                firstHopIDs.contains(edge.targetID)
        }

        let hiddenCount = max(visibleEdges.count - maxVisibleEdges, 0)
        visibleEdges = Array(visibleEdges.prefix(maxVisibleEdges))

        var nodesByID: [String: RelationshipNode] = [
            centerID: RelationshipNode(
                id: centerID,
                name: centerName,
                initials: centerID == "me" ? "ME" : initials(for: centerName),
                depth: 0
            )
        ]

        for edge in visibleEdges {
            for endpoint in [
                (edge.sourceID, edge.sourceName),
                (edge.targetID, edge.targetName)
            ] {
                guard nodesByID[endpoint.0] == nil else { continue }
                let depth = firstHopIDs.contains(endpoint.0) ? 1 : 2
                let person = peopleByID[endpoint.0]
                nodesByID[endpoint.0] = RelationshipNode(
                    id: endpoint.0,
                    name: person?.displayName ?? endpoint.1,
                    initials: person?.initials ?? initials(for: endpoint.1),
                    depth: endpoint.0 == centerID ? 0 : depth
                )
            }
        }

        let graphEdges = visibleEdges.map { edge in
            RelationshipGraphEdge(
                id: edge.id,
                sourceID: edge.sourceID,
                targetID: edge.targetID,
                sourceName: edge.sourceName,
                targetName: edge.targetName,
                displayTag: edge.displayTag(priorities: priorities),
                depth: edge.sourceID == centerID || edge.targetID == centerID ? 1 : 2,
                isAIInferred: edge.isAIInferred,
                isEditable: !edge.id.hasPrefix("self-edge-")
            )
        }

        return TwoHopRelationshipGraph(
            nodes: Array(nodesByID.values),
            edges: graphEdges,
            hiddenEdgeCount: hiddenCount
        )
    }

    func layout(in size: CGSize) -> PositionedRelationshipGraph {
        let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
        let metrics = RelationshipMapLayoutPolicy.metrics(width: size.width, height: size.height)
        let firstHop = nodes.filter { $0.depth == 1 }.sorted { $0.name < $1.name }
        let secondHop = nodes.filter { $0.depth == 2 }.sorted { $0.name < $1.name }
        let firstRadius = CGFloat(metrics.firstHopRadius)
        let secondRadius = CGFloat(metrics.secondHopRadius)
        var positioned: [String: PositionedRelationshipNode] = [:]

        for node in nodes where node.depth == 0 {
            positioned[node.id] = PositionedRelationshipNode(
                node: node,
                point: centerPoint,
                size: CGFloat(metrics.centerNodeSize),
                labelMaxWidth: CGFloat(metrics.labelMaxWidth),
                scale: CGFloat(metrics.scale)
            )
        }

        for (index, node) in firstHop.enumerated() {
            let angle = angleFor(index: index, count: firstHop.count)
            positioned[node.id] = PositionedRelationshipNode(
                node: node,
                point: CGPoint(
                    x: centerPoint.x + CGFloat(cos(angle)) * firstRadius,
                    y: centerPoint.y + CGFloat(sin(angle)) * firstRadius
                ),
                size: CGFloat(metrics.firstHopNodeSize),
                labelMaxWidth: CGFloat(metrics.labelMaxWidth),
                scale: CGFloat(metrics.scale)
            )
        }

        for (index, node) in secondHop.enumerated() {
            let angle = angleFor(index: index, count: secondHop.count, offset: .pi / 7)
            positioned[node.id] = PositionedRelationshipNode(
                node: node,
                point: CGPoint(
                    x: centerPoint.x + CGFloat(cos(angle)) * secondRadius,
                    y: centerPoint.y + CGFloat(sin(angle)) * secondRadius
                ),
                size: CGFloat(metrics.secondHopNodeSize),
                labelMaxWidth: CGFloat(metrics.labelMaxWidth),
                scale: CGFloat(metrics.scale)
            )
        }

        let positionedEdges = edges.map { edge in
            PositionedRelationshipGraphEdge(
                edge: edge,
                labelPoint: labelPoint(for: edge, nodes: positioned, offset: CGFloat(metrics.edgeLabelOffset)),
                showsLabel: edge.depth == 1 || metrics.showsSecondaryEdgeLabels
            )
        }

        return PositionedRelationshipGraph(nodes: positioned, edges: positionedEdges, metrics: metrics)
    }

    private func labelPoint(
        for edge: RelationshipGraphEdge,
        nodes: [String: PositionedRelationshipNode],
        offset: CGFloat
    ) -> CGPoint {
        guard let source = nodes[edge.sourceID],
              let target = nodes[edge.targetID] else {
            return .zero
        }
        let anchor: CGPoint
        if edge.depth == 1, source.depth == 0 || target.depth == 0 {
            let center = source.depth == 0 ? source.point : target.point
            let outer = source.depth == 0 ? target.point : source.point
            anchor = CGPoint(
                x: center.x + (outer.x - center.x) * 0.62,
                y: center.y + (outer.y - center.y) * 0.62
            )
        } else {
            anchor = CGPoint(
                x: (source.point.x + target.point.x) / 2,
                y: (source.point.y + target.point.y) / 2
            )
        }
        let dx = target.point.x - source.point.x
        let dy = target.point.y - source.point.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let direction = edge.id.hashValue.isMultiple(of: 2) ? CGFloat(1) : CGFloat(-1)
        let depthOffset = edge.depth == 1 ? offset * 1.25 : offset * 0.9
        return CGPoint(
            x: anchor.x + (-dy / length) * depthOffset * direction,
            y: anchor.y + (dx / length) * depthOffset * direction
        )
    }

    private func angleFor(index: Int, count: Int, offset: Double = 0) -> Double {
        guard count > 0 else { return -.pi / 2 }
        return (Double(index) / Double(count)) * .pi * 2 - .pi / 2 + offset
    }

    private static func initials(for name: String) -> String {
        let words = name
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
        let initials = words.prefix(2).compactMap(\.first).map(String.init).joined()
        if !initials.isEmpty {
            return initials.uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private static func selfEdges(centerName: String, people: [FriendPerson]) -> [RelationshipEdge] {
        people.map { person in
            let label = person.relationLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "朋友" : person.relationLabel
            return RelationshipEdge(
                id: "self-edge-\(person.id)",
                sourceID: "me",
                sourceName: centerName,
                targetID: person.id,
                targetName: person.displayName,
                label: label,
                strength: Double(min(max(person.manualClosenessLevel, 1), 6)) / 6,
                relationKind: "self",
                confidence: 1,
                tags: [label],
                manualPrimaryTag: label
            )
        }
    }
}

private struct RelationshipNode: Identifiable {
    let id: String
    let name: String
    let initials: String
    let depth: Int
}

private struct PositionedRelationshipNode: Identifiable {
    let id: String
    let name: String
    let initials: String
    let depth: Int
    let point: CGPoint
    let size: CGFloat
    let labelMaxWidth: CGFloat
    let scale: CGFloat

    init(
        node: RelationshipNode,
        point: CGPoint,
        size: CGFloat,
        labelMaxWidth: CGFloat,
        scale: CGFloat
    ) {
        id = node.id
        name = node.name
        initials = node.initials
        depth = node.depth
        self.point = point
        self.size = size
        self.labelMaxWidth = labelMaxWidth
        self.scale = scale
    }
}

private struct RelationshipGraphEdge: Identifiable {
    let id: String
    let sourceID: String
    let targetID: String
    let sourceName: String
    let targetName: String
    let displayTag: String
    let depth: Int
    let isAIInferred: Bool
    let isEditable: Bool
}

private struct PositionedRelationshipGraphEdge: Identifiable {
    let id: String
    let sourceID: String
    let targetID: String
    let sourceName: String
    let targetName: String
    let displayTag: String
    let depth: Int
    let isAIInferred: Bool
    let isEditable: Bool
    let labelPoint: CGPoint
    let showsLabel: Bool

    init(
        edge: RelationshipGraphEdge,
        labelPoint: CGPoint,
        showsLabel: Bool
    ) {
        id = edge.id
        sourceID = edge.sourceID
        targetID = edge.targetID
        sourceName = edge.sourceName
        targetName = edge.targetName
        displayTag = edge.displayTag
        depth = edge.depth
        isAIInferred = edge.isAIInferred
        isEditable = edge.isEditable
        self.labelPoint = labelPoint
        self.showsLabel = showsLabel
    }
}

private struct PositionedRelationshipGraph {
    let nodes: [String: PositionedRelationshipNode]
    let edges: [PositionedRelationshipGraphEdge]
    let metrics: RelationshipMapLayoutMetrics
}
