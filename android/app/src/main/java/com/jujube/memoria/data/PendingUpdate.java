package com.jujube.memoria.data;

public final class PendingUpdate {
    public final String id;
    public final String type;
    public final String summary;
    public final String evidence;
    public final String personName;
    public final String createdLabel;

    public PendingUpdate(
            String id,
            String type,
            String summary,
            String evidence,
            String personName,
            String createdLabel
    ) {
        this.id = id;
        this.type = type;
        this.summary = summary;
        this.evidence = evidence;
        this.personName = personName;
        this.createdLabel = createdLabel;
    }
}
