package com.jujube.memoria.data;

public final class FocusItem {
    public final String id;
    public final String label;
    public final String detail;
    public final AppSection targetSection;
    public final String priority;

    public FocusItem(String id, String label, String detail, AppSection targetSection, String priority) {
        this.id = id;
        this.label = label;
        this.detail = detail;
        this.targetSection = targetSection;
        this.priority = priority;
    }
}
