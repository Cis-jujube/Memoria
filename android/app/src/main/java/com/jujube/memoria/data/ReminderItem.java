package com.jujube.memoria.data;

public final class ReminderItem {
    public final String id;
    public final String title;
    public final String personName;
    public final String dueLabel;

    public ReminderItem(String id, String title, String personName, String dueLabel) {
        this.id = id;
        this.title = title;
        this.personName = personName;
        this.dueLabel = dueLabel;
    }
}
