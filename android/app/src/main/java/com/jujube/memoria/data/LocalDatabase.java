package com.jujube.memoria.data;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import java.util.ArrayList;
import java.util.List;

public final class LocalDatabase extends SQLiteOpenHelper {
    private static final String DATABASE_NAME = "memoria.sqlite3";
    private static final int DATABASE_VERSION = 2;

    public LocalDatabase(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL)");
        db.execSQL("CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)");
        db.execSQL("CREATE TABLE people (id TEXT PRIMARY KEY, display_name TEXT NOT NULL, relation_label TEXT NOT NULL, group_label TEXT NOT NULL, location TEXT NOT NULL, birthday TEXT NOT NULL, dietary_restrictions TEXT NOT NULL DEFAULT '', favorite_foods TEXT NOT NULL DEFAULT '', disliked_things TEXT NOT NULL DEFAULT '', zodiac_sign TEXT NOT NULL DEFAULT '', mbti TEXT NOT NULL DEFAULT '', interests TEXT NOT NULL DEFAULT '', books TEXT NOT NULL DEFAULT '', sports TEXT NOT NULL DEFAULT '', profile_tags TEXT NOT NULL DEFAULT '', last_signal TEXT NOT NULL, initials TEXT NOT NULL)");
        db.execSQL("CREATE TABLE memories (id TEXT PRIMARY KEY, body TEXT NOT NULL, created_at TEXT NOT NULL)");
        db.execSQL("CREATE TABLE pending_updates (id TEXT PRIMARY KEY, type TEXT NOT NULL, summary TEXT NOT NULL, evidence TEXT NOT NULL, person_name TEXT NOT NULL, created_label TEXT NOT NULL)");
        db.execSQL("CREATE TABLE reminders (id TEXT PRIMARY KEY, title TEXT NOT NULL, person_name TEXT NOT NULL, due_label TEXT NOT NULL)");
        db.execSQL("CREATE TABLE gift_ideas (id TEXT PRIMARY KEY, title TEXT NOT NULL, person_name TEXT NOT NULL, price_band TEXT NOT NULL, rationale TEXT NOT NULL)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        if (oldVersion < 2) {
            addTextColumn(db, "people", "dietary_restrictions");
            addTextColumn(db, "people", "favorite_foods");
            addTextColumn(db, "people", "disliked_things");
            addTextColumn(db, "people", "zodiac_sign");
            addTextColumn(db, "people", "mbti");
            addTextColumn(db, "people", "interests");
            addTextColumn(db, "people", "books");
            addTextColumn(db, "people", "sports");
            addTextColumn(db, "people", "profile_tags");
            backfillDemoProfiles(db);
        }
    }

    public void backfillDemoProfiles() {
        backfillDemoProfiles(getWritableDatabase());
    }

    public boolean hasPeople() {
        try (Cursor cursor = getReadableDatabase().rawQuery("SELECT COUNT(*) FROM people", null)) {
            return cursor.moveToFirst() && cursor.getInt(0) > 0;
        }
    }

    public AppSettings loadSettings() {
        AppSettings settings = new AppSettings();
        settings.model = readSetting("deepseek_model", "deepseek-v4-flash");
        settings.deepThinking = "true".equals(readSetting("deep_thinking", "false"));
        settings.language = readSetting("language", "system");
        return settings;
    }

    public void saveSettings(AppSettings settings) {
        writeSetting("deepseek_model", settings.model);
        writeSetting("deep_thinking", settings.deepThinking ? "true" : "false");
        writeSetting("language", settings.language);
    }

    public List<FriendPerson> loadPeople() {
        List<FriendPerson> people = new ArrayList<>();
        try (Cursor cursor = getReadableDatabase().rawQuery(
                "SELECT id, display_name, relation_label, group_label, location, birthday, dietary_restrictions, favorite_foods, disliked_things, zodiac_sign, mbti, interests, books, sports, profile_tags, last_signal, initials FROM people ORDER BY display_name",
                null
        )) {
            while (cursor.moveToNext()) {
                people.add(new FriendPerson(
                        cursor.getString(0),
                        cursor.getString(1),
                        cursor.getString(2),
                        groupFrom(cursor.getString(3)),
                        cursor.getString(4),
                        cursor.getString(5),
                        cursor.getString(6),
                        cursor.getString(7),
                        cursor.getString(8),
                        cursor.getString(9),
                        cursor.getString(10),
                        cursor.getString(11),
                        cursor.getString(12),
                        cursor.getString(13),
                        cursor.getString(14),
                        cursor.getString(15),
                        cursor.getString(16)
                ));
            }
        }
        return people;
    }

    public List<PendingUpdate> loadPendingUpdates() {
        List<PendingUpdate> updates = new ArrayList<>();
        try (Cursor cursor = getReadableDatabase().rawQuery(
                "SELECT id, type, summary, evidence, person_name, created_label FROM pending_updates ORDER BY rowid DESC",
                null
        )) {
            while (cursor.moveToNext()) {
                updates.add(new PendingUpdate(
                        cursor.getString(0),
                        cursor.getString(1),
                        cursor.getString(2),
                        cursor.getString(3),
                        cursor.getString(4),
                        cursor.getString(5)
                ));
            }
        }
        return updates;
    }

    public List<ReminderItem> loadReminders() {
        List<ReminderItem> reminders = new ArrayList<>();
        try (Cursor cursor = getReadableDatabase().rawQuery(
                "SELECT id, title, person_name, due_label FROM reminders ORDER BY rowid",
                null
        )) {
            while (cursor.moveToNext()) {
                reminders.add(new ReminderItem(
                        cursor.getString(0),
                        cursor.getString(1),
                        cursor.getString(2),
                        cursor.getString(3)
                ));
            }
        }
        return reminders;
    }

    public List<GiftIdea> loadGiftIdeas() {
        List<GiftIdea> gifts = new ArrayList<>();
        try (Cursor cursor = getReadableDatabase().rawQuery(
                "SELECT id, title, person_name, price_band, rationale FROM gift_ideas ORDER BY rowid",
                null
        )) {
            while (cursor.moveToNext()) {
                gifts.add(new GiftIdea(
                        cursor.getString(0),
                        cursor.getString(1),
                        cursor.getString(2),
                        cursor.getString(3),
                        cursor.getString(4)
                ));
            }
        }
        return gifts;
    }

    public void insertPerson(FriendPerson person) {
        ContentValues values = new ContentValues();
        values.put("id", person.id);
        values.put("display_name", person.displayName);
        values.put("relation_label", person.relationLabel);
        values.put("group_label", person.groupLabel.title);
        values.put("location", person.location);
        values.put("birthday", person.birthday);
        values.put("dietary_restrictions", person.dietaryRestrictions);
        values.put("favorite_foods", person.favoriteFoods);
        values.put("disliked_things", person.dislikedThings);
        values.put("zodiac_sign", person.zodiacSign);
        values.put("mbti", person.mbti);
        values.put("interests", person.interests);
        values.put("books", person.books);
        values.put("sports", person.sports);
        values.put("profile_tags", person.profileTags);
        values.put("last_signal", person.lastSignal);
        values.put("initials", person.initials);
        getWritableDatabase().insertWithOnConflict("people", null, values, SQLiteDatabase.CONFLICT_REPLACE);
    }

    public void insertReminder(ReminderItem reminder) {
        ContentValues values = new ContentValues();
        values.put("id", reminder.id);
        values.put("title", reminder.title);
        values.put("person_name", reminder.personName);
        values.put("due_label", reminder.dueLabel);
        getWritableDatabase().insertWithOnConflict("reminders", null, values, SQLiteDatabase.CONFLICT_REPLACE);
    }

    public void insertGiftIdea(GiftIdea gift) {
        ContentValues values = new ContentValues();
        values.put("id", gift.id);
        values.put("title", gift.title);
        values.put("person_name", gift.personName);
        values.put("price_band", gift.priceBand);
        values.put("rationale", gift.rationale);
        getWritableDatabase().insertWithOnConflict("gift_ideas", null, values, SQLiteDatabase.CONFLICT_REPLACE);
    }

    public void insertMemory(String id, String body, String createdAt) {
        ContentValues values = new ContentValues();
        values.put("id", id);
        values.put("body", body);
        values.put("created_at", createdAt);
        getWritableDatabase().insert("memories", null, values);
    }

    public void insertPendingUpdate(PendingUpdate update) {
        ContentValues values = new ContentValues();
        values.put("id", update.id);
        values.put("type", update.type);
        values.put("summary", update.summary);
        values.put("evidence", update.evidence);
        values.put("person_name", update.personName);
        values.put("created_label", update.createdLabel);
        getWritableDatabase().insertWithOnConflict("pending_updates", null, values, SQLiteDatabase.CONFLICT_REPLACE);
    }

    public void deletePendingUpdate(PendingUpdate update) {
        getWritableDatabase().delete("pending_updates", "id = ?", new String[]{update.id});
    }

    private String readSetting(String key, String fallback) {
        try (Cursor cursor = getReadableDatabase().rawQuery(
                "SELECT value FROM app_settings WHERE key = ?",
                new String[]{key}
        )) {
            if (cursor.moveToFirst()) {
                return cursor.getString(0);
            }
        }
        return fallback;
    }

    private void writeSetting(String key, String value) {
        ContentValues values = new ContentValues();
        values.put("key", key);
        values.put("value", value);
        getWritableDatabase().insertWithOnConflict("app_settings", null, values, SQLiteDatabase.CONFLICT_REPLACE);
    }

    private static void addTextColumn(SQLiteDatabase db, String table, String column) {
        try {
            db.execSQL("ALTER TABLE " + table + " ADD COLUMN " + column + " TEXT NOT NULL DEFAULT ''");
        } catch (Exception ignored) {
        }
    }

    private static void backfillDemoProfiles(SQLiteDatabase db) {
        updateDemoProfile(
                db,
                "demo-alex",
                "不吃香菜",
                "火锅、毛肚、虾滑",
                "临时改计划、太吵的自习室",
                "Scorpio",
                "INTJ",
                "数学、篮球、效率工具",
                "Atomic Habits, 置身事内",
                "篮球、健身",
                "室友, 考试, 火锅"
        );
        updateDemoProfile(
                db,
                "demo-may",
                "少冰，不太能吃辣",
                "抹茶、日料、桂花乌龙",
                "敷衍的群发祝福",
                "Taurus",
                "INFP",
                "音乐、拍立得、文学社、香水",
                "夜航西飞, The Midnight Library",
                "瑜伽、散步",
                "生日, 礼物, 文学社"
        );
        updateDemoProfile(
                db,
                "demo-jason",
                "工作日少糖",
                "冷萃、牛排、越南粉",
                "没有 agenda 的长会",
                "Leo",
                "ENTJ",
                "创业、跑步、职业规划",
                "The Hard Thing About Hard Things",
                "跑步、攀岩",
                "学长, 内推, 职业"
        );
        updateDemoProfile(
                db,
                "demo-nina",
                "少喝奶制品",
                "紫菜包饭、冷面、草莓蛋糕",
                "太临时的出行安排",
                "Aquarius",
                "ENFP",
                "旅行、韩语、摄影、城市漫步",
                "Pachinko, 旅行的艺术",
                "普拉提、徒步",
                "水瓶, 交换, 旅行"
        );
    }

    private static void updateDemoProfile(
            SQLiteDatabase db,
            String id,
            String dietaryRestrictions,
            String favoriteFoods,
            String dislikedThings,
            String zodiacSign,
            String mbti,
            String interests,
            String books,
            String sports,
            String profileTags
    ) {
        ContentValues values = new ContentValues();
        values.put("dietary_restrictions", dietaryRestrictions);
        values.put("favorite_foods", favoriteFoods);
        values.put("disliked_things", dislikedThings);
        values.put("zodiac_sign", zodiacSign);
        values.put("mbti", mbti);
        values.put("interests", interests);
        values.put("books", books);
        values.put("sports", sports);
        values.put("profile_tags", profileTags);
        db.update(
                "people",
                values,
                "id = ? AND dietary_restrictions = '' AND favorite_foods = '' AND disliked_things = '' AND zodiac_sign = '' AND mbti = '' AND interests = '' AND books = '' AND sports = '' AND profile_tags = ''",
                new String[]{id}
        );
    }

    private GroupFilter groupFrom(String value) {
        for (GroupFilter group : GroupFilter.values()) {
            if (group.title.equals(value)) {
                return group;
            }
        }
        return GroupFilter.CLASSMATES;
    }
}
