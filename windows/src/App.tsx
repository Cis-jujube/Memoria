import { invoke } from "@tauri-apps/api/core";
import { FormEvent, useEffect, useMemo, useState } from "react";

type DeepSeekModel = "deepseek-v4-flash" | "deepseek-v4-pro";
type LanguagePreference = "system" | "zh-CN" | "en";

type AppSettings = {
  model: DeepSeekModel;
  deepThinking: boolean;
  language: LanguagePreference;
  hasApiKey: boolean;
};

type Person = {
  id: string;
  displayName: string;
  relationLabel: string;
  groupLabel: string;
  location: string;
  birthday: string;
  dietaryRestrictions: string;
  favoriteFoods: string;
  dislikedThings: string;
  zodiacSign: string;
  mbti: string;
  interests: string;
  books: string;
  sports: string;
  profileTags: string;
  lastSignal: string;
  initials: string;
};

type PendingUpdate = {
  id: string;
  typeName: string;
  summary: string;
  evidence: string;
  personName: string;
  createdLabel: string;
};

type DashboardPayload = {
  people: Person[];
  pendingUpdates: PendingUpdate[];
  settings: AppSettings;
};

type Copy = {
  aiInboxTitle: string;
  whySuggested: string;
  settingsTitle: string;
  deepSeekSectionTitle: string;
  apiKeyPlaceholder: string;
  saveKey: string;
  testConnection: string;
  removeKey: string;
  modelLabel: string;
  deepThinkingLabel: string;
  languageLabel: string;
  deepseekPrivacyNote: string;
  missingKeyMessage: string;
  sendToInbox: string;
  quickCaptureTitle: string;
  quickCaptureHint: string;
  confirm: string;
  discard: string;
};

const copies: Record<"zh-CN" | "en", Copy> = {
  "zh-CN": {
    aiInboxTitle: "待确认",
    whySuggested: "为什么建议这样记",
    settingsTitle: "设置",
    deepSeekSectionTitle: "DeepSeek 接入",
    apiKeyPlaceholder: "粘贴你的 DeepSeek API key",
    saveKey: "保存密钥",
    testConnection: "测试连接",
    removeKey: "移除密钥",
    modelLabel: "模型",
    deepThinkingLabel: "深度思考",
    languageLabel: "界面语言",
    deepseekPrivacyNote:
      "开启 AI 识别后，你输入的记忆内容会发送给 DeepSeek 处理。密钥只保存在 Windows 凭据管理器里，不写进本地数据库。",
    missingKeyMessage: "还没有保存 DeepSeek API key。先去设置里填一下，再用 AI 识别。",
    sendToInbox: "发送到待确认",
    quickCaptureTitle: "快速记录",
    quickCaptureHint: "写下一条记忆、计划、偏好或提醒线索...",
    confirm: "确认",
    discard: "放弃",
  },
  en: {
    aiInboxTitle: "AI Inbox",
    whySuggested: "Why AI suggested this",
    settingsTitle: "Settings",
    deepSeekSectionTitle: "DeepSeek",
    apiKeyPlaceholder: "Paste your DeepSeek API key",
    saveKey: "Save key",
    testConnection: "Test connection",
    removeKey: "Remove key",
    modelLabel: "Model",
    deepThinkingLabel: "Deep thinking",
    languageLabel: "Language",
    deepseekPrivacyNote:
      "AI capture sends the text you enter to DeepSeek. Your API key stays in Windows Credential Manager and is not written to SQLite.",
    missingKeyMessage: "No DeepSeek API key is saved yet. Add one in Settings before using AI capture.",
    sendToInbox: "Send to AI Inbox",
    quickCaptureTitle: "Quick Capture",
    quickCaptureHint: "Type a memory, plan, preference, or reminder signal...",
    confirm: "Confirm",
    discard: "Discard",
  },
};

const emptySettings: AppSettings = {
  model: "deepseek-v4-flash",
  deepThinking: false,
  language: "system",
  hasApiKey: false,
};

function resolveLanguage(preference: LanguagePreference) {
  if (preference === "zh-CN" || preference === "en") {
    return preference;
  }
  return navigator.language.toLowerCase().startsWith("zh") ? "zh-CN" : "en";
}

