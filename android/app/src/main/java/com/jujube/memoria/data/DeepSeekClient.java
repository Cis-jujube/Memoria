package com.jujube.memoria.data;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.UUID;

public final class DeepSeekClient {
    public void testConnection(String apiKey, AppSettings settings) throws Exception {
        extract("Alex likes hotpot.", "Alex", apiKey, settings);
    }

    public PendingUpdate extract(String text, String personName, String apiKey, AppSettings settings) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL("https://api.deepseek.com/chat/completions").openConnection();
        connection.setRequestMethod("POST");
        connection.setConnectTimeout(20000);
        connection.setReadTimeout(30000);
        connection.setRequestProperty("Content-Type", "application/json");
        connection.setRequestProperty("Authorization", "Bearer " + apiKey);
        connection.setDoOutput(true);

        byte[] body = buildRequest(text, settings).toString().getBytes(StandardCharsets.UTF_8);
        try (OutputStream stream = connection.getOutputStream()) {
            stream.write(body);
        }

        int status = connection.getResponseCode();
        InputStream input = status >= 200 && status < 300
                ? connection.getInputStream()
                : connection.getErrorStream();
        String response = readAll(input);
        if (status < 200 || status >= 300) {
            throw new IllegalStateException("DeepSeek request failed with status " + status);
        }

        JSONObject json = new JSONObject(response);
        JSONArray choices = json.optJSONArray("choices");
        String content = choices == null || choices.length() == 0
                ? ""
                : choices.getJSONObject(0).getJSONObject("message").optString("content", "");
        if (content.trim().isEmpty()) {
            throw new IllegalStateException("DeepSeek returned empty content.");
        }

        return new PendingUpdate(
                "ai-" + UUID.randomUUID(),
                "AI",
                summarizeExtraction(content, text),
                text,
                personName == null || personName.trim().isEmpty() ? guessPersonName(text) : personName,
                "Just now"
        );
    }

    public JSONObject buildRequest(String text, AppSettings settings) throws Exception {
        JSONObject payload = new JSONObject();
        payload.put("model", normalizeModel(settings.model));

        JSONArray messages = new JSONArray();
        messages.put(new JSONObject()
                .put("role", "system")
                .put("content", "Extract friend relationship facts from student-life notes. Keep sensitive facts minimal and evidence-backed. Return only valid JSON with top-level people, reminders, and giftIdeas arrays."));
        messages.put(new JSONObject()
                .put("role", "user")
                .put("content", "Locale: " + resolvedLocale(settings.language) + "\nTimezone: local\nNote:\n" + text));
        payload.put("messages", messages);
        payload.put("response_format", new JSONObject().put("type", "json_object"));
        payload.put("thinking", new JSONObject().put("type", settings.deepThinking ? "enabled" : "disabled"));
        if (settings.deepThinking) {
            payload.put("reasoning_effort", "high");
        }
        payload.put("temperature", 0.1);
        payload.put("max_tokens", 1600);
        payload.put("stream", false);
        return payload;
    }

    private static String normalizeModel(String model) {
        if ("deepseek-v4-pro".equals(model)) {
            return "deepseek-v4-pro";
        }
        return "deepseek-v4-flash";
    }

    private static String resolvedLocale(String preference) {
        if ("zh-CN".equals(preference) || "en".equals(preference)) {
            return preference;
        }
        return Locale.getDefault().getLanguage().startsWith("zh") ? "zh-CN" : "en";
    }

    private static String summarizeExtraction(String content, String fallback) {
        try {
            JSONObject json = new JSONObject(content);
            JSONArray people = json.optJSONArray("people");
            if (people != null && people.length() > 0) {
                JSONArray updates = people.getJSONObject(0).optJSONArray("updates");
                if (updates != null && updates.length() > 0) {
                    String summary = updates.getJSONObject(0).optString("summary", "");
                    if (!summary.isEmpty()) {
                        return summary;
                    }
                }
            }
        } catch (Exception ignored) {
        }
        return fallback.length() > 96 ? fallback.substring(0, 93) + "..." : fallback;
    }

    private static String guessPersonName(String text) {
        String[] words = text.split("[^A-Za-z]+");
        for (String word : words) {
            if (!word.isEmpty() && Character.isUpperCase(word.charAt(0))) {
                return word;
            }
        }
        return "New friend";
    }

    private static String readAll(InputStream input) throws Exception {
        if (input == null) {
            return "";
        }
        StringBuilder builder = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                builder.append(line);
            }
        }
        return builder.toString();
    }
}
