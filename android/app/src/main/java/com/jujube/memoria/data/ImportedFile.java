package com.jujube.memoria.data;

public final class ImportedFile {
    public final String id;
    public final String filename;
    public final String status;
    public final double progress;

    public ImportedFile(String id, String filename, String status, double progress) {
        this.id = id;
        this.filename = filename;
        this.status = status;
        this.progress = progress;
    }
}
