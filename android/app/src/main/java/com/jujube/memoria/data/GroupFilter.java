package com.jujube.memoria.data;

public enum GroupFilter {
    ALL("All"),
    CLASSMATES("Classmates"),
    STUDY_ABROAD("Study Abroad"),
    HOME_FRIENDS("Home Friends"),
    INTERNSHIP("Internship");

    public final String title;

    GroupFilter(String title) {
        this.title = title;
    }
}
