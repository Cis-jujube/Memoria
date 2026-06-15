package com.jujube.memoria.data;

public final class SearchResult {
    public final String title;
    public final String excerpt;
    public final String source;

    public SearchResult(String title, String excerpt, String source) {
        this.title = title;
        this.excerpt = excerpt;
        this.source = source;
    }
}
