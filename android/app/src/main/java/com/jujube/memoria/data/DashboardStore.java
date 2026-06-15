package com.jujube.memoria.data;

import android.content.Context;

import java.text.DateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

public final class DashboardStore {
    public final List<FriendPerson> people = new ArrayList<>();
    public final List<PendingUpdate> pendingUpdates = new ArrayList<>();
    public final List<ReminderItem> reminders = new ArrayList<>();
    public final List<GiftIdea> gifts = new ArrayList<>();
    public final List<ImportedFile> files = new ArrayList<>();
    public final List<RelationshipEdge> relationshipEdges = new ArrayList<>();
    public final AppSettings settings;
    public String statusMessage = "";

    private final LocalDatabase database;
    private final SecureApiKeyStore secureApiKeyStore;
    private final DeepSeekClient deepSeekClient = new DeepSeekClient();

    public DashboardStore(Context context) {
        Context appContext = context.getApplicationContext();
        database = new LocalDatabase(appContext);
        secureApiKeyStore = new SecureApiKeyStore(appContext);
        settings = database.loadSettings();
        settings.hasApiKey = secureApiKeyStore.hasKey();
        database.backfillDemoProfiles();

        if (database.hasPeople()) {
            loadFromDatabase();
            seedPreviewArtifacts();
        } else {
            seedDemoData();
            persistSeedData();
        }
    }

    public int badgeFor(AppSection section) {
        switch (section) {
            case INBOX:
                return pendingUpdates.size();
            case REMINDERS:
                return reminders.size();
            case GIFTS:
                return gifts.size();
            case FILES:
                int inProgress = 0;
                for (ImportedFile file : files) {
                    if (file.progress < 1) {
                        inProgress += 1;
                    }
                }
                return inProgress;
            default:
                return 0;
        }
    }

    public int countFor(GroupFilter group) {
        if (group == GroupFilter.ALL) {
            return people.size();
        }

        int count = 0;
        for (FriendPerson person : people) {
            if (person.groupLabel == group) {
                count += 1;
            }
        }
        return count;
    }

    public List<FriendPerson> visiblePeople(GroupFilter group) {
        List<FriendPerson> visible = new ArrayList<>();

        for (FriendPerson person : people) {
            if (group == GroupFilter.ALL || person.groupLabel == group) {
                visible.add(person);
            }
        }

        return visible;
    }

    public List<FocusItem> focusItems() {
        List<FocusItem> items = new ArrayList<>();

        if (!pendingUpdates.isEmpty()) {
            PendingUpdate update = pendingUpdates.get(0);
            items.add(new FocusItem(
                    "review-" + update.id,
                    "Review " + update.personName,
                    update.summary,
                    AppSection.INBOX,
                    "High"
            ));
        }

        if (!reminders.isEmpty()) {
            ReminderItem reminder = reminders.get(0);
            items.add(new FocusItem(
                    "reminder-" + reminder.id,
                    "Prepare " + reminder.personName,
                    reminder.title + " - " + reminder.dueLabel,
                    AppSection.REMINDERS,
                    "High"
            ));
        }

        if (!gifts.isEmpty()) {
            GiftIdea gift = gifts.get(0);
            items.add(new FocusItem(
                    "gift-" + gift.id,
                    "Gift idea for " + gift.personName,
                    gift.title + " - " + gift.priceBand,
                    AppSection.GIFTS,
                    "Medium"
            ));
        }

        return items;
    }

    public List<String> askSuggestions() {
        List<String> suggestions = new ArrayList<>();
        suggestions.add(pendingUpdates.isEmpty()
                ? "What should I review today?"
                : "What should I review for " + pendingUpdates.get(0).personName + "?");
        suggestions.add("Who needs attention this week?");
        suggestions.add(gifts.isEmpty()
                ? "What gift ideas do I have?"
                : "What gift fits " + gifts.get(0).personName + "?");
        return suggestions;
    }

    public Map<String, Integer> groupCounts() {
        Map<String, Integer> counts = new LinkedHashMap<>();
        for (GroupFilter group : GroupFilter.values()) {
            if (group != GroupFilter.ALL) {
                counts.put(group.title, countFor(group));
            }
        }
        return counts;
    }

    public Map<String, Integer> fileStatusCounts() {
        Map<String, Integer> counts = new LinkedHashMap<>();
        for (ImportedFile file : files) {
            counts.put(file.status, counts.containsKey(file.status) ? counts.get(file.status) + 1 : 1);
        }
        return counts;
    }

    public NativeCopy copy() {
        return NativeCopy.forLanguage(settings.language);
    }

    public void saveSettings() {
        database.saveSettings(settings);
        statusMessage = localized("设置已保存。", "Settings saved.");
    }

