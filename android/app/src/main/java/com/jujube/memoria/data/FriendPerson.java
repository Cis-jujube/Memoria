package com.jujube.memoria.data;

public final class FriendPerson {
    public final String id;
    public final String displayName;
    public final String relationLabel;
    public final GroupFilter groupLabel;
    public final String location;
    public final String birthday;
    public final String dietaryRestrictions;
    public final String favoriteFoods;
    public final String dislikedThings;
    public final String zodiacSign;
    public final String mbti;
    public final String interests;
    public final String books;
    public final String sports;
    public final String profileTags;
    public final String lastSignal;
    public final String initials;

    public FriendPerson(
            String id,
            String displayName,
            String relationLabel,
            GroupFilter groupLabel,
            String location,
            String birthday,
            String dietaryRestrictions,
            String favoriteFoods,
            String dislikedThings,
            String zodiacSign,
            String mbti,
            String interests,
            String books,
            String sports,
            String profileTags,
            String lastSignal,
            String initials
    ) {
        this.id = id;
        this.displayName = displayName;
        this.relationLabel = relationLabel;
        this.groupLabel = groupLabel;
        this.location = location;
        this.birthday = birthday;
        this.dietaryRestrictions = dietaryRestrictions;
        this.favoriteFoods = favoriteFoods;
        this.dislikedThings = dislikedThings;
        this.zodiacSign = zodiacSign;
        this.mbti = mbti;
        this.interests = interests;
        this.books = books;
        this.sports = sports;
        this.profileTags = profileTags;
        this.lastSignal = lastSignal;
        this.initials = initials;
    }
}
