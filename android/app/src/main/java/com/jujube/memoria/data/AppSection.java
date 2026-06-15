package com.jujube.memoria.data;

public enum AppSection {
    BRIEF("Daily Brief"),
    INBOX("AI Inbox"),
    PEOPLE("People"),
    CALENDAR("Calendar"),
    REMINDERS("Reminders"),
    GIFTS("Gift Ideas"),
    SEARCH("Search"),
    MAP("Relationship Map"),
    FILES("Files & Imports"),
    SETTINGS("Settings");

    public final String title;

    AppSection(String title) {
        this.title = title;
    }
}