    public void saveApiKey(String apiKey) throws Exception {
        String trimmed = apiKey.trim();
        if (trimmed.isEmpty()) {
            statusMessage = localized("API key 不能为空。", "API key cannot be empty.");
            return;
        }

        secureApiKeyStore.save(trimmed);
        settings.hasApiKey = true;
        statusMessage = localized("密钥已保存到本机安全存储。", "Key saved to local secure storage.");
    }

    public void removeApiKey() {
        secureApiKeyStore.remove();
        settings.hasApiKey = false;
        statusMessage = localized("密钥已移除。", "Key removed.");
    }

    public void testConnection() throws Exception {
        String apiKey = secureApiKeyStore.read();
        if (apiKey == null || apiKey.trim().isEmpty()) {
            statusMessage = copy().missingKeyMessage;
            return;
        }

        deepSeekClient.testConnection(apiKey, settings);
        statusMessage = localized("连接正常。", "Connection works.");
    }

    public synchronized void addCapture(String text, FriendPerson selectedPerson) {
        String trimmed = text.trim();
        if (trimmed.isEmpty()) {
            return;
        }

        String personName = selectedPerson == null ? "Unknown person" : selectedPerson.displayName;
        String timeLabel = DateFormat.getTimeInstance(DateFormat.SHORT, Locale.getDefault()).format(new Date());
        database.insertMemory("memory-" + UUID.randomUUID(), trimmed, DateFormat.getDateTimeInstance().format(new Date()));

        PendingUpdate update;
        String apiKey = secureApiKeyStore.read();
        if (apiKey == null || apiKey.trim().isEmpty()) {
            update = new PendingUpdate(
                    "local-" + UUID.randomUUID(),
                    "Capture",
                    trimmed,
                    copy().missingKeyMessage,
                    personName,
                    "Today, " + timeLabel
            );
        } else {
            try {
                update = deepSeekClient.extract(trimmed, personName, apiKey, settings);
            } catch (Exception exception) {
                update = new PendingUpdate(
                        "local-" + UUID.randomUUID(),
                        "Capture",
                        trimmed,
                        localized("AI 识别暂时失败：", "AI extraction failed: ") + exception.getMessage(),
                        personName,
                        "Today, " + timeLabel
                );
            }
        }

        pendingUpdates.add(0, update);
        database.insertPendingUpdate(update);
        statusMessage = localized("已发送到待确认。", "Sent to AI Inbox.");
    }

    public void removePending(PendingUpdate update) {
        database.deletePendingUpdate(update);
        pendingUpdates.remove(update);
    }

    public String nextActionFor(FriendPerson person) {
        for (PendingUpdate update : pendingUpdates) {
            if (update.personName.equals(person.displayName)) {
                return "Review pending update";
            }
        }

        for (ReminderItem reminder : reminders) {
            if (reminder.personName.equals(person.displayName)) {
                return "Prepare for reminder";
            }
        }

        for (GiftIdea gift : gifts) {
            if (gift.personName.equals(person.displayName)) {
                return "Check gift idea";
            }
        }

        return "Capture one fresh signal";
    }

    public List<SearchResult> search(String query) {
        String normalized = query.trim().toLowerCase(Locale.ROOT);
        List<SearchResult> results = new ArrayList<>();

        if (normalized.isEmpty()) {
            return results;
        }

        for (PendingUpdate update : pendingUpdates) {
            if (contains(update.personName, normalized) || contains(update.summary, normalized)) {
                results.add(new SearchResult(update.personName, update.summary, "AI Inbox - " + update.createdLabel));
            }
        }

        for (FriendPerson person : people) {
            if (contains(person.displayName, normalized) || contains(person.lastSignal, normalized)) {
                results.add(new SearchResult(person.displayName, person.lastSignal, person.groupLabel.title + " - " + person.location));
            }
        }

        for (GiftIdea gift : gifts) {
            if (contains(gift.personName, normalized) || contains(gift.rationale, normalized)) {
                results.add(new SearchResult(gift.title, gift.rationale, "Gift Ideas - " + gift.personName));
            }
        }

        return results;
    }

    private static boolean contains(String value, String needle) {
        return value.toLowerCase(Locale.ROOT).contains(needle);
    }

    private void loadFromDatabase() {
        people.clear();
        pendingUpdates.clear();
        reminders.clear();
        gifts.clear();
        people.addAll(database.loadPeople());
        pendingUpdates.addAll(database.loadPendingUpdates());
        reminders.addAll(database.loadReminders());
        gifts.addAll(database.loadGiftIdeas());
    }

    private void persistSeedData() {
        for (FriendPerson person : people) {
            database.insertPerson(person);
        }
        for (PendingUpdate update : pendingUpdates) {
            database.insertPendingUpdate(update);
        }
        for (ReminderItem reminder : reminders) {
            database.insertReminder(reminder);
        }
        for (GiftIdea gift : gifts) {
            database.insertGiftIdea(gift);
        }
    }

    private String localized(String chinese, String english) {
        return NativeCopy.forLanguage(settings.language).settingsTitle.equals("设置") ? chinese : english;
    }