export default function App() {
  const [dashboard, setDashboard] = useState<DashboardPayload | null>(null);
  const [settings, setSettings] = useState<AppSettings>(emptySettings);
  const [apiKey, setApiKey] = useState("");
  const [capture, setCapture] = useState("");
  const [selectedPersonId, setSelectedPersonId] = useState<string | null>(null);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  const language = resolveLanguage(settings.language);
  const copy = copies[language];

  useEffect(() => {
    invoke<DashboardPayload>("init_database")
      .then((payload) => {
        setDashboard(payload);
        setSettings(payload.settings);
        setSelectedPersonId(payload.people[0]?.id ?? null);
      })
      .catch((error) => setStatus(String(error)));
  }, []);

  const selectedPerson = useMemo(
    () => dashboard?.people.find((person) => person.id === selectedPersonId) ?? dashboard?.people[0],
    [dashboard?.people, selectedPersonId],
  );

  async function refresh(payloadPromise: Promise<DashboardPayload>) {
    const payload = await payloadPromise;
    setDashboard(payload);
    setSettings(payload.settings);
  }

  async function saveSettings(next: AppSettings) {
    setSettings(next);
    await refresh(invoke<DashboardPayload>("save_settings", { settings: next }));
  }

  async function onCapture(event: FormEvent) {
    event.preventDefault();
    if (!capture.trim()) {
      return;
    }

    setBusy(true);
    setStatus("");
    const text = capture;
    setCapture("");
    try {
      await refresh(
        invoke<DashboardPayload>("capture_memory", {
          text,
          personName: selectedPerson?.displayName ?? null,
        }),
      );
      setStatus(language === "zh-CN" ? "已发送到待确认。" : "Sent to AI Inbox.");
    } catch (error) {
      setStatus(String(error));
    } finally {
      setBusy(false);
    }
  }

  async function saveApiKey() {
    setBusy(true);
    setStatus("");
    try {
      await refresh(invoke<DashboardPayload>("save_api_key", { apiKey }));
      setApiKey("");
      setStatus(language === "zh-CN" ? "密钥已保存到 Windows 凭据管理器。" : "Key saved to Windows Credential Manager.");
    } catch (error) {
      setStatus(String(error));
    } finally {
      setBusy(false);
    }
  }

  async function testConnection() {
    setBusy(true);
    setStatus("");
    try {
      const message = await invoke<string>("test_connection");
      setStatus(message);
    } catch (error) {
      setStatus(String(error));
    } finally {
      setBusy(false);
    }
  }

  async function removeApiKey() {
    setBusy(true);
    setStatus("");
    try {
      await refresh(invoke<DashboardPayload>("remove_api_key"));
      setStatus(language === "zh-CN" ? "密钥已移除。" : "Key removed.");
    } catch (error) {
      setStatus(String(error));
    } finally {
      setBusy(false);
    }
  }

  async function reviewPending(id: string) {
    await refresh(invoke<DashboardPayload>("review_pending", { id }));
  }

  if (!dashboard) {
    return (
      <main className="loading-shell">
        <div>
          <h1>Memoria</h1>
          <p>{status || "Loading local database..."}</p>
        </div>
      </main>
    );
  }

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div>
          <p className="eyebrow">Memoria</p>
          <h1>{language === "zh-CN" ? "本地朋友记忆" : "Local Friend Memory"}</h1>
          <p>{language === "zh-CN" ? "SQLite 本地数据 · DeepSeek 自带密钥" : "SQLite local data · Bring your own DeepSeek key"}</p>
        </div>

        <nav aria-label="Primary">
          <a href="#brief">{language === "zh-CN" ? "今日概览" : "Daily Brief"}</a>
          <a href="#inbox">{copy.aiInboxTitle}</a>
          <a href="#calendar">{language === "zh-CN" ? "日历" : "Calendar"}</a>
          <a href="#settings">{copy.settingsTitle}</a>
        </nav>
      </aside>

      <section className="workspace">
        <header className="topbar" id="brief">
          <div>
            <p className="eyebrow">{language === "zh-CN" ? "本机原生版" : "Native Local App"}</p>
            <h2>{language === "zh-CN" ? "先记录，后确认，再沉淀" : "Capture, review, then remember"}</h2>
          </div>
          <div className="status-pill">{settings.hasApiKey ? "DeepSeek ready" : "No API key"}</div>
        </header>

        <section className="metrics" aria-label="Dashboard metrics">
          <Metric label={language === "zh-CN" ? "联系人" : "People"} value={dashboard.people.length} />
          <Metric label={copy.aiInboxTitle} value={dashboard.pendingUpdates.length} />
          <Metric label={copy.modelLabel} value={settings.model === "deepseek-v4-pro" ? "Pro" : "Flash"} />
        </section>

        <section className="two-column">
          <form className="panel capture-panel" onSubmit={onCapture}>
            <div className="panel-header">
              <div>
                <p className="eyebrow">{copy.quickCaptureTitle}</p>
                <h3>{language === "zh-CN" ? "给这段关系留一条线索" : "Leave a relationship signal"}</h3>
              </div>
              <select
                value={selectedPerson?.id ?? ""}
                onChange={(event) => setSelectedPersonId(event.target.value)}
                aria-label={language === "zh-CN" ? "选择联系人" : "Select person"}
              >
                {dashboard.people.map((person) => (
                  <option value={person.id} key={person.id}>
                    {person.displayName}
                  </option>
                ))}
              </select>
            </div>
            <textarea
              value={capture}
              onChange={(event) => setCapture(event.target.value)}
              placeholder={copy.quickCaptureHint}
              rows={6}
            />
            <p className="hint">
              {language === "zh-CN"
                ? "内容会先进入待确认。你点确认之前，联系人档案不会被改。"
                : "Captures go to AI Inbox first. Profiles do not change until you confirm."}
            </p>
            <button className="primary" type="submit" disabled={busy}>
              {copy.sendToInbox}
            </button>
          </form>

          <section className="panel people-panel" aria-label="People">
            <div className="panel-header">
              <div>
                <p className="eyebrow">{language === "zh-CN" ? "联系人" : "People"}</p>
                <h3>{language === "zh-CN" ? "最近需要记住的人" : "People worth remembering"}</h3>
              </div>
            </div>
            <div className="person-list">
              {dashboard.people.map((person) => (
                <button
                  className={person.id === selectedPerson?.id ? "person-row active" : "person-row"}
                  key={person.id}
                  onClick={() => setSelectedPersonId(person.id)}
                  type="button"
                >
                  <span>{person.initials}</span>
                  <strong>{person.displayName}</strong>
                  <small>{person.lastSignal}</small>
                </button>
              ))}
            </div>
          </section>
        </section>

        {selectedPerson ? (
          <section className="panel profile-panel" aria-label="Profile">
            <div className="panel-header">
              <div>
                <p className="eyebrow">{language === "zh-CN" ? "联系人档案" : "Profile"}</p>
                <h3>{selectedPerson.displayName}</h3>
              </div>
              <div className="status-pill">{selectedPerson.zodiacSign} · {selectedPerson.mbti}</div>
            </div>
            <div className="profile-grid">
              <ProfileFact label={language === "zh-CN" ? "生日" : "Birthday"} value={selectedPerson.birthday} />
              <ProfileFact label={language === "zh-CN" ? "忌口" : "Dietary"} value={selectedPerson.dietaryRestrictions} />
              <ProfileFact label={language === "zh-CN" ? "喜欢吃的" : "Favorite foods"} value={selectedPerson.favoriteFoods} />
              <ProfileFact label={language === "zh-CN" ? "不喜欢" : "Dislikes"} value={selectedPerson.dislikedThings} />
              <ProfileFact label={language === "zh-CN" ? "星座" : "Zodiac"} value={selectedPerson.zodiacSign} />
              <ProfileFact label="MBTI" value={selectedPerson.mbti} />
              <ProfileFact label={language === "zh-CN" ? "兴趣爱好" : "Interests"} value={selectedPerson.interests} />
              <ProfileFact label={language === "zh-CN" ? "在看的书" : "Books"} value={selectedPerson.books} />
              <ProfileFact label={language === "zh-CN" ? "运动" : "Sports"} value={selectedPerson.sports} />
              <ProfileFact label={language === "zh-CN" ? "标签" : "Tags"} value={selectedPerson.profileTags} />
            </div>
            <div className="evidence">
              <strong>{language === "zh-CN" ? "最近线索" : "Last signal"}</strong>
              <span>{selectedPerson.lastSignal}</span>
            </div>
          </section>
        ) : null}

        <section className="panel" id="calendar">
          <div className="panel-header">
            <div>
              <p className="eyebrow">{language === "zh-CN" ? "日历" : "Calendar"}</p>
              <h3>{language === "zh-CN" ? "生日和提醒放在一条时间线上" : "Birthdays and reminders in one timeline"}</h3>
            </div>
          </div>
          <div className="calendar-list">
            {dashboard.people.map((person, index) => (
              <article className="calendar-row" key={`birthday-${person.id}`}>
                <span>{index + 1}</span>
                <div>
                  <strong>{language === "zh-CN" ? `${person.displayName} 生日` : `${person.displayName} birthday`}</strong>
                  <small>{person.birthday} · {person.favoriteFoods || person.lastSignal}</small>
                </div>
              </article>
            ))}
          </div>
        </section>

        <section className="panel" id="inbox">
          <div className="panel-header">
            <div>
              <p className="eyebrow">{copy.aiInboxTitle}</p>
              <h3>{language === "zh-CN" ? "确认后才写入档案" : "Review before writing to profiles"}</h3>
            </div>
          </div>

          <div className="inbox-list">
            {dashboard.pendingUpdates.length === 0 ? (
              <p className="empty">{language === "zh-CN" ? "这里暂时没有要确认的内容。" : "No pending updates right now."}</p>
            ) : (
              dashboard.pendingUpdates.map((update) => (
                <article className="pending-item" key={update.id}>
                  <div>
                    <p className="eyebrow">{update.typeName} · {update.createdLabel}</p>
                    <h4>{update.personName}</h4>
                    <p>{update.summary}</p>
                    <div className="evidence">
                      <strong>{copy.whySuggested}</strong>
                      <span>{update.evidence}</span>
                    </div>
                  </div>
                  <div className="action-row">
                    <button type="button" onClick={() => reviewPending(update.id)}>
                      {copy.discard}
                    </button>
                    <button className="primary" type="button" onClick={() => reviewPending(update.id)}>
                      {copy.confirm}
                    </button>
                  </div>
                </article>
              ))
            )}
          </div>
        </section>

        <section className="panel settings-panel" id="settings">
          <div className="panel-header">
            <div>
              <p className="eyebrow">{copy.settingsTitle}</p>
              <h3>{copy.deepSeekSectionTitle}</h3>
            </div>
          </div>

          <div className="settings-grid">
            <label>
              <span>{copy.apiKeyPlaceholder}</span>
              <input
                value={apiKey}
                onChange={(event) => setApiKey(event.target.value)}
                placeholder={settings.hasApiKey ? "sk-***" : copy.apiKeyPlaceholder}
                type="password"
              />
            </label>
            <div className="button-row">
              <button className="primary" type="button" onClick={saveApiKey} disabled={busy}>
                {copy.saveKey}
              </button>
              <button type="button" onClick={testConnection} disabled={busy}>
                {copy.testConnection}
              </button>
              <button type="button" onClick={removeApiKey} disabled={busy}>
                {copy.removeKey}
              </button>
            </div>

            <fieldset>
              <legend>{copy.modelLabel}</legend>
              <Segment
                active={settings.model === "deepseek-v4-flash"}
                onClick={() => saveSettings({ ...settings, model: "deepseek-v4-flash" })}
              >
                Flash
              </Segment>
              <Segment
                active={settings.model === "deepseek-v4-pro"}
                onClick={() => saveSettings({ ...settings, model: "deepseek-v4-pro" })}
              >
                Pro
              </Segment>
            </fieldset>

            <fieldset>
              <legend>{copy.deepThinkingLabel}</legend>
              <Segment
                active={!settings.deepThinking}
                onClick={() => saveSettings({ ...settings, deepThinking: false })}
              >
                {language === "zh-CN" ? "关" : "Off"}
              </Segment>
              <Segment
                active={settings.deepThinking}
                onClick={() => saveSettings({ ...settings, deepThinking: true })}
              >
                {language === "zh-CN" ? "开" : "On"}
              </Segment>
            </fieldset>

            <fieldset>
              <legend>{copy.languageLabel}</legend>
              <Segment active={settings.language === "system"} onClick={() => saveSettings({ ...settings, language: "system" })}>
                {language === "zh-CN" ? "跟随系统" : "System"}
              </Segment>
              <Segment active={settings.language === "zh-CN"} onClick={() => saveSettings({ ...settings, language: "zh-CN" })}>
                中文
              </Segment>
              <Segment active={settings.language === "en"} onClick={() => saveSettings({ ...settings, language: "en" })}>
                English
              </Segment>
            </fieldset>
          </div>

          <div className="sync-note">
            <strong>{language === "zh-CN" ? "账号与同步" : "Account & Sync"}</strong>
            <p>
              {language === "zh-CN"
                ? "之后可以登录同一个账号，把手机和电脑上的联系人、记忆、提醒同步到你的自托管服务器。DeepSeek API key 不参与同步，只留在这台电脑。"
                : "Sign in later to sync people, memories, and reminders across your devices through your self-hosted server. The DeepSeek API key stays on this PC and is never synced."}
            </p>
            <span>
              {language === "zh-CN"
                ? "本地优先，离线也能用。服务器地址和账号登录待接入。"
                : "Local-first and usable offline. Server URL and account login are planned next."}
            </span>
          </div>

          <p className="privacy-note">{copy.deepseekPrivacyNote}</p>
          {status ? <p className="status-note">{status}</p> : null}
        </section>
      </section>
    </main>
  );
}

function Metric({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function ProfileFact({ label, value }: { label: string; value: string }) {
  return (
    <div className="profile-fact">
      <span>{label}</span>
      <strong>{value || "—"}</strong>
    </div>
  );
}

function Segment({
  active,
  children,
  onClick,
}: {
  active: boolean;
  children: string;
  onClick: () => void;
}) {
  return (
    <button className={active ? "segment active" : "segment"} type="button" onClick={onClick}>
      {children}
    </button>
  );
}
