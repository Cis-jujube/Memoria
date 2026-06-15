package com.jujube.memoria.data;

public final class GiftIdea {
    public final String id;
    public final String title;
    public final String personName;
    public final String priceBand;
    public final String rationale;

    public GiftIdea(String id, String title, String personName, String priceBand, String rationale) {
        this.id = id;
        this.title = title;
        this.personName = personName;
        this.priceBand = priceBand;
        this.rationale = rationale;
    }
}
