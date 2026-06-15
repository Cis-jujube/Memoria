use chrono::Local;
use keyring::Entry;
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{fs, path::PathBuf};
use tauri::Manager;

const KEYRING_SERVICE: &str = "com.jujube.memoria.deepseek";
const KEYRING_ACCOUNT: &str = "deepseek-api-key";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct AppSettings {
    model: String,
    deep_thinking: bool,
    language: String,
    has_api_key: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct Person {
    id: String,
    display_name: String,
    relation_label: String,
    group_label: String,
    location: String,
    birthday: String,
    dietary_restrictions: String,
    favorite_foods: String,
    disliked_things: String,
    zodiac_sign: String,
    mbti: String,
    interests: String,
    books: String,
    sports: String,
    profile_tags: String,
    last_signal: String,
    initials: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct PendingUpdate {
    id: String,
    type_name: String,
    summary: String,
    evidence: String,
    person_name: String,
    created_label: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DashboardPayload {
    people: Vec<Person>,
    pending_updates: Vec<PendingUpdate>,
    settings: AppSettings,
}

#[tauri::command]
fn init_database(app: tauri::AppHandle) -> Result<DashboardPayload, String> {
    let conn = open_database(&app)?;
    migrate(&conn)?;
    seed_if_empty(&conn)?;
    load_dashboard(&conn)
}

#[tauri::command]
fn save_settings(app: tauri::AppHandle, settings: AppSettings) -> Result<DashboardPayload, String> {
    let conn = open_ready_database(&app)?;
    let model = normalize_model(&settings.model);
    write_setting(&conn, "deepseek_model", model)?;
    write_setting(
        &conn,
        "deep_thinking",
        if settings.deep_thinking { "true" } else { "false" },
    )?;
    write_setting(&conn, "language", normalize_language(&settings.language))?;
    load_dashboard(&conn)
}

#[tauri::command]
fn save_api_key(app: tauri::AppHandle, api_key: String) -> Result<DashboardPayload, String> {
    let trimmed = api_key.trim();
    if trimmed.is_empty() {
        return Err("API key cannot be empty.".to_string());
    }

    keyring_entry()?.set_password(trimmed).map_err(to_string)?;
    let conn = open_ready_database(&app)?;
    load_dashboard(&conn)
}

#[tauri::command]
fn remove_api_key(app: tauri::AppHandle) -> Result<DashboardPayload, String> {
    let entry = keyring_entry()?;
    let _ = entry.delete_credential();
    let conn = open_ready_database(&app)?;
    load_dashboard(&conn)
}

#[tauri::command]
async fn test_connection(app: tauri::AppHandle) -> Result<String, String> {
    let conn = open_ready_database(&app)?;
    let settings = load_settings(&conn)?;
    let api_key = read_api_key()?.ok_or_else(|| missing_key_message(&settings.language))?;
    let _ = call_deepseek("Alex likes hotpot.", &settings, &api_key).await?;
    Ok(if resolves_chinese(&settings.language) {
        "连接正常。".to_string()
    } else {
        "Connection works.".to_string()
    })
}

#[tauri::command]
async fn capture_memory(
    app: tauri::AppHandle,
    text: String,
    person_name: Option<String>,
) -> Result<DashboardPayload, String> {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return Err("Capture cannot be empty.".to_string());
    }

    let conn = open_ready_database(&app)?;
    let settings = load_settings(&conn)?;
    let memory_id = format!("memory-{}", Local::now().timestamp_nanos_opt().unwrap_or_default());
    conn.execute(
        "INSERT INTO memories (id, body, created_at) VALUES (?1, ?2, ?3)",
        params![memory_id, trimmed, Local::now().to_rfc3339()],
    )
    .map_err(to_string)?;

    let person = person_name
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "New friend".to_string());
    let update = match read_api_key()? {
        Some(api_key) => match call_deepseek(trimmed, &settings, &api_key).await {
            Ok(content) => PendingUpdate {
                id: format!("ai-{}", Local::now().timestamp_nanos_opt().unwrap_or_default()),
                type_name: "AI".to_string(),
                summary: summarize_extraction(&content, trimmed),
                evidence: trimmed.to_string(),
                person_name: person,
                created_label: "Just now".to_string(),
            },
            Err(error) => PendingUpdate {
                id: format!("local-{}", Local::now().timestamp_nanos_opt().unwrap_or_default()),
                type_name: "Capture".to_string(),
                summary: trimmed.to_string(),
                evidence: format!("AI extraction failed: {error}"),
                person_name: person,
                created_label: "Just now".to_string(),
            },
        },
        None => PendingUpdate {
            id: format!("local-{}", Local::now().timestamp_nanos_opt().unwrap_or_default()),
            type_name: "Capture".to_string(),
            summary: trimmed.to_string(),
            evidence: missing_key_message(&settings.language),
            person_name: person,
            created_label: "Just now".to_string(),
        },
    };

    insert_pending_update(&conn, &update)?;
    load_dashboard(&conn)
}

#[tauri::command]
fn review_pending(app: tauri::AppHandle, id: String) -> Result<DashboardPayload, String> {
    let conn = open_ready_database(&app)?;
    conn.execute("DELETE FROM pending_updates WHERE id = ?1", params![id])
        .map_err(to_string)?;
    load_dashboard(&conn)
}

#[tauri::command]
fn build_deepseek_request_preview(
    text: String,
    settings: AppSettings,
) -> Result<Value, String> {
    Ok(build_deepseek_request(&text, &settings))
}

fn open_ready_database(app: &tauri::AppHandle) -> Result<Connection, String> {
    let conn = open_database(app)?;
    migrate(&conn)?;
    seed_if_empty(&conn)?;
    Ok(conn)
}

fn open_database(app: &tauri::AppHandle) -> Result<Connection, String> {
    let dir = app.path().app_data_dir().map_err(to_string)?;
    fs::create_dir_all(&dir).map_err(to_string)?;
    Connection::open(database_path(dir)).map_err(to_string)
}

fn database_path(dir: PathBuf) -> PathBuf {
    dir.join("memoria.sqlite3")
}

fn migrate(conn: &Connection) -> Result<(), String> {
    conn.execute_batch(
        "
        CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS people (
            id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            relation_label TEXT NOT NULL,
            group_label TEXT NOT NULL,
            location TEXT NOT NULL,
            birthday TEXT NOT NULL,
            dietary_restrictions TEXT NOT NULL DEFAULT '',
            favorite_foods TEXT NOT NULL DEFAULT '',
            disliked_things TEXT NOT NULL DEFAULT '',
            zodiac_sign TEXT NOT NULL DEFAULT '',
            mbti TEXT NOT NULL DEFAULT '',
            interests TEXT NOT NULL DEFAULT '',
            books TEXT NOT NULL DEFAULT '',
            sports TEXT NOT NULL DEFAULT '',
            profile_tags TEXT NOT NULL DEFAULT '',
            last_signal TEXT NOT NULL,
            initials TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS memories (id TEXT PRIMARY KEY, body TEXT NOT NULL, created_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS pending_updates (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            summary TEXT NOT NULL,
            evidence TEXT NOT NULL,
            person_name TEXT NOT NULL,
            created_label TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS reminders (id TEXT PRIMARY KEY, title TEXT NOT NULL, person_name TEXT NOT NULL, due_label TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS gift_ideas (id TEXT PRIMARY KEY, title TEXT NOT NULL, person_name TEXT NOT NULL, price_band TEXT NOT NULL, rationale TEXT NOT NULL);
        INSERT OR IGNORE INTO schema_migrations (version, applied_at) VALUES (1, datetime('now'));
        ",
    )
    .map_err(to_string)?;
    add_text_column_if_missing(conn, "people", "dietary_restrictions")?;
    add_text_column_if_missing(conn, "people", "favorite_foods")?;
    add_text_column_if_missing(conn, "people", "disliked_things")?;
    add_text_column_if_missing(conn, "people", "zodiac_sign")?;
    add_text_column_if_missing(conn, "people", "mbti")?;
    add_text_column_if_missing(conn, "people", "interests")?;
    add_text_column_if_missing(conn, "people", "books")?;
    add_text_column_if_missing(conn, "people", "sports")?;
    add_text_column_if_missing(conn, "people", "profile_tags")?;
    backfill_demo_profiles(conn)?;
    Ok(())
}

fn backfill_demo_profiles(conn: &Connection) -> Result<(), String> {
    let people = [
        (
            "demo-alex",
            "不吃香菜",
            "火锅、毛肚、虾滑",
            "临时改计划、太吵的自习室",
            "Scorpio",
            "INTJ",
            "数学、篮球、效率工具",
            "Atomic Habits, 置身事内",
            "篮球、健身",
            "室友, 考试, 火锅",
        ),
        (
            "demo-may",
            "少冰，不太能吃辣",
            "抹茶、日料、桂花乌龙",
            "敷衍的群发祝福",
            "Taurus",
            "INFP",
            "音乐、拍立得、文学社、香水",
            "夜航西飞, The Midnight Library",
            "瑜伽、散步",
            "生日, 礼物, 文学社",
        ),
        (
            "demo-jason",
            "工作日少糖",
            "冷萃、牛排、越南粉",
            "没有 agenda 的长会",
            "Leo",
            "ENTJ",
            "创业、跑步、职业规划",
            "The Hard Thing About Hard Things",
            "跑步、攀岩",
            "学长, 内推, 职业",
        ),
        (
            "demo-nina",
            "少喝奶制品",
            "紫菜包饭、冷面、草莓蛋糕",
            "太临时的出行安排",
            "Aquarius",
            "ENFP",
            "旅行、韩语、摄影、城市漫步",
            "Pachinko, 旅行的艺术",
            "普拉提、徒步",
            "水瓶, 交换, 旅行",
        ),
    ];

    for person in people {
        conn.execute(
            "UPDATE people
             SET dietary_restrictions = ?1, favorite_foods = ?2, disliked_things = ?3, zodiac_sign = ?4, mbti = ?5, interests = ?6, books = ?7, sports = ?8, profile_tags = ?9
             WHERE id = ?10
             AND dietary_restrictions = ''
             AND favorite_foods = ''
             AND disliked_things = ''
             AND zodiac_sign = ''
             AND mbti = ''
             AND interests = ''
             AND books = ''
             AND sports = ''
             AND profile_tags = ''",
            params![
                person.1, person.2, person.3, person.4, person.5, person.6, person.7, person.8,
                person.9, person.0
            ],
        )
        .map_err(to_string)?;
    }

    Ok(())
}

fn seed_if_empty(conn: &Connection) -> Result<(), String> {
    let count: i64 = conn
        .query_row("SELECT COUNT(*) FROM people", [], |row| row.get(0))
        .map_err(to_string)?;
    if count > 0 {
        return Ok(());
    }

    let people = [
        (
            "demo-alex",
            "Alex Chen",
            "Roommate - Classmate",
            "Classmates",
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
            "AC",
        ),
        (
            "demo-may",
            "May Zhang",
            "Close friend - Literature club",
            "Home Friends",
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
            "MZ",
        ),
        (
            "demo-jason",
            "Jason Wu",
            "Senior - Internship referral",
            "Internship",
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
            "JW",
        ),
        (
            "demo-nina",
            "Nina Park",
            "Exchange friend - Seoul",
            "Study Abroad",
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
            "NP",
        ),
    ];
    for person in people {
        conn.execute(
            "INSERT INTO people (id, display_name, relation_label, group_label, location, birthday, dietary_restrictions, favorite_foods, disliked_things, zodiac_sign, mbti, interests, books, sports, profile_tags, last_signal, initials)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17)",
            params![
                person.0, person.1, person.2, person.3, person.4, person.5, person.6, person.7,
                person.8, person.9, person.10, person.11, person.12, person.13, person.14, person.15, person.16
            ],
        )
        .map_err(to_string)?;
    }

    let update = PendingUpdate {
        id: "p1".to_string(),
        type_name: "Preference".to_string(),
        summary: "Alex does not eat cilantro and likes hotpot tripe and shrimp paste.".to_string(),
        evidence: "Dinner note from yesterday with Alex".to_string(),
        person_name: "Alex Chen".to_string(),
        created_label: "Today".to_string(),
    };
    insert_pending_update(conn, &update)
}

fn load_dashboard(conn: &Connection) -> Result<DashboardPayload, String> {
    Ok(DashboardPayload {
        people: load_people(conn)?,
        pending_updates: load_pending_updates(conn)?,
        settings: load_settings(conn)?,
    })
}

fn load_people(conn: &Connection) -> Result<Vec<Person>, String> {
    let mut statement = conn
        .prepare(
            "SELECT id, display_name, relation_label, group_label, location, birthday, dietary_restrictions, favorite_foods, disliked_things, zodiac_sign, mbti, interests, books, sports, profile_tags, last_signal, initials
             FROM people ORDER BY display_name",
        )
        .map_err(to_string)?;
    let rows = statement
        .query_map([], |row| {
            Ok(Person {
                id: row.get(0)?,
                display_name: row.get(1)?,
                relation_label: row.get(2)?,
                group_label: row.get(3)?,
                location: row.get(4)?,
                birthday: row.get(5)?,
                dietary_restrictions: row.get(6)?,
                favorite_foods: row.get(7)?,
                disliked_things: row.get(8)?,
                zodiac_sign: row.get(9)?,
                mbti: row.get(10)?,
                interests: row.get(11)?,
                books: row.get(12)?,
                sports: row.get(13)?,
                profile_tags: row.get(14)?,
                last_signal: row.get(15)?,
                initials: row.get(16)?,
            })
        })
        .map_err(to_string)?;
    rows.collect::<Result<Vec<_>, _>>().map_err(to_string)
}

fn load_pending_updates(conn: &Connection) -> Result<Vec<PendingUpdate>, String> {
    let mut statement = conn
        .prepare(
            "SELECT id, type, summary, evidence, person_name, created_label
             FROM pending_updates ORDER BY rowid DESC",
        )
        .map_err(to_string)?;
    let rows = statement
        .query_map([], |row| {
            Ok(PendingUpdate {
                id: row.get(0)?,
                type_name: row.get(1)?,
                summary: row.get(2)?,
                evidence: row.get(3)?,
                person_name: row.get(4)?,
                created_label: row.get(5)?,
            })
        })
        .map_err(to_string)?;
    rows.collect::<Result<Vec<_>, _>>().map_err(to_string)
}

fn load_settings(conn: &Connection) -> Result<AppSettings, String> {
    Ok(AppSettings {
        model: read_setting(conn, "deepseek_model", "deepseek-v4-flash")?,
        deep_thinking: read_setting(conn, "deep_thinking", "false")? == "true",
        language: read_setting(conn, "language", "system")?,
        has_api_key: read_api_key()?.is_some(),
    })
}

fn read_setting(conn: &Connection, key: &str, fallback: &str) -> Result<String, String> {
    match conn.query_row(
        "SELECT value FROM app_settings WHERE key = ?1",
        params![key],
        |row| row.get::<_, String>(0),
    ) {
        Ok(value) => Ok(value),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(fallback.to_string()),
        Err(error) => Err(error.to_string()),
    }
}

fn write_setting(conn: &Connection, key: &str, value: &str) -> Result<(), String> {
    conn.execute(
        "INSERT INTO app_settings (key, value) VALUES (?1, ?2)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        params![key, value],
    )
    .map(|_| ())
    .map_err(to_string)
}

fn add_text_column_if_missing(conn: &Connection, table: &str, column: &str) -> Result<(), String> {
    let mut statement = conn
        .prepare(&format!("PRAGMA table_info({table})"))
        .map_err(to_string)?;
    let rows = statement
        .query_map([], |row| row.get::<_, String>(1))
        .map_err(to_string)?;
    let columns = rows.collect::<Result<Vec<_>, _>>().map_err(to_string)?;
    if columns.iter().any(|existing| existing == column) {
        return Ok(());
    }

    conn.execute(
        &format!("ALTER TABLE {table} ADD COLUMN {column} TEXT NOT NULL DEFAULT ''"),
        [],
    )
    .map(|_| ())
    .map_err(to_string)
}

fn insert_pending_update(conn: &Connection, update: &PendingUpdate) -> Result<(), String> {
    conn.execute(
        "INSERT INTO pending_updates (id, type, summary, evidence, person_name, created_label)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)
         ON CONFLICT(id) DO UPDATE SET
            type = excluded.type,
            summary = excluded.summary,
            evidence = excluded.evidence,
            person_name = excluded.person_name,
            created_label = excluded.created_label",
        params![
            update.id,
            update.type_name,
            update.summary,
            update.evidence,
            update.person_name,
            update.created_label
        ],
    )
    .map(|_| ())
    .map_err(to_string)
}

async fn call_deepseek(text: &str, settings: &AppSettings, api_key: &str) -> Result<String, String> {
    let response = reqwest::Client::new()
        .post("https://api.deepseek.com/chat/completions")
        .bearer_auth(api_key)
        .json(&build_deepseek_request(text, settings))
        .send()
        .await
        .map_err(to_string)?;
    let status = response.status();
    let body = response.text().await.map_err(to_string)?;
    if !status.is_success() {
        return Err(format!("DeepSeek request failed with status {status}"));
    }

    let json: Value = serde_json::from_str(&body).map_err(to_string)?;
    let content = json["choices"][0]["message"]["content"]
        .as_str()
        .unwrap_or_default()
        .trim()
        .to_string();
    if content.is_empty() {
        return Err("DeepSeek returned empty content.".to_string());
    }
    Ok(content)
}

fn build_deepseek_request(text: &str, settings: &AppSettings) -> Value {
    let mut payload = json!({
        "model": normalize_model(&settings.model),
        "messages": [
            {
                "role": "system",
                "content": "Extract friend relationship facts from student-life notes. Keep sensitive facts minimal and evidence-backed. Return only valid JSON with top-level people, reminders, and giftIdeas arrays."
            },
            {
                "role": "user",
                "content": format!("Locale: {}\nTimezone: local\nNote:\n{}", normalize_language(&settings.language), text)
            }
        ],
        "response_format": { "type": "json_object" },
        "thinking": { "type": if settings.deep_thinking { "enabled" } else { "disabled" } },
        "temperature": 0.1,
        "max_tokens": 1600,
        "stream": false
    });
    if settings.deep_thinking {
        payload["reasoning_effort"] = json!("high");
    }
    payload
}

fn summarize_extraction(content: &str, fallback: &str) -> String {
    let parsed = serde_json::from_str::<Value>(content);
    if let Ok(json) = parsed {
        if let Some(summary) = json["people"][0]["updates"][0]["summary"].as_str() {
            if !summary.trim().is_empty() {
                return summary.to_string();
            }
        }
    }
    if fallback.chars().count() > 96 {
        format!("{}...", fallback.chars().take(93).collect::<String>())
    } else {
        fallback.to_string()
    }
}

fn keyring_entry() -> Result<Entry, String> {
    Entry::new(KEYRING_SERVICE, KEYRING_ACCOUNT).map_err(to_string)
}

fn read_api_key() -> Result<Option<String>, String> {
    match keyring_entry()?.get_password() {
        Ok(value) => Ok(Some(value)),
        Err(keyring::Error::NoEntry) => Ok(None),
        Err(error) => Err(error.to_string()),
    }
}

fn normalize_model(model: &str) -> &str {
    if model == "deepseek-v4-pro" {
        "deepseek-v4-pro"
    } else {
        "deepseek-v4-flash"
    }
}

fn normalize_language(language: &str) -> &str {
    if language == "zh-CN" || language == "en" {
        language
    } else {
        "system"
    }
}

fn resolves_chinese(language: &str) -> bool {
    language == "zh-CN"
}

fn missing_key_message(language: &str) -> String {
    if resolves_chinese(language) {
        "还没有保存 DeepSeek API key。先去设置里填一下，再用 AI 识别。".to_string()
    } else {
        "No DeepSeek API key is saved yet. Add one in Settings before using AI capture.".to_string()
    }
}

fn to_string(error: impl std::fmt::Display) -> String {
    error.to_string()
}

pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            init_database,
            save_settings,
            save_api_key,
            remove_api_key,
            test_connection,
            capture_memory,
            review_pending,
            build_deepseek_request_preview
        ])
        .run(tauri::generate_context!())
        .expect("error while running Memoria Windows");
}
