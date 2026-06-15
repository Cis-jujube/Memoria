package com.jujube.memoria;

import android.app.Activity;
import android.content.res.Configuration;
import android.graphics.Typeface;
import android.os.Bundle;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.Button;
import android.widget.EditText;
import android.widget.GridLayout;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;

import com.jujube.memoria.data.AppSection;
import com.jujube.memoria.data.DashboardStore;
import com.jujube.memoria.data.FocusItem;
import com.jujube.memoria.data.FriendPerson;
import com.jujube.memoria.data.GiftIdea;
import com.jujube.memoria.data.GroupFilter;
import com.jujube.memoria.data.ImportedFile;
import com.jujube.memoria.data.NativeCopy;
import com.jujube.memoria.data.PendingUpdate;
import com.jujube.memoria.data.RelationshipEdge;
import com.jujube.memoria.data.ReminderItem;
import com.jujube.memoria.data.SearchResult;
import com.jujube.memoria.ui.RelationshipMapCanvas;
import com.jujube.memoria.ui.Ui;

import java.util.List;
import java.util.Map;

public final class MainActivity extends Activity {
    private DashboardStore store;

    private AppSection selectedSection = AppSection.BRIEF;
    private GroupFilter selectedGroup = GroupFilter.ALL;
    private FriendPerson selectedPerson;
    private String searchQuery = "";
    private String quickCaptureText = "";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        configureWindow();
        store = new DashboardStore(this);
        selectedPerson = store.people.isEmpty() ? null : store.people.get(0);
        render();
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        render();
    }

    private void configureWindow() {
        Window window = getWindow();
        window.setStatusBarColor(Ui.INK);
        window.setNavigationBarColor(Ui.CANVAS);
    }

    private boolean isWideLayout() {
        return getResources().getConfiguration().screenWidthDp >= 720;
    }

    private void render() {
        if (isWideLayout()) {
            renderWide();
        } else {
            renderPhone();
        }
    }

    private void renderWide() {
        LinearLayout root = Ui.horizontal(this);
        root.setBackgroundColor(Ui.CANVAS);

        LinearLayout sidebar = buildSidebar();
        root.addView(sidebar, new LinearLayout.LayoutParams(Ui.dp(this, 292), ViewGroup.LayoutParams.MATCH_PARENT));

        View divider = new View(this);
        divider.setBackgroundColor(0x14000000);
        root.addView(divider, new LinearLayout.LayoutParams(Ui.dp(this, 1), ViewGroup.LayoutParams.MATCH_PARENT));

        root.addView(buildContentFrame(), new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1));
        setContentView(root);
    }

    private void renderPhone() {
        LinearLayout root = Ui.vertical(this, 0);
        root.setBackgroundColor(Ui.CANVAS);
        root.addView(buildContentFrame(), Ui.matchWeight(1));
        root.addView(buildBottomNavigation(), Ui.matchWrap());
        setContentView(root);
    }

    private LinearLayout buildSidebar() {
        LinearLayout sidebar = Ui.vertical(this, 14);
        sidebar.setBackgroundColor(Ui.INK);
        Ui.pad(sidebar, 18);

        TextView title = Ui.text(this, "Memoria", 24, 0xFFFFFFFF, Typeface.BOLD);
        sidebar.addView(title, Ui.matchWrap());
        sidebar.addView(subtleText("Private friend memory", 13, 0xCCEEF2EF), Ui.matchWrap());
        sidebar.addView(spacer(12), Ui.matchWrap());

        sidebar.addView(sidebarLabel("COMMAND CENTER"), Ui.matchWrap());
        for (AppSection section : AppSection.values()) {
            sidebar.addView(navButton(titleFor(section), section, store.badgeFor(section), true), Ui.matchWrap());
        }

        sidebar.addView(spacer(18), Ui.matchWrap());
        sidebar.addView(sidebarLabel("GROUPS"), Ui.matchWrap());
        for (GroupFilter group : GroupFilter.values()) {
            if (group == GroupFilter.ALL) {
                continue;
            }
            sidebar.addView(groupButton(group), Ui.matchWrap());
        }

        return sidebar;
    }

    private View buildBottomNavigation() {
        HorizontalScrollView scroll = new HorizontalScrollView(this);
        scroll.setHorizontalScrollBarEnabled(false);
        scroll.setBackgroundColor(Ui.INK);

        LinearLayout row = Ui.horizontal(this);
        Ui.pad(row, 10, 8);
        for (AppSection section : AppSection.values()) {
            row.addView(navButton(titleFor(section), section, store.badgeFor(section), false));
        }
        scroll.addView(row);
        return scroll;
    }

    private View buildContentFrame() {
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setBackgroundColor(Ui.CANVAS);

        LinearLayout content = Ui.vertical(this, 16);
        Ui.pad(content, isWideLayout() ? 24 : 16);
        content.addView(sectionHeader(titleFor(selectedSection), subtitleFor(selectedSection)), Ui.matchWrap());
        content.addView(buildSectionContent(), Ui.matchWrap());

        scroll.addView(content, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        ));
        return scroll;
    }

    private View buildSectionContent() {
        switch (selectedSection) {
            case BRIEF:
                return buildBrief();
            case INBOX:
                return buildInbox();
            case PEOPLE:
                return buildPeople();
            case CALENDAR:
                return buildCalendar();
            case REMINDERS:
                return buildReminders();
            case GIFTS:
                return buildGifts();
            case SEARCH:
                return buildSearch();
            case MAP:
                return buildRelationshipMap();
            case FILES:
                return buildFiles();
            case SETTINGS:
                return buildSettings();
            default:
                return buildBrief();
        }
    }

    private View buildBrief() {
        LinearLayout layout = Ui.vertical(this, 16);

        GridLayout metrics = new GridLayout(this);
        metrics.setColumnCount(isWideLayout() ? 4 : 2);
        metrics.addView(metricCard("Active people", store.people.size(), "People"));
        metrics.addView(metricCard("AI updates", store.pendingUpdates.size(), "Inbox"));
        metrics.addView(metricCard("Reminders", store.reminders.size(), "Due"));
        metrics.addView(metricCard("Gift ideas", store.gifts.size(), "Gifts"));
        layout.addView(metrics, Ui.matchWrap());

        LinearLayout focusCard = card();
        focusCard.addView(titleText("Today Focus", 20), Ui.matchWrap());
        List<FocusItem> items = store.focusItems();
        if (items.isEmpty()) {
            focusCard.addView(bodyText("No urgent relationship work."), Ui.matchWrap());
        } else {
            for (FocusItem item : items) {
                Button button = plainButton(item.label + "\n" + item.detail);
                button.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
                button.setOnClickListener(view -> {
                    selectedSection = item.targetSection;
                    render();
                });
                focusCard.addView(button, Ui.matchWrap());
            }
        }
        layout.addView(focusCard, Ui.matchWrap());

        layout.addView(barChart("Group distribution", store.groupCounts()), Ui.matchWrap());
        layout.addView(quickCaptureCard(), Ui.matchWrap());

        return layout;
    }

    private View buildInbox() {
        LinearLayout layout = Ui.vertical(this, 14);
        NativeCopy copy = store.copy();

        if (store.pendingUpdates.isEmpty()) {
            layout.addView(emptyState(
                    isChinese() ? "待确认里是空的" : "AI Inbox is clear",
                    isChinese() ? "新的记录和导入内容会先放在这里，确认后才会写进联系人档案。" : "New captures and imports will wait here for review."
            ), Ui.matchWrap());
            return layout;
        }

        for (PendingUpdate update : store.pendingUpdates.toArray(new PendingUpdate[0])) {
            LinearLayout card = card();
            card.addView(pill(update.type + " - " + update.createdLabel), Ui.matchWrap());
            card.addView(titleText(update.personName, 19), Ui.matchWrap());
            card.addView(bodyText(update.summary), Ui.matchWrap());
            card.addView(citationBlock(copy.whySuggested, update.evidence), Ui.matchWrap());

            LinearLayout actions = Ui.horizontal(this);
            actions.setGravity(Gravity.END);
            Button discard = secondaryButton(isChinese() ? "放弃" : "Discard");
            discard.setOnClickListener(view -> {
                store.removePending(update);
                render();
            });
            Button confirm = primaryButton(isChinese() ? "确认" : "Confirm");
            confirm.setOnClickListener(view -> {
                store.removePending(update);
                render();
            });
            actions.addView(discard);
            actions.addView(confirm);
            card.addView(actions, Ui.matchWrap());
            layout.addView(card, Ui.matchWrap());
        }

        return layout;
    }

    private View buildPeople() {
        LinearLayout layout = Ui.vertical(this, 14);
        layout.addView(groupChips(), Ui.matchWrap());

        List<FriendPerson> people = store.visiblePeople(selectedGroup);
        if (people.isEmpty()) {
            layout.addView(emptyState("No people in this group", "Switch groups or capture a new relationship signal."), Ui.matchWrap());
            return layout;
        }

        for (FriendPerson person : people) {
            LinearLayout card = card();
            LinearLayout row = Ui.horizontal(this);

            TextView avatar = Ui.text(this, person.initials, 18, 0xFFFFFFFF, Typeface.BOLD);
            avatar.setGravity(Gravity.CENTER);
            avatar.setBackground(Ui.rounded(Ui.INK, 8, this));
            row.addView(avatar, new LinearLayout.LayoutParams(Ui.dp(this, 54), Ui.dp(this, 54)));

            LinearLayout meta = Ui.vertical(this, 4);
            meta.setPadding(Ui.dp(this, 12), 0, 0, 0);
            meta.addView(titleText(person.displayName, 20), Ui.matchWrap());
            meta.addView(subtleText(person.relationLabel, 14, Ui.MUTED), Ui.matchWrap());
            meta.addView(subtleText(person.location, 13, Ui.MUTED), Ui.matchWrap());
            row.addView(meta, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
            card.addView(row, Ui.matchWrap());

            card.addView(bodyText("Last signal: " + person.lastSignal), Ui.matchWrap());
            card.addView(pill(person.groupLabel.title + " - " + person.birthday), Ui.matchWrap());
            card.addView(profileGrid(person), Ui.matchWrap());
            card.addView(citationBlock("Next action", store.nextActionFor(person)), Ui.matchWrap());
            layout.addView(card, Ui.matchWrap());
        }

        return layout;
    }

    private View buildCalendar() {
        LinearLayout layout = Ui.vertical(this, 14);

        for (FriendPerson person : store.people) {
            LinearLayout card = card();
            card.addView(titleText((isChinese() ? "生日 · " : "Birthday · ") + person.displayName, 18), Ui.matchWrap());
            card.addView(pill(person.birthday), Ui.matchWrap());
            card.addView(bodyText(person.favoriteFoods.isEmpty() ? person.lastSignal : person.favoriteFoods), Ui.matchWrap());
            layout.addView(card, Ui.matchWrap());
        }

        for (ReminderItem reminder : store.reminders) {
            LinearLayout card = card();
            card.addView(titleText(reminder.title, 18), Ui.matchWrap());
            card.addView(bodyText(reminder.personName), Ui.matchWrap());
            card.addView(pill(reminder.dueLabel), Ui.matchWrap());
            layout.addView(card, Ui.matchWrap());
        }

        if (store.people.isEmpty() && store.reminders.isEmpty()) {
            layout.addView(emptyState(
                    isChinese() ? "还没有日历事件" : "No calendar moments",
                    isChinese() ? "确认生日、提醒或计划后，这里会自动出现。" : "Confirmed birthdays, reminders, and plans will appear here."
            ), Ui.matchWrap());
        }

        return layout;
    }

    private View buildReminders() {
        LinearLayout layout = Ui.vertical(this, 14);
        if (store.reminders.isEmpty()) {
            layout.addView(emptyState("No reminders", "Create reminders from people, captures, or imported memories."), Ui.matchWrap());
            return layout;
        }

        for (ReminderItem reminder : store.reminders) {
            LinearLayout card = card();
            card.addView(titleText(reminder.title, 19), Ui.matchWrap());
            card.addView(bodyText(reminder.personName), Ui.matchWrap());
            card.addView(pill(reminder.dueLabel), Ui.matchWrap());
            layout.addView(card, Ui.matchWrap());
        }

        return layout;
    }

    private View buildGifts() {
        LinearLayout layout = Ui.vertical(this, 14);
        if (store.gifts.isEmpty()) {
            layout.addView(emptyState("No gift ideas yet", "Gift recommendations should cite stored preferences and memories."), Ui.matchWrap());
            return layout;
        }

        for (GiftIdea gift : store.gifts) {
            LinearLayout card = card();
            card.addView(titleText(gift.title, 20), Ui.matchWrap());
            card.addView(pill(gift.personName + " - " + gift.priceBand), Ui.matchWrap());
            card.addView(bodyText(gift.rationale), Ui.matchWrap());
            card.addView(citationBlock("Rationale", "Cites stored profile facts and captured memories."), Ui.matchWrap());
            layout.addView(card, Ui.matchWrap());
        }

        return layout;
    }

    private View buildSearch() {
        LinearLayout layout = Ui.vertical(this, 14);

        EditText search = new EditText(this);
        search.setSingleLine(false);
        search.setMinLines(1);
        search.setMaxLines(3);
        search.setText(searchQuery);
        search.setHint("Ask about a friend, gift, birthday, or reminder");
        search.setTextColor(Ui.INK);
        search.setHintTextColor(Ui.MUTED);
        search.setBackground(Ui.roundedStroke(Ui.CARD, 8, Ui.BORDER, this));
        Ui.pad(search, 12, 10);
        search.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence sequence, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence sequence, int start, int before, int count) {
                searchQuery = sequence.toString();
                renderSearchResults(layout, search);
            }

            @Override
            public void afterTextChanged(Editable editable) {
            }
        });
        layout.addView(search, Ui.matchWrap());

        renderSearchResults(layout, search);
        return layout;
    }

    private void renderSearchResults(LinearLayout layout, EditText searchField) {
        while (layout.getChildCount() > 1) {
            layout.removeViewAt(1);
        }

        if (searchQuery.trim().isEmpty()) {
            LinearLayout suggestions = card();
            suggestions.addView(titleText("Try asking", 18), Ui.matchWrap());
            for (String suggestion : store.askSuggestions()) {
                Button button = plainButton(suggestion);
                button.setOnClickListener(view -> {
                    searchQuery = suggestion;
                    searchField.setText(suggestion);
                    searchField.setSelection(searchField.getText().length());
                });
                suggestions.addView(button, Ui.matchWrap());
            }
            layout.addView(suggestions, Ui.matchWrap());
            return;
        }

        List<SearchResult> results = store.search(searchQuery);
        if (results.isEmpty()) {
            layout.addView(emptyState("No cited memory found", "Try a friend name, preference, reminder, or gift keyword."), Ui.matchWrap());
            return;
        }

        for (SearchResult result : results) {
            LinearLayout card = card();
            card.addView(titleText(result.title, 19), Ui.matchWrap());
            card.addView(bodyText(result.excerpt), Ui.matchWrap());
            card.addView(pill(result.source), Ui.matchWrap());
            layout.addView(card, Ui.matchWrap());
        }
    }

    private View buildRelationshipMap() {
        LinearLayout layout = Ui.vertical(this, 14);
        if (store.relationshipEdges.isEmpty()) {
            layout.addView(emptyState("No relationship edges", "Edges can be inferred from confirmed memories, groups, and shared events."), Ui.matchWrap());
            return layout;
        }

        LinearLayout canvasCard = card();
        canvasCard.addView(new RelationshipMapCanvas(this, store.relationshipEdges), new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                Ui.dp(this, isWideLayout() ? 320 : 260)
        ));
        layout.addView(canvasCard, Ui.matchWrap());

        for (RelationshipEdge edge : store.relationshipEdges) {
            LinearLayout card = card();
            card.addView(titleText(edge.sourceName + " -> " + edge.targetName, 18), Ui.matchWrap());
            card.addView(bodyText(edge.label + " - " + Math.round(edge.strength * 100) + "%"), Ui.matchWrap());
            layout.addView(card, Ui.matchWrap());
        }
        return layout;
    }

    private View buildFiles() {
        LinearLayout layout = Ui.vertical(this, 14);
        layout.addView(barChart("Import funnel", store.fileStatusCounts()), Ui.matchWrap());

        if (store.files.isEmpty()) {
            layout.addView(emptyState("No imported files", "Photos, PDFs, and chat exports will show parse status here."), Ui.matchWrap());
            return layout;
        }

        for (ImportedFile file : store.files) {
            LinearLayout card = card();
            card.addView(titleText(file.filename, 18), Ui.matchWrap());
            card.addView(bodyText(file.status), Ui.matchWrap());
            ProgressBar progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
            progress.setMax(100);
            progress.setProgress((int) Math.round(file.progress * 100));
            card.addView(progress, Ui.matchWrap());
            layout.addView(card, Ui.matchWrap());
        }

        return layout;
    }

    private View buildSettings() {
        NativeCopy copy = store.copy();
        LinearLayout layout = Ui.vertical(this, 14);

        LinearLayout deepSeekCard = card();
        deepSeekCard.addView(titleText(copy.deepSeekSectionTitle, 20), Ui.matchWrap());
        deepSeekCard.addView(subtleText(
                store.settings.hasApiKey
                        ? (isChinese() ? "已保存密钥。出于安全考虑，这里不会显示完整内容。" : "A key is saved. The full value is never shown here.")
                        : (isChinese() ? "还没有保存 DeepSeek API key。" : "No DeepSeek API key is saved yet."),
                13,
                Ui.MUTED
        ), Ui.matchWrap());

        EditText apiKeyInput = new EditText(this);
        apiKeyInput.setSingleLine(true);
        apiKeyInput.setHint(copy.apiKeyPlaceholder);
        apiKeyInput.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        apiKeyInput.setTextColor(Ui.INK);
        apiKeyInput.setHintTextColor(Ui.MUTED);
        apiKeyInput.setBackground(Ui.roundedStroke(0xFFF8FAF8, 8, Ui.BORDER, this));
        Ui.pad(apiKeyInput, 12, 10);
        deepSeekCard.addView(apiKeyInput, Ui.matchWrap());

        LinearLayout keyActions = Ui.horizontal(this);
        Button saveKey = primaryButton(copy.saveKey);
        saveKey.setOnClickListener(view -> {
            try {
                store.saveApiKey(apiKeyInput.getText().toString());
            } catch (Exception exception) {
                store.statusMessage = (isChinese() ? "保存密钥失败：" : "Failed to save key: ") + exception.getMessage();
            }
            render();
        });
        Button test = secondaryButton(copy.testConnection);
        test.setOnClickListener(view -> {
            test.setEnabled(false);
            new Thread(() -> {
                try {
                    store.testConnection();
                } catch (Exception exception) {
                    store.statusMessage = (isChinese() ? "连接失败：" : "Connection failed: ") + exception.getMessage();
                }
                runOnUiThread(this::render);
            }).start();
        });
        keyActions.addView(saveKey, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        keyActions.addView(test, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        deepSeekCard.addView(keyActions, Ui.matchWrap());

        Button removeKey = secondaryButton(copy.removeKey);
        removeKey.setOnClickListener(view -> {
            store.removeApiKey();
            render();
        });
        deepSeekCard.addView(removeKey, Ui.matchWrap());

        deepSeekCard.addView(subtleText(copy.modelLabel, 13, Ui.MUTED), Ui.matchWrap());
        LinearLayout modelRow = Ui.horizontal(this);
        Button flash = chip("Flash", "deepseek-v4-flash".equals(store.settings.model));
        flash.setOnClickListener(view -> {
            store.settings.model = "deepseek-v4-flash";
            store.saveSettings();
            render();
        });
        Button pro = chip("Pro", "deepseek-v4-pro".equals(store.settings.model));
        pro.setOnClickListener(view -> {
            store.settings.model = "deepseek-v4-pro";
            store.saveSettings();
            render();
        });
        modelRow.addView(flash);
        modelRow.addView(pro);
        deepSeekCard.addView(modelRow, Ui.matchWrap());

        Button thinking = chip(
                copy.deepThinkingLabel + ": " + (store.settings.deepThinking ? (isChinese() ? "开" : "On") : (isChinese() ? "关" : "Off")),
                store.settings.deepThinking
        );
        thinking.setOnClickListener(view -> {
            store.settings.deepThinking = !store.settings.deepThinking;
            store.saveSettings();
            render();
        });
        deepSeekCard.addView(thinking, Ui.matchWrap());
        layout.addView(deepSeekCard, Ui.matchWrap());

        LinearLayout languageCard = card();
        languageCard.addView(titleText(copy.languageLabel, 20), Ui.matchWrap());
        LinearLayout languageRow = Ui.horizontal(this);
        addLanguageButton(languageRow, "system", isChinese() ? "跟随系统" : "System");
        addLanguageButton(languageRow, "zh-CN", "中文");
        addLanguageButton(languageRow, "en", "English");
        languageCard.addView(languageRow, Ui.matchWrap());
        layout.addView(languageCard, Ui.matchWrap());

        LinearLayout syncCard = card();
        syncCard.addView(titleText(isChinese() ? "账号与同步" : "Account & Sync", 20), Ui.matchWrap());
        syncCard.addView(bodyText(isChinese()
                ? "之后可以登录同一个账号，把手机和电脑上的联系人、记忆、提醒同步到你的自托管服务器。DeepSeek API key 不参与同步，只留在这台设备。"
                : "Sign in later to sync people, memories, and reminders across your devices through your self-hosted server. The DeepSeek API key stays on this device and is never synced."
        ), Ui.matchWrap());
        syncCard.addView(subtleText(
                isChinese() ? "本地优先，离线也能用。服务器地址和账号登录待接入。" : "Local-first and usable offline. Server URL and account login are planned next.",
                13,
                Ui.MUTED
        ), Ui.matchWrap());
        layout.addView(syncCard, Ui.matchWrap());

        LinearLayout privacyCard = card();
        privacyCard.addView(titleText(isChinese() ? "隐私说明" : "Privacy", 20), Ui.matchWrap());
        privacyCard.addView(bodyText(copy.deepseekPrivacyNote), Ui.matchWrap());
        layout.addView(privacyCard, Ui.matchWrap());

        if (!store.statusMessage.isEmpty()) {
            LinearLayout statusCard = card();
            statusCard.addView(bodyText(store.statusMessage), Ui.matchWrap());
            layout.addView(statusCard, Ui.matchWrap());
        }

        return layout;
    }

    private View quickCaptureCard() {
        LinearLayout card = card();
        NativeCopy copy = store.copy();
        card.addView(titleText(isChinese() ? "快速记录" : "Quick Capture", 20), Ui.matchWrap());
        EditText input = new EditText(this);
        input.setMinLines(2);
        input.setMaxLines(5);
        input.setText(quickCaptureText);
        input.setHint(isChinese() ? "写下一条记忆、计划、偏好或提醒线索..." : "Type a memory, plan, preference, or reminder signal...");
        input.setBackground(Ui.roundedStroke(0xFFF8FAF8, 8, Ui.BORDER, this));
        Ui.pad(input, 12, 10);
        input.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence sequence, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence sequence, int start, int before, int count) {
                quickCaptureText = sequence.toString();
            }

            @Override
            public void afterTextChanged(Editable editable) {
            }
        });
        card.addView(input, Ui.matchWrap());
        card.addView(subtleText(
                isChinese() ? "记录会先进入待确认；你确认之前，联系人档案不会被改动。" : "Capture creates a pending AI update. Profiles are not changed until reviewed.",
                13,
                Ui.MUTED
        ), Ui.matchWrap());

        Button send = primaryButton(copy.sendToInbox);
        send.setOnClickListener(view -> {
            String text = quickCaptureText;
            quickCaptureText = "";
            send.setEnabled(false);
            new Thread(() -> {
                store.addCapture(text, selectedPerson);
                runOnUiThread(() -> {
                    selectedSection = AppSection.INBOX;
                    render();
                });
            }).start();
        });
        card.addView(send, Ui.matchWrap());
        if (!store.statusMessage.isEmpty()) {
            card.addView(subtleText(store.statusMessage, 13, Ui.MUTED), Ui.matchWrap());
        }
        return card;
    }

    private View groupChips() {
        HorizontalScrollView scroll = new HorizontalScrollView(this);
        scroll.setHorizontalScrollBarEnabled(false);
        LinearLayout row = Ui.horizontal(this);
        for (GroupFilter group : GroupFilter.values()) {
            Button button = chip(group.title + " " + store.countFor(group), selectedGroup == group);
            button.setOnClickListener(view -> {
                selectedGroup = group;
                List<FriendPerson> people = store.visiblePeople(selectedGroup);
                selectedPerson = people.isEmpty() ? null : people.get(0);
                render();
            });
            row.addView(button);
        }
        scroll.addView(row);
        return scroll;
    }

    private View navButton(String label, AppSection section, int badge, boolean sidebar) {
        boolean active = selectedSection == section;
        String text = badge > 0 ? label + "  " + badge : label;
        Button button = new Button(this);
        button.setAllCaps(false);
        button.setMinHeight(Ui.dp(this, 44));
        button.setText(text);
        button.setGravity(sidebar ? Gravity.CENTER_VERTICAL | Gravity.START : Gravity.CENTER);
        button.setTextColor(active ? Ui.INK : 0xFFE2EAE5);
        button.setBackground(Ui.rounded(active ? 0xFFE2EAE5 : 0x0017372D, 8, this));
        Ui.pad(button, 12, 8);
        button.setOnClickListener(view -> {
            selectedSection = section;
            render();
        });
        return button;
    }

    private View groupButton(GroupFilter group) {
        boolean active = selectedSection == AppSection.PEOPLE && selectedGroup == group;
        Button button = new Button(this);
        button.setAllCaps(false);
        button.setText(group.title + "  " + store.countFor(group));
        button.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
        button.setTextColor(active ? Ui.INK : 0xCCDCE6DF);
        button.setBackground(Ui.rounded(active ? 0xFFE2EAE5 : 0x0017372D, 8, this));
        Ui.pad(button, 12, 8);
        button.setOnClickListener(view -> {
            selectedSection = AppSection.PEOPLE;
            selectedGroup = group;
            List<FriendPerson> people = store.visiblePeople(group);
            selectedPerson = people.isEmpty() ? null : people.get(0);
            render();
        });
        return button;
    }

    private void addLanguageButton(LinearLayout row, String value, String label) {
        Button button = chip(label, value.equals(store.settings.language));
        button.setOnClickListener(view -> {
            store.settings.language = value;
            store.saveSettings();
            render();
        });
        row.addView(button);
    }

    private View metricCard(String label, int count, String caption) {
        LinearLayout card = card();
        card.addView(subtleText(caption, 12, Ui.SAGE), Ui.matchWrap());
        card.addView(Ui.text(this, String.valueOf(count), 30, Ui.INK, Typeface.BOLD), Ui.matchWrap());
        card.addView(subtleText(label, 13, Ui.MUTED), Ui.matchWrap());
        GridLayout.LayoutParams params = new GridLayout.LayoutParams();
        params.width = 0;
        params.height = ViewGroup.LayoutParams.WRAP_CONTENT;
        params.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f);
        params.setMargins(Ui.dp(this, 0), Ui.dp(this, 0), Ui.dp(this, 10), Ui.dp(this, 10));
        card.setLayoutParams(params);
        return card;
    }

    private View profileGrid(FriendPerson person) {
        LinearLayout grid = Ui.vertical(this, 8);
        grid.addView(profileFact(isChinese() ? "忌口" : "Dietary", person.dietaryRestrictions), Ui.matchWrap());
        grid.addView(profileFact(isChinese() ? "喜欢吃的" : "Favorite foods", person.favoriteFoods), Ui.matchWrap());
        grid.addView(profileFact(isChinese() ? "不喜欢" : "Dislikes", person.dislikedThings), Ui.matchWrap());
        grid.addView(profileFact(isChinese() ? "星座" : "Zodiac", person.zodiacSign), Ui.matchWrap());
        grid.addView(profileFact("MBTI", person.mbti), Ui.matchWrap());
        grid.addView(profileFact(isChinese() ? "兴趣爱好" : "Interests", person.interests), Ui.matchWrap());
        grid.addView(profileFact(isChinese() ? "在看的书" : "Books", person.books), Ui.matchWrap());
        grid.addView(profileFact(isChinese() ? "运动" : "Sports", person.sports), Ui.matchWrap());
        grid.addView(profileFact(isChinese() ? "标签" : "Tags", person.profileTags), Ui.matchWrap());
        return grid;
    }

    private View profileFact(String label, String value) {
        LinearLayout block = Ui.vertical(this, 3);
        block.setBackground(Ui.rounded(0xFFF4F7F4, 8, this));
        Ui.pad(block, 10, 8);
        block.addView(subtleText(label, 12, Ui.MUTED), Ui.matchWrap());
        block.addView(bodyText(value == null || value.isEmpty() ? "-" : value), Ui.matchWrap());
        return block;
    }

    private View barChart(String title, Map<String, Integer> values) {
        LinearLayout card = card();
        card.addView(titleText(title, 18), Ui.matchWrap());
        int max = 1;
        for (Integer value : values.values()) {
            max = Math.max(max, value);
        }

        for (Map.Entry<String, Integer> entry : values.entrySet()) {
            LinearLayout row = Ui.vertical(this, 4);
            row.addView(subtleText(entry.getKey() + " - " + entry.getValue(), 13, Ui.MUTED), Ui.matchWrap());

            LinearLayout track = new LinearLayout(this);
            track.setBackground(Ui.rounded(0xFFE2EAE5, 5, this));
            View fill = new View(this);
            fill.setBackground(Ui.rounded(Ui.SAGE, 5, this));
            track.addView(fill, new LinearLayout.LayoutParams(0, Ui.dp(this, 10), Math.max(1, entry.getValue())));
            track.addView(new View(this), new LinearLayout.LayoutParams(0, Ui.dp(this, 10), Math.max(0, max - entry.getValue())));
            row.addView(track, Ui.matchWrap());
            card.addView(row, Ui.matchWrap());
        }
        return card;
    }

    private LinearLayout card() {
        LinearLayout card = Ui.vertical(this, 10);
        card.setBackground(Ui.roundedStroke(Ui.CARD, 8, Ui.BORDER, this));
        Ui.pad(card, 14);
        LinearLayout.LayoutParams params = Ui.matchWrap();
        params.setMargins(0, 0, 0, Ui.dp(this, 12));
        card.setLayoutParams(params);
        return card;
    }

    private View sectionHeader(String title, String subtitle) {
        LinearLayout header = Ui.vertical(this, 4);
        header.addView(Ui.text(this, title, isWideLayout() ? 30 : 25, Ui.INK, Typeface.BOLD), Ui.matchWrap());
        header.addView(subtleText(subtitle, 15, Ui.MUTED), Ui.matchWrap());
        return header;
    }

    private View emptyState(String title, String detail) {
        LinearLayout card = card();
        card.setGravity(Gravity.CENTER);
        card.addView(titleText(title, 20), Ui.matchWrap());
        TextView detailView = bodyText(detail);
        detailView.setGravity(Gravity.CENTER);
        card.addView(detailView, Ui.matchWrap());
        return card;
    }

    private TextView titleText(String value, float sp) {
        return Ui.text(this, value, sp, Ui.INK, Typeface.BOLD);
    }

    private TextView bodyText(String value) {
        TextView view = Ui.text(this, value, 15, Ui.INK, Typeface.NORMAL);
        view.setLineSpacing(Ui.dp(this, 2), 1);
        return view;
    }

    private TextView subtleText(String value, float sp, int color) {
        return Ui.text(this, value, sp, color, Typeface.NORMAL);
    }

    private TextView sidebarLabel(String value) {
        TextView label = Ui.text(this, value, 12, 0x99EEF2EF, Typeface.BOLD);
        label.setLetterSpacing(0.08f);
        return label;
    }

    private TextView pill(String value) {
        TextView pill = Ui.text(this, value, 13, Ui.INK, Typeface.BOLD);
        pill.setBackground(Ui.rounded(0xFFE2EAE5, 999, this));
        Ui.pad(pill, 10, 6);
        return pill;
    }

    private View citationBlock(String label, String text) {
        LinearLayout block = Ui.vertical(this, 4);
        block.setBackground(Ui.rounded(0xFFF4F7F4, 8, this));
        Ui.pad(block, 12, 10);
        block.addView(subtleText(label, 12, Ui.MUTED), Ui.matchWrap());
        block.addView(bodyText(text), Ui.matchWrap());
        return block;
    }

    private Button primaryButton(String text) {
        Button button = new Button(this);
        button.setAllCaps(false);
        button.setText(text);
        button.setTextColor(0xFFFFFFFF);
        button.setBackground(Ui.rounded(Ui.INK, 8, this));
        button.setMinHeight(Ui.dp(this, 48));
        return button;
    }

    private Button secondaryButton(String text) {
        Button button = new Button(this);
        button.setAllCaps(false);
        button.setText(text);
        button.setTextColor(Ui.INK);
        button.setBackground(Ui.roundedStroke(0x00000000, 8, Ui.BORDER, this));
        button.setMinHeight(Ui.dp(this, 48));
        return button;
    }

    private Button plainButton(String text) {
        Button button = new Button(this);
        button.setAllCaps(false);
        button.setText(text);
        button.setTextColor(Ui.INK);
        button.setBackground(Ui.rounded(0xFFF4F7F4, 8, this));
        button.setMinHeight(Ui.dp(this, 48));
        return button;
    }

    private Button chip(String text, boolean active) {
        Button button = new Button(this);
        button.setAllCaps(false);
        button.setText(text);
        button.setTextColor(active ? 0xFFFFFFFF : Ui.INK);
        button.setBackground(Ui.rounded(active ? Ui.INK : Ui.CARD, 999, this));
        button.setMinHeight(Ui.dp(this, 42));
        Ui.pad(button, 12, 6);
        return button;
    }

    private View spacer(int heightDp) {
        View view = new View(this);
        view.setLayoutParams(new LinearLayout.LayoutParams(1, Ui.dp(this, heightDp)));
        return view;
    }

    private boolean isChinese() {
        String language = store.settings.language;
        if ("zh-CN".equals(language)) {
            return true;
        }
        if ("en".equals(language)) {
            return false;
        }
        return java.util.Locale.getDefault().getLanguage().startsWith("zh");
    }

    private String titleFor(AppSection section) {
        if (!isChinese()) {
            return section.title;
        }

        switch (section) {
            case BRIEF:
                return "今日概览";
            case INBOX:
                return store.copy().aiInboxTitle;
            case PEOPLE:
                return "联系人";
            case CALENDAR:
                return "日历";
            case REMINDERS:
                return "提醒";
            case GIFTS:
                return "礼物想法";
            case SEARCH:
                return "搜索";
            case MAP:
                return "关系图";
            case FILES:
                return "文件导入";
            case SETTINGS:
                return store.copy().settingsTitle;
            default:
                return section.title;
        }
    }

    private String subtitleFor(AppSection section) {
        if (isChinese()) {
            switch (section) {
                case BRIEF:
                    return "把重要的人和最近的线索放在一个地方。";
                case INBOX:
                    return "先确认，再写进联系人档案。";
                case PEOPLE:
                    return selectedGroup == GroupFilter.ALL ? "所有关系分组。" : selectedGroup.title;
                case CALENDAR:
                    return "生日、提醒、考试和聚会放在一条时间线上看。";
                case REMINDERS:
                    return "近期要跟进的事情和人生节点。";
                case GIFTS:
                    return "基于已保存线索的礼物建议。";
                case SEARCH:
                    return "从联系人、记忆、提醒和礼物里查找。";
                case MAP:
                    return "轻量查看朋友之间的关系线索。";
                case FILES:
                    return "导入内容确认前不会改动档案。";
                case SETTINGS:
                    return "DeepSeek、语言和本地隐私设置。";
                default:
                    return "";
            }
        }

        switch (section) {
            case BRIEF:
                return "Private command center for relationship memory.";
            case INBOX:
                return "Confirm before memories change.";
            case PEOPLE:
                return selectedGroup == GroupFilter.ALL ? "All relationship groups." : selectedGroup.title;
            case CALENDAR:
                return "Birthdays, reminders, exams, and gatherings in one timeline.";
            case REMINDERS:
                return "Upcoming follow-ups and life events.";
            case GIFTS:
                return "Recommendations with source-backed rationale.";
            case SEARCH:
                return "Ask from stored people, memories, reminders, and gifts.";
            case MAP:
                return "Lightweight relationship edges.";
            case FILES:
                return "Import status before memories are changed.";
            case SETTINGS:
                return "DeepSeek, language, and local privacy settings.";
            default:
                return "";
        }
    }
}
