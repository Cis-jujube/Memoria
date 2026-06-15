package com.jujube.memoria.data;

import java.util.Locale;

public final class NativeCopy {
    public final String aiInboxTitle;
    public final String whySuggested;
    public final String settingsTitle;
    public final String deepSeekSectionTitle;
    public final String apiKeyPlaceholder;
    public final String saveKey;
    public final String testConnection;
    public final String removeKey;
    public final String modelLabel;
    public final String deepThinkingLabel;
    public final String languageLabel;
    public final String deepseekPrivacyNote;
    public final String missingKeyMessage;
    public final String sendToInbox;

    private NativeCopy(
            String aiInboxTitle,
            String whySuggested,
            String settingsTitle,
            String deepSeekSectionTitle,
            String apiKeyPlaceholder,
            String saveKey,
            String testConnection,
            String removeKey,
            String modelLabel,
            String deepThinkingLabel,
            String languageLabel,
            String deepseekPrivacyNote,
            String missingKeyMessage,
            String sendToInbox
    ) {
        this.aiInboxTitle = aiInboxTitle;
        this.whySuggested = whySuggested;
        this.settingsTitle = settingsTitle;
        this.deepSeekSectionTitle = deepSeekSectionTitle;
        this.apiKeyPlaceholder = apiKeyPlaceholder;
        this.saveKey = saveKey;
        this.testConnection = testConnection;
        this.removeKey = removeKey;
        this.modelLabel = modelLabel;
        this.deepThinkingLabel = deepThinkingLabel;
        this.languageLabel = languageLabel;
        this.deepseekPrivacyNote = deepseekPrivacyNote;
        this.missingKeyMessage = missingKeyMessage;
        this.sendToInbox = sendToInbox;
    }

    public static NativeCopy forLanguage(String preference) {
        String language = preference == null ? "system" : preference;
        boolean useChinese = "zh-CN".equals(language)
                || ("system".equals(language) && Locale.getDefault().getLanguage().startsWith("zh"));

        if (useChinese) {
            return new NativeCopy(
                    "待确认",
                    "为什么建议这样记",
                    "设置",
                    "DeepSeek 接入",
                    "粘贴你的 DeepSeek API key",
                    "保存密钥",
                    "测试连接",
                    "移除密钥",
                    "模型",
                    "深度思考",
                    "界面语言",
                    "开启 AI 识别后，你输入的记忆内容会发送给 DeepSeek 处理。密钥只保存在本机安全存储里，不写进本地数据库。",
                    "还没有保存 DeepSeek API key。先去设置里填一下，再用 AI 识别。",
                    "发送到待确认"
            );
        }

        return new NativeCopy(
                "AI Inbox",
                "Why AI suggested this",
                "Settings",
                "DeepSeek",
                "Paste your DeepSeek API key",
                "Save key",
                "Test connection",
                "Remove key",
                "Model",
                "Deep thinking",
                "Language",
                "AI capture sends the text you enter to DeepSeek. Your API key stays in local secure storage and is not written to SQLite.",
                "No DeepSeek API key is saved yet. Add one in Settings before using AI capture.",
                "Send to AI Inbox"
        );
    }
}