    private void seedPreviewArtifacts() {
        if (files.isEmpty()) {
            files.add(new ImportedFile("f1", "IMG_20250512_1213.jpg", "OCR processing", 0.82));
            files.add(new ImportedFile("f2", "Lecture_Notes_ML.pdf", "23 notes extracted", 1));
            files.add(new ImportedFile("f3", "Wechat_Export_May.json", "Pending review", 0.35));
        }

        if (relationshipEdges.isEmpty()) {
            relationshipEdges.add(new RelationshipEdge("e1", "Alex Chen", "May Zhang", "Class project", 0.70));
            relationshipEdges.add(new RelationshipEdge("e2", "Jason Wu", "Alex Chen", "Career advice", 0.56));
            relationshipEdges.add(new RelationshipEdge("e3", "Nina Park", "May Zhang", "Study abroad", 0.62));
        }
    }

    private void seedDemoData() {
        people.add(new FriendPerson(
                "demo-alex",
                "Alex Chen",
                "Roommate - Classmate",
                GroupFilter.CLASSMATES,
                "Beijing / NYU",
                "Nov 3",
                "不吃香菜",
                "火锅、毛肚、虾滑",
                "临时改计划、太吵的自习室",
                "Scorpio",
                "INTJ",
                "数学、篮球、效率工具",
                "Atomic Habits, 置身事内",
                "篮球、健身",
                "室友, 考试, 火锅",
                "Calculus midterm on May 20",
                "AC"
        ));
        people.add(new FriendPerson(
                "demo-may",
                "May Zhang",
                "Close friend - Literature club",
                GroupFilter.HOME_FRIENDS,
                "Shanghai",
                "May 16",
                "少冰，不太能吃辣",
                "抹茶、日料、桂花乌龙",
                "敷衍的群发祝福",
                "Taurus",
                "INFP",
                "音乐、拍立得、文学社、香水",
                "夜航西飞, The Midnight Library",
                "瑜伽、散步",
                "生日, 礼物, 文学社",
                "Likes music, instant photos, and ritual gifts",
                "MZ"
        ));
        people.add(new FriendPerson(
                "demo-jason",
                "Jason Wu",
                "Senior - Internship referral",
                GroupFilter.INTERNSHIP,
                "NYC",
                "Aug 9",
                "工作日少糖",
                "冷萃、牛排、越南粉",
                "没有 agenda 的长会",
                "Leo",
                "ENTJ",
                "创业、跑步、职业规划",
                "The Hard Thing About Hard Things",
                "跑步、攀岩",
                "学长, 内推, 职业",
                "Starts full-time work in June",
                "JW"
        ));
        people.add(new FriendPerson(
                "demo-nina",
                "Nina Park",
                "Exchange friend - Seoul",
                GroupFilter.STUDY_ABROAD,
                "Seoul",
                "Feb 21",
                "少喝奶制品",
                "紫菜包饭、冷面、草莓蛋糕",
                "太临时的出行安排",
                "Aquarius",
                "ENFP",
                "旅行、韩语、摄影、城市漫步",
                "Pachinko, 旅行的艺术",
                "普拉提、徒步",
                "水瓶, 交换, 旅行",
                "Planning a study abroad reunion",
                "NP"
        ));

        pendingUpdates.add(new PendingUpdate(
                "p1",
                "Preference",
                "Alex does not eat cilantro and likes hotpot tripe and shrimp paste.",
                "Dinner note from yesterday with Alex",
                "Alex Chen",
                "Today, 8:45 PM"
        ));
        pendingUpdates.add(new PendingUpdate(
                "p2",
                "Event",
                "Alex has a calculus midterm on May 20 and wants a high score.",
                "Preparing for the May 20 calculus midterm",
                "Alex Chen",
                "Today, 8:40 PM"
        ));
        pendingUpdates.add(new PendingUpdate(
                "p3",
                "Birthday",
                "May's birthday is May 16; she likes music and instant photos.",
                "Birthday note captured from chat",
                "May Zhang",
                "Today, 7:12 PM"
        ));

        reminders.add(new ReminderItem("r1", "May Zhang birthday", "May Zhang", "May 16 - in 2 days"));
        reminders.add(new ReminderItem("r2", "Alex calculus midterm", "Alex Chen", "May 20 - in 6 days"));
        reminders.add(new ReminderItem("r3", "Group study", "Classmates", "May 18 - 7:00 PM"));

        gifts.add(new GiftIdea(
                "g1",
                "BYREDO fragrance set",
                "May Zhang",
                "$$",
                "May likes music, instant photos, and gifts with a ritual feeling."
        ));
        gifts.add(new GiftIdea(
                "g2",
                "AirPods Pro 2",
                "Alex Chen",
                "$$$",
                "Alex studies and commutes often, but the budget should be confirmed."
        ));

        seedPreviewArtifacts();
    }
}
