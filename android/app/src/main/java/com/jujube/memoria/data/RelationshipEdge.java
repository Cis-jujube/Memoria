package com.jujube.memoria.data;

public final class RelationshipEdge {
    public final String id;
    public final String sourceName;
    public final String targetName;
    public final String label;
    public final double strength;

    public RelationshipEdge(String id, String sourceName, String targetName, String label, double strength) {
        this.id = id;
        this.sourceName = sourceName;
        this.targetName = targetName;
        this.label = label;
        this.strength = strength;
    }
}
