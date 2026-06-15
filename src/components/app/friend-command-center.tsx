"use client";

import {
  ArrowUpRight,
  BookOpen,
  Bell,
  CalendarDays,
  Check,
  ChevronRight,
  Coffee,
  FileUp,
  Gift,
  Globe2,
  Inbox,
  Gamepad2,
  Heart,
  Lock,
  Menu,
  MessageCircle,
  Mic,
  Network,
  Plus,
  Search,
  Send,
  Settings,
  ShieldCheck,
  Sparkles,
  Star,
  Target,
  Trash2,
  Upload,
  UserPlus,
  WandSparkles,
  Users,
  X,
} from "lucide-react";
import dynamic from "next/dynamic";
import { signIn, signOut } from "next-auth/react";
import { useEffect, useMemo, useState, type FormEvent, type ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { StatusCard } from "@/components/ui/status-card";
import { demoDashboardData, type DashboardData } from "@/data/demo";
import { cn } from "@/lib/cn";
import { deriveDashboardAnalytics } from "@/lib/dashboard-analytics";
import { enrichDashboardData } from "@/lib/relationship-intelligence";
import {
  navigationItems,
  parseAppSection,
  type AppSection,
  type NavigationMode,
} from "@/lib/dashboard-navigation";

const RelationshipGalaxy = dynamic(
  () =>
    import("@/components/app/relationship-galaxy").then(
      (module) => module.RelationshipGalaxy,
    ),
  {
    ssr: false,
    loading: () => (
      <div className="grid min-h-[420px] place-items-center rounded-lg bg-[#0c1b18] text-sm text-[#dcebe3]">
        正在打开关系星图...
      </div>
    ),
  },
);

type Props = {
  data: DashboardData;
  isAuthenticated: boolean;
  hasGoogleAuth: boolean;
  hasAuthSecret?: boolean;
  hasDatabaseUrl?: boolean;
  hasPasswordAuth?: boolean;
  userEmail?: string | null;
  userName?: string | null;
};

type AskResult = {
  answer: string;
  citations: { type: string; id: string; label: string }[];
};

type LanguageMode = "system" | "zh" | "en";
type UiLanguage = "zh" | "en";
type DeepSeekModel = "deepseek-v4-flash" | "deepseek-v4-pro";

const languageStorageKey = "memoria.language-mode";
const deepSeekStorageKey = "memoria.deepseek-settings";
const deepSeekSessionKey = "memoria.deepseek-session-key";
const deepSeekPlatformUrl = "https://platform.deepseek.com/";
const deepSeekDocsUrl = "https://api-docs.deepseek.com/";

const deepSeekModels: { value: DeepSeekModel; label: string; detail: string }[] = [
  {
    value: "deepseek-v4-flash",
    label: "DeepSeek V4 Flash",
    detail: "日常记录、搜索和待确认建议，速度优先。",
  },
  {
    value: "deepseek-v4-pro",
    label: "DeepSeek V4 Pro",
    detail: "更复杂的人物整理和长文本，质量优先。",
  },
];

const productCopy: Record<
  UiLanguage,
  {
    brandLine: string;
    captureAction: string;
    navAria: Record<AppSection, string>;
    navLabels: Record<AppSection, string>;
    quickRecord: string;
    settingsButton: string;
    signInButton: string;
    status: { authenticated: string; preview: string };
  }
> = {
  zh: {
    brandLine: "把重要的人和事记清楚",
    captureAction: "记一条新记忆",
    navAria: {
      home: "首页",
      brief: "今日简报",
      calendar: "关系日历",
      files: "文件导入",
      gifts: "礼物灵感",
      groups: "分组编辑",
      inbox: "待确认",
      map: "关系星图",
      people: "朋友档案",
      reminders: "提醒",
      search: "记忆搜索",
      settings: "账号设置",
    },
    navLabels: {
      home: "首页",
      brief: "今日简报",
      calendar: "关系日历",
      files: "文件导入",
      gifts: "礼物灵感",
      groups: "分组编辑",
      inbox: "待确认",
      map: "关系星图",
      people: "朋友档案",
      reminders: "提醒",
      search: "记忆搜索",
      settings: "账号设置",
    },
    quickRecord: "快速记录",
    settingsButton: "配置登录",
    signInButton: "登录",
    status: {
      authenticated: "你的私密工作区已经就绪。",
      preview: "预览模式。登录后才会保存真实记忆。",
    },
  },
  en: {
    brandLine: "Remember the people who matter",
    captureAction: "Capture a memory",
    navAria: {
      home: "Home",
      brief: "Daily Brief",
      calendar: "Calendar",
      files: "Files",
      gifts: "Gift Ideas",
      groups: "Groups",
      inbox: "AI Inbox",
      map: "Relationship Map",
      people: "People",
      reminders: "Reminders",
      search: "Memory Search",
      settings: "Account Settings",
    },
    navLabels: {
      home: "Home",
      brief: "Daily Brief",
      calendar: "Calendar",
      files: "Files",
      gifts: "Gifts",
      groups: "Groups",
      inbox: "AI Inbox",
      map: "Map",
      people: "People",
      reminders: "Reminders",
      search: "Search",
      settings: "Settings",
    },
    quickRecord: "Quick capture",
    settingsButton: "Set up login",
    signInButton: "Sign in",
    status: {
      authenticated: "Your private workspace is ready.",
      preview: "Preview mode. Sign in to save real memories.",
    },
  },
};

export function FriendCommandCenter({
  data,
  isAuthenticated,
  hasAuthSecret = false,
  hasDatabaseUrl = false,
  hasGoogleAuth,
  hasPasswordAuth = false,
  userEmail,
  userName,
}: Props) {
  const [dashboard, setDashboard] = useState(data);
  const [activeSection, setActiveSection] = useState<AppSection>("home");
  const [groupFilter, setGroupFilter] = useState<string | null>(null);
  const [isMobileNavOpen, setIsMobileNavOpen] = useState(false);
  const [captureText, setCaptureText] = useState("");
  const [askText, setAskText] = useState("");
  const [askResult, setAskResult] = useState<AskResult | null>(null);
  const [reminderTitle, setReminderTitle] = useState("");
  const [reminderDueAt, setReminderDueAt] = useState("");
  const [uploadStatus, setUploadStatus] = useState("已经准备好导入私密文件。");
  const [status, setStatus] = useState(
    isAuthenticated
      ? "你的私密工作区已经就绪。"
      : "预览模式。登录后才会保存真实记忆。",
  );
  const [authMode, setAuthMode] = useState<"sign-in" | "register">("sign-in");
  const [accountName, setAccountName] = useState("");
  const [accountEmail, setAccountEmail] = useState("");
  const [accountPassword, setAccountPassword] = useState("");
  const [profileName, setProfileName] = useState(userName || "");
  const [authBusy, setAuthBusy] = useState(false);
  const [languageMode, setLanguageMode] = useState<LanguageMode>("zh");
  const [deepSeekApiKey, setDeepSeekApiKey] = useState("");
  const [deepSeekSavedKey, setDeepSeekSavedKey] = useState("");
  const [deepSeekModel, setDeepSeekModel] = useState<DeepSeekModel>("deepseek-v4-flash");
  const [deepSeekThinking, setDeepSeekThinking] = useState(false);
  const [deepSeekStatus, setDeepSeekStatus] = useState("还没有保存 DeepSeek API key。");
  const [deepSeekBusy, setDeepSeekBusy] = useState(false);
  const [newGroupLabel, setNewGroupLabel] = useState("");
  const [newGroupDescription, setNewGroupDescription] = useState("");
  const [newGroupColor, setNewGroupColor] = useState("#256f56");

  const uiLanguage = useMemo(() => resolveLanguageMode(languageMode), [languageMode]);
  const copy = productCopy[uiLanguage];
  const localizedNavigationItems = useMemo(
    () =>
      navigationItems.map((item) => ({
        ...item,
        label: copy.navLabels[item.section],
      })),
    [copy.navLabels],
  );
  const mobileNavigationItems = useMemo(() => {
    const priority: AppSection[] = ["home", "inbox", "people", "map", "settings"];
    return priority.flatMap((section) => {
      const item = localizedNavigationItems.find((candidate) => candidate.section === section);
      return item ? [item] : [];
    });
  }, [localizedNavigationItems]);
  const meName = profileName || userName || userEmail?.split("@")[0] || "Me";
  const greetingName = meName.split(" ")[0] || "Me";
  const analytics = useMemo(
    () => deriveDashboardAnalytics(dashboard),
    [dashboard],
  );
  const visiblePeople = useMemo(() => {
    if (!groupFilter) return dashboard.people;
    const label = groupLabel(dashboard.groups, groupFilter);
    return dashboard.people.filter(
      (person) =>
        person.groupIds.includes(groupFilter) ||
        person.groupLabels.includes(label) ||
        person.groupLabel === label,
    );
  }, [dashboard.groups, dashboard.people, groupFilter]);
  const firstPerson = visiblePeople[0] || dashboard.people[0] || demoDashboardData.people[0];
  const selectedFile = dashboard.files[0];
  const headerTitle = groupFilter
    ? `${groupLabel(dashboard.groups, groupFilter)} · 朋友`
    : sectionDisplayLabel(activeSection, uiLanguage);
  const headerSubtitle = sectionSubtitle(activeSection, groupFilter, dashboard.groups, uiLanguage);
  const badgeCounts = {
    inbox: dashboard.stats.inbox,
    reminders: dashboard.stats.reminders,
    gifts: dashboard.gifts.length,
    files: dashboard.stats.files,
  };

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      const initialNavigation = getInitialNavigation();
      setActiveSection(initialNavigation.section);
      setGroupFilter(initialNavigation.group);
      const savedLanguageMode = parseLanguageMode(localStorage.getItem(languageStorageKey));
      if (savedLanguageMode) {
        setLanguageMode(savedLanguageMode);
      }
      const savedDeepSeek = readDeepSeekSettings();
      if (savedDeepSeek) {
        setDeepSeekSavedKey(savedDeepSeek.apiKey);
        setDeepSeekModel(savedDeepSeek.model);
        setDeepSeekThinking(savedDeepSeek.thinkingEnabled);
        setDeepSeekStatus("已保存到当前浏览器会话。Capture 时会使用这组 DeepSeek 设置。");
      }
    });
    return () => window.cancelAnimationFrame(frame);
  }, []);

  useEffect(() => {
    document.documentElement.lang = uiLanguage === "zh" ? "zh-CN" : "en";
    localStorage.setItem(languageStorageKey, languageMode);
  }, [languageMode, uiLanguage]);

  async function handleCapture(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const text = captureText.trim();
    if (!text) return;

    if (!isAuthenticated) {
      setDashboard((current) => ({
        ...current,
        stats: { ...current.stats, inbox: current.stats.inbox + 1 },
        pendingUpdates: [
          {
            id: `local-${Date.now()}`,
            type: "预览",
            summary: text.length > 86 ? `${text.slice(0, 83)}...` : text,
            evidence: "本地预览。登录后保存。",
            personName: "新朋友",
            createdLabel: "刚刚",
          },
          ...current.pendingUpdates,
        ],
      }));
      setCaptureText("");
      setStatus("已添加一条预览待确认。登录后可以调用真实 AI。");
      selectSection("inbox");
      return;
    }

    setStatus("正在记录，并准备 AI 待确认建议...");
    const response = await fetch("/api/capture", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        deepSeek: buildDeepSeekRequestPayload(
          deepSeekSavedKey,
          deepSeekModel,
          deepSeekThinking,
        ),
        text,
      }),
    });

    if (!response.ok) {
      const body = (await response.json().catch(() => null)) as {
        error?: string;
      } | null;
      setStatus(body?.error || "记录失败。");
      return;
    }

    const body = (await response.json()) as { pendingUpdateCount: number };
    setCaptureText("");
    setStatus(`已生成 ${body.pendingUpdateCount} 条待确认建议。`);
    selectSection("inbox");
  }

  async function reviewPending(id: string, action: "confirm" | "discard") {
    setDashboard((current) => ({
      ...current,
      pendingUpdates: current.pendingUpdates.filter((item) => item.id !== id),
      stats: {
        ...current.stats,
        inbox: Math.max(0, current.stats.inbox - 1),
      },
    }));

    if (!isAuthenticated || id.startsWith("local-")) {
      setStatus(action === "confirm" ? "预览建议已确认。" : "预览建议已移除。");
      return;
    }

    const response = await fetch(`/api/pending-updates/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action }),
    });

    setStatus(response.ok ? "待确认建议已处理。" : "处理失败。");
  }

  async function handleAsk(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const query = askText.trim();
    if (!query) return;

    if (!isAuthenticated) {
      const matches = [
        ...dashboard.people
          .filter((person) =>
            `${person.displayName} ${person.lastSignal} ${person.groupLabel}`
              .toLowerCase()
              .includes(query.toLowerCase()),
          )
          .map((person) => ({
            type: "person",
            id: person.id,
            label: person.displayName,
          })),
        ...dashboard.pendingUpdates
          .filter((update) =>
            `${update.summary} ${update.evidence}`
              .toLowerCase()
              .includes(query.toLowerCase()),
          )
          .map((update) => ({
            type: "pending",
            id: update.id,
            label: update.summary,
          })),
      ].slice(0, 5);
      setAskResult({
        answer: matches.length
          ? `预览数据里找到 ${matches.length} 条和「${query}」有关的线索。`
          : `预览数据里还没有匹配「${query}」的记忆。`,
        citations: matches,
      });
      setAskText("");
      setStatus("预览模式只会查当前页面里的示例数据。登录后才会查真实记忆。");
      selectSection("search");
      return;
    }

    setStatus(`Searching your private memory for "${query}".`);
    const response = await fetch("/api/ask", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query }),
    });
    const body = (await response.json().catch(() => null)) as AskResult | {
      error?: string;
    } | null;

    if (!response.ok || !isAskResult(body)) {
      setStatus(getErrorMessage(body) || "搜索失败。");
      return;
    }

    setAskResult(body);
    setAskText("");
    setStatus("搜索完成，结果已附来源。");
    selectSection("search");
  }

  async function handleCreateReminder(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const title = reminderTitle.trim();
    if (!title || !reminderDueAt) return;
    const dueDate = new Date(reminderDueAt);

    if (!isAuthenticated) {
      setDashboard((current) => ({
        ...current,
        stats: { ...current.stats, reminders: current.stats.reminders + 1 },
        reminders: [
          {
            id: `local-reminder-${Date.now()}`,
            title,
            personName: "预览",
            dueAt: dueDate.toISOString(),
            type: "reminder",
            dueLabel: dueDate.toLocaleString(),
          },
          ...current.reminders,
        ],
      }));
      setStatus("已添加一条预览提醒。登录后才会真正保存。");
      setReminderTitle("");
      setReminderDueAt("");
      return;
    }

    setStatus("正在保存提醒...");
    const response = await fetch("/api/reminders", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title, dueAt: dueDate.toISOString() }),
    });

    if (!response.ok) {
      setStatus("提醒保存失败。");
      return;
    }

    setDashboard((current) => ({
      ...current,
      stats: { ...current.stats, reminders: current.stats.reminders + 1 },
      reminders: [
        {
          id: `saved-reminder-${Date.now()}`,
          title,
          personName: "通用",
          dueAt: dueDate.toISOString(),
          type: "reminder",
          dueLabel: dueDate.toLocaleString(),
        },
        ...current.reminders,
      ],
    }));
    setReminderTitle("");
    setReminderDueAt("");
    setStatus("提醒已保存。");
  }

  async function handleFileUpload(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const input = form.elements.namedItem("file") as HTMLInputElement | null;
    const file = input?.files?.[0];
    if (!file) return;

    if (!isAuthenticated) {
      setDashboard((current) => ({
        ...current,
        stats: { ...current.stats, files: current.stats.files + 1 },
        files: [
          {
            id: `local-file-${Date.now()}`,
            filename: file.name,
            status: "预览导入已排队",
            progress: 24,
          },
          ...current.files,
        ],
      }));
      setUploadStatus("预览文件已排队。登录后才会上传到私密存储。");
      form.reset();
      return;
    }

    const formData = new FormData();
    formData.append("file", file);
    setUploadStatus("正在上传到私密存储...");
    const response = await fetch("/api/files/upload", {
      method: "POST",
      body: formData,
    });

    if (!response.ok) {
      const body = (await response.json().catch(() => null)) as {
        error?: string;
      } | null;
      setUploadStatus(body?.error || "文件上传失败。");
      return;
    }

    setDashboard((current) => ({
      ...current,
      stats: { ...current.stats, files: current.stats.files + 1 },
      files: [
        {
          id: `uploaded-${Date.now()}`,
          filename: file.name,
          status: "处理中",
          progress: 64,
        },
        ...current.files,
      ],
    }));
    setUploadStatus("文件已上传，解析任务已排队。");
    form.reset();
  }

  async function handleAccountSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const email = accountEmail.trim().toLowerCase();
    const password = accountPassword;

    if (!hasPasswordAuth) {
      setStatus(
        "现在还不能登录：服务器已经有数据库地址，但还缺 NEXTAUTH_SECRET 或 AUTH_SECRET。",
      );
      return;
    }

    if (!email || password.length < 8) {
      setStatus("请填一个有效邮箱，密码至少 8 个字符。");
      return;
    }

    setAuthBusy(true);
    setStatus(authMode === "register" ? "正在创建账号..." : "正在登录...");

    try {
      if (authMode === "register") {
        const response = await fetch("/api/auth/register", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            email,
            name: accountName.trim(),
            password,
          }),
        });
        const body = (await response.json().catch(() => null)) as {
          error?: string;
        } | null;

        if (!response.ok) {
          setStatus(body?.error || "这个账号暂时没创建成功。");
          return;
        }
      }

      const result = await signIn("credentials", {
        email,
        password,
        redirect: false,
      });

      if (result?.error) {
        setStatus("邮箱或密码不对。");
        return;
      }

      setAccountPassword("");
      setStatus("已登录，正在打开你的私密工作区...");
      window.location.reload();
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "账号操作没有成功。");
    } finally {
      setAuthBusy(false);
    }
  }

  async function handleUpdateProfile(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const name = profileName.trim();
    if (!name) {
      setStatus("请输入一个显示名。");
      return;
    }
    if (!isAuthenticated) {
      setStatus("显示名已在预览里更新。");
      return;
    }

    setAuthBusy(true);
    const response = await fetch("/api/account", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    });
    setAuthBusy(false);
    setStatus(response.ok ? "显示名已保存。" : "显示名暂时保存失败。");
  }

  function handleLanguageModeChange(mode: LanguageMode) {
    setLanguageMode(mode);
    const nextLanguage = resolveLanguageMode(mode);
    setStatus(nextLanguage === "zh" ? "界面语言已切到中文。" : "Interface language is now English.");
  }

  function handleSaveDeepSeekSettings(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const apiKey = deepSeekApiKey.trim() || deepSeekSavedKey;
    if (!apiKey) {
      setDeepSeekStatus("先填入 DeepSeek API key，再保存。");
      return;
    }

    const settings = {
      model: deepSeekModel,
      thinkingEnabled: deepSeekThinking,
      hasSessionKey: true,
    };
    sessionStorage.setItem(deepSeekSessionKey, apiKey);
    localStorage.setItem(deepSeekStorageKey, JSON.stringify(settings));
    setDeepSeekSavedKey(apiKey);
    setDeepSeekApiKey("");
    setDeepSeekStatus("已保存到当前浏览器会话。不会写进账号资料、服务器数据库或持久化本机存储。");
    setStatus("DeepSeek 设置已保存。");
  }

  function handleRemoveDeepSeekSettings() {
    localStorage.removeItem(deepSeekStorageKey);
    sessionStorage.removeItem(deepSeekSessionKey);
    setDeepSeekApiKey("");
    setDeepSeekSavedKey("");
    setDeepSeekModel("deepseek-v4-flash");
    setDeepSeekThinking(false);
    setDeepSeekStatus("已移除当前浏览器会话里的 DeepSeek API key。");
    setStatus("DeepSeek API key 已从这台浏览器移除。");
  }

  async function handleTestDeepSeekSettings() {
    const apiKey = deepSeekApiKey.trim() || deepSeekSavedKey;
    if (!apiKey) {
      setDeepSeekStatus("先填入 DeepSeek API key，再测试连接。");
      return;
    }

    setDeepSeekBusy(true);
    setDeepSeekStatus("正在测试 DeepSeek 连接...");
    try {
      const response = await fetch("/api/deepseek/test", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          apiKey,
          model: deepSeekModel,
          thinkingEnabled: deepSeekThinking,
        }),
      });
      const body = (await response.json().catch(() => null)) as { error?: string } | null;
      setDeepSeekStatus(
        response.ok
          ? "测试通过。这组 key、模型和思考模式可以使用。"
          : body?.error || "DeepSeek 连接没有通过。",
      );
    } finally {
      setDeepSeekBusy(false);
    }
  }

  async function handleCreateGroup(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const label = newGroupLabel.trim();
    if (!label) return;
    const draft = {
      label,
      color: newGroupColor,
      description: newGroupDescription.trim(),
      sortOrder: dashboard.groups.length,
    };

    if (!isAuthenticated) {
      const group = {
        id: `local-group-${Date.now()}`,
        ...draft,
        memberCount: 0,
      };
      setDashboard((current) => ({
        ...recountGroups({
          ...current,
          groups: [...current.groups, group],
        }),
      }));
      resetGroupForm();
      setStatus("预览分组已创建。");
      return;
    }

    const response = await fetch("/api/groups", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(draft),
    });
    const body = (await response.json().catch(() => null)) as {
      group?: DashboardData["groups"][number];
      error?: string;
    } | null;

    if (!response.ok || !body?.group) {
      setStatus(body?.error || "分组创建失败。");
      return;
    }

    setDashboard((current) =>
      recountGroups({
        ...current,
        groups: [...current.groups, body.group!],
      }),
    );
    resetGroupForm();
    setStatus("分组已创建。");
  }

  async function handleUpdateGroup(
    groupId: string,
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const patch = {
      label: String(form.get("label") || "").trim(),
      color: String(form.get("color") || "#184f3c"),
      description: String(form.get("description") || "").trim(),
    };
    if (!patch.label) return;

    if (!isAuthenticated) {
      setDashboard((current) => updateGroupLocally(current, groupId, patch));
      setStatus("预览分组已更新。");
      return;
    }

    const response = await fetch(`/api/groups/${groupId}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(patch),
    });
    const body = (await response.json().catch(() => null)) as {
      group?: DashboardData["groups"][number];
      error?: string;
    } | null;

    if (!response.ok || !body?.group) {
      setStatus(body?.error || "分组保存失败。");
      return;
    }

    setDashboard((current) => updateGroupLocally(current, groupId, body.group!));
    setStatus("分组已保存。");
  }

  async function handleDeleteGroup(
    groupId: string,
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const mergeInto = String(form.get("mergeInto") || "");
    const target = mergeInto && mergeInto !== groupId ? mergeInto : "";
    const url = target ? `/api/groups/${groupId}?mergeInto=${encodeURIComponent(target)}` : `/api/groups/${groupId}`;

    if (isAuthenticated) {
      const response = await fetch(url, { method: "DELETE" });
      if (!response.ok) {
        const body = (await response.json().catch(() => null)) as { error?: string } | null;
        setStatus(body?.error || "分组删除失败。");
        return;
      }
    }

    setDashboard((current) => deleteGroupLocally(current, groupId, target || null));
    if (groupFilter === groupId) {
      setGroupFilter(null);
    }
    setStatus(target ? "分组已合并。" : "分组已删除。");
  }

  async function handleAddPersonToGroup(personId: string, groupId: string) {
    if (!groupId) return;
    if (isAuthenticated) {
      const response = await fetch(`/api/people/${personId}/groups`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ groupId }),
      });
      if (!response.ok) {
        setStatus("加入分组失败。");
        return;
      }
    }

    setDashboard((current) => addPersonToGroupLocally(current, personId, groupId));
    setStatus("已加入分组。");
  }

  async function handleRemovePersonFromGroup(personId: string, groupId: string) {
    if (isAuthenticated) {
      const response = await fetch(`/api/people/${personId}/groups`, {
        method: "DELETE",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ groupId }),
      });
      if (!response.ok) {
        setStatus("移出分组失败。");
        return;
      }
    }

    setDashboard((current) => removePersonFromGroupLocally(current, personId, groupId));
    setStatus("已移出分组。");
  }

  async function handleSignOut() {
    setAuthBusy(true);
    await signOut({ callbackUrl: "/" });
  }

  function selectSection(section: AppSection) {
    setActiveSection(section);
    setGroupFilter(null);
    setIsMobileNavOpen(false);
    syncUrl(section, null);
  }

  function selectGroup(filter: string) {
    setActiveSection("people");
    setGroupFilter(filter);
    setIsMobileNavOpen(false);
    syncUrl("people", filter);
  }

  function resetGroupForm() {
    setNewGroupLabel("");
    setNewGroupDescription("");
    setNewGroupColor("#256f56");
  }

  const privacyNote = useMemo(
    () =>
      isAuthenticated
        ? "登录后的数据只归当前账号，所有 AI 建议都保留来源。"
        : "预览数据只存在当前页面，不会真正保存。",
    [isAuthenticated],
  );

  return (
    <main className="min-h-screen bg-[#f4f0e8] pb-[calc(5rem+env(safe-area-inset-bottom))] text-[#17130f] lg:p-4 lg:pb-4">
      <div className="mx-auto flex min-h-screen max-w-[1480px] overflow-hidden rounded-none border-[#dfd3c0] bg-[#faf7ef] shadow-none ring-1 ring-black/[0.02] lg:min-h-[calc(100vh-2rem)] lg:rounded-xl lg:border lg:shadow-[0_24px_80px_rgba(48,38,24,0.14)]">
        <Sidebar
          activeSection={activeSection}
          badgeCounts={badgeCounts}
          copy={copy}
          groups={dashboard.groups}
          groupFilter={groupFilter}
          isAuthenticated={isAuthenticated}
          isOpen={isMobileNavOpen}
          items={localizedNavigationItems}
          privacyNote={privacyNote}
          userName={meName}
          onClose={() => setIsMobileNavOpen(false)}
          onSelectGroup={selectGroup}
          onSelectSection={selectSection}
        />

        <section className="flex min-w-0 flex-1 flex-col">
          <header className="flex flex-col gap-4 border-b border-[#dfd3c0] bg-[#fbf8f1]/95 px-4 py-4 md:flex-row md:items-center md:justify-between lg:px-7">
            <div className="flex min-w-0 items-start gap-3">
              <Button
                type="button"
                aria-label="打开导航"
                className="h-10 w-10 shrink-0 px-0 lg:hidden"
                onClick={() => setIsMobileNavOpen(true)}
              >
                <Menu size={18} />
              </Button>
              <div className="min-w-0">
                <p className="text-sm font-medium text-[#756d63]">
                  {uiLanguage === "zh"
                    ? `早安，${greetingName}。今天先看值得留意的人和事。`
                    : `Good morning, ${greetingName}. Start with the people who need attention.`}
                </p>
                <h2 className="mt-1 text-2xl font-semibold tracking-normal text-[#17130f]">
                  {headerTitle}
                </h2>
                <p className="mt-1 max-w-2xl text-sm leading-6 text-[#756d63]">
                  {headerSubtitle}
                </p>
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="rounded-md border border-[#dfd3c0] bg-[#fffaf2] px-3 py-2 text-xs text-[#6c6256] shadow-[inset_0_1px_0_rgba(255,255,255,0.7)]">
                {status}
              </span>
              {isAuthenticated ? (
                <Button type="button" onClick={handleSignOut} disabled={authBusy}>
                  退出
                </Button>
              ) : hasPasswordAuth || hasGoogleAuth ? (
                <Button
                  type="button"
                  variant="primary"
                  onClick={() => selectSection("settings")}
                >
                  {copy.signInButton}
                </Button>
              ) : (
                <Button
                  type="button"
                  variant="primary"
                  onClick={() => selectSection("settings")}
                >
                  {copy.settingsButton}
                </Button>
              )}
            </div>
          </header>

          {activeSection === "home" ? (
            <div className="grid flex-1 grid-cols-1 gap-5 overflow-auto p-4 lg:grid-cols-[minmax(0,1fr)_320px] lg:p-7">
              <div className="min-w-0 space-y-5">
                <ModeLandingPanel
                  analytics={analytics}
                  dashboard={dashboard}
                  uiLanguage={uiLanguage}
                  onSelectSection={selectSection}
                />

                <TodayFocusPanel
                  analytics={analytics}
                  uiLanguage={uiLanguage}
                  onSelectSection={selectSection}
                />

                <CaptureCard
                  captureText={captureText}
                  onCaptureTextChange={setCaptureText}
                  onSubmit={handleCapture}
                  onSelectSection={selectSection}
                />

                <StatusGrid dashboard={dashboard} />

                <ActiveSection
                  activeSection={activeSection}
                  analytics={analytics}
                  accountEmail={accountEmail}
                  accountName={accountName}
                  accountPassword={accountPassword}
                  authBusy={authBusy}
                  authMode={authMode}
                  askResult={askResult}
                  askText={askText}
                  dashboard={dashboard}
                  deepSeekApiKey={deepSeekApiKey}
                  deepSeekBusy={deepSeekBusy}
                  deepSeekModel={deepSeekModel}
                  deepSeekSavedKey={deepSeekSavedKey}
                  deepSeekStatus={deepSeekStatus}
                  deepSeekThinking={deepSeekThinking}
                  languageMode={languageMode}
                  groupFilter={groupFilter}
                  hasAuthSecret={hasAuthSecret}
                  hasDatabaseUrl={hasDatabaseUrl}
                  hasGoogleAuth={hasGoogleAuth}
                  hasPasswordAuth={hasPasswordAuth}
                  isAuthenticated={isAuthenticated}
                  newGroupColor={newGroupColor}
                  newGroupDescription={newGroupDescription}
                  newGroupLabel={newGroupLabel}
                  profileName={profileName}
                  reminderDueAt={reminderDueAt}
                  reminderTitle={reminderTitle}
                  uploadStatus={uploadStatus}
                  userEmail={userEmail}
                  userName={meName}
                  visiblePeople={visiblePeople}
                  onAccountEmailChange={setAccountEmail}
                  onAccountNameChange={setAccountName}
                  onAccountPasswordChange={setAccountPassword}
                  onAccountSubmit={handleAccountSubmit}
                  onAddPersonToGroup={handleAddPersonToGroup}
                  onAskTextChange={setAskText}
                  onCreateGroup={handleCreateGroup}
                  onCreateReminder={handleCreateReminder}
                  onDeleteGroup={handleDeleteGroup}
                  onDeepSeekApiKeyChange={setDeepSeekApiKey}
                  onDeepSeekModelChange={setDeepSeekModel}
                  onDeepSeekThinkingChange={setDeepSeekThinking}
                  onFileUpload={handleFileUpload}
                  onLanguageModeChange={handleLanguageModeChange}
                  onNewGroupColorChange={setNewGroupColor}
                  onNewGroupDescriptionChange={setNewGroupDescription}
                  onNewGroupLabelChange={setNewGroupLabel}
                  onProfileNameChange={setProfileName}
                  onProfileSubmit={handleUpdateProfile}
                  onRemovePersonFromGroup={handleRemovePersonFromGroup}
                  onSignOut={handleSignOut}
                  onReminderDueAtChange={setReminderDueAt}
                  onReminderTitleChange={setReminderTitle}
                  onReviewPending={reviewPending}
                  onRemoveDeepSeekSettings={handleRemoveDeepSeekSettings}
                  onSaveDeepSeekSettings={handleSaveDeepSeekSettings}
                  onSearch={handleAsk}
                  onSelectSection={selectSection}
                  onSetAuthMode={setAuthMode}
                  onTestDeepSeekSettings={handleTestDeepSeekSettings}
                  onUpdateGroup={handleUpdateGroup}
                />
              </div>

              <ContextRail
                firstPerson={firstPerson}
                hasGoogleAuth={hasGoogleAuth}
                hasPasswordAuth={hasPasswordAuth}
                isAuthenticated={isAuthenticated}
                nextActionsByPerson={analytics.nextActionsByPerson}
                selectedFile={selectedFile}
                userEmail={userEmail}
                onSelectSection={selectSection}
              />
            </div>
          ) : (
            <div className="flex-1 overflow-auto p-4 lg:p-7">
              <ActiveSection
                activeSection={activeSection}
                analytics={analytics}
                accountEmail={accountEmail}
                accountName={accountName}
                accountPassword={accountPassword}
                authBusy={authBusy}
                authMode={authMode}
                askResult={askResult}
                askText={askText}
                dashboard={dashboard}
                deepSeekApiKey={deepSeekApiKey}
                deepSeekBusy={deepSeekBusy}
                deepSeekModel={deepSeekModel}
                deepSeekSavedKey={deepSeekSavedKey}
                deepSeekStatus={deepSeekStatus}
                deepSeekThinking={deepSeekThinking}
                languageMode={languageMode}
                groupFilter={groupFilter}
                hasAuthSecret={hasAuthSecret}
                hasDatabaseUrl={hasDatabaseUrl}
                hasGoogleAuth={hasGoogleAuth}
                hasPasswordAuth={hasPasswordAuth}
                isAuthenticated={isAuthenticated}
                newGroupColor={newGroupColor}
                newGroupDescription={newGroupDescription}
                newGroupLabel={newGroupLabel}
                profileName={profileName}
                reminderDueAt={reminderDueAt}
                reminderTitle={reminderTitle}
                uploadStatus={uploadStatus}
                userEmail={userEmail}
                userName={meName}
                visiblePeople={visiblePeople}
                onAccountEmailChange={setAccountEmail}
                onAccountNameChange={setAccountName}
                onAccountPasswordChange={setAccountPassword}
                onAccountSubmit={handleAccountSubmit}
                onAddPersonToGroup={handleAddPersonToGroup}
                onAskTextChange={setAskText}
                onCreateGroup={handleCreateGroup}
                onCreateReminder={handleCreateReminder}
                onDeleteGroup={handleDeleteGroup}
                onDeepSeekApiKeyChange={setDeepSeekApiKey}
                onDeepSeekModelChange={setDeepSeekModel}
                onDeepSeekThinkingChange={setDeepSeekThinking}
                onFileUpload={handleFileUpload}
                onLanguageModeChange={handleLanguageModeChange}
                onNewGroupColorChange={setNewGroupColor}
                onNewGroupDescriptionChange={setNewGroupDescription}
                onNewGroupLabelChange={setNewGroupLabel}
                onProfileNameChange={setProfileName}
                onProfileSubmit={handleUpdateProfile}
                onRemovePersonFromGroup={handleRemovePersonFromGroup}
                onSignOut={handleSignOut}
                onReminderDueAtChange={setReminderDueAt}
                onReminderTitleChange={setReminderTitle}
                onReviewPending={reviewPending}
                onRemoveDeepSeekSettings={handleRemoveDeepSeekSettings}
                onSaveDeepSeekSettings={handleSaveDeepSeekSettings}
                onSearch={handleAsk}
                onSelectSection={selectSection}
                onSetAuthMode={setAuthMode}
                onTestDeepSeekSettings={handleTestDeepSeekSettings}
                onUpdateGroup={handleUpdateGroup}
              />
            </div>
          )}
        </section>
      </div>

      <MobileBottomNav
        activeSection={activeSection}
        badgeCounts={badgeCounts}
        copy={copy}
        items={mobileNavigationItems}
        onSelectSection={selectSection}
      />
    </main>
  );
}

function Sidebar({
  activeSection,
  badgeCounts,
  copy,
  groups,
  groupFilter,
  isAuthenticated,
  isOpen,
  items,
  privacyNote,
  userName,
  onClose,
  onSelectGroup,
  onSelectSection,
}: {
  activeSection: AppSection;
  badgeCounts: Record<string, number>;
  copy: (typeof productCopy)[UiLanguage];
  groups: DashboardData["groups"];
  groupFilter: string | null;
  isAuthenticated: boolean;
  isOpen: boolean;
  items: typeof navigationItems;
  privacyNote: string;
  userName?: string | null;
  onClose: () => void;
  onSelectGroup: (filter: string) => void;
  onSelectSection: (section: AppSection) => void;
}) {
  const groupedItems = (["home", "selfThread", "friendMemory", "system"] as NavigationMode[])
    .map((mode) => ({
      mode,
      title: navigationModeLabel(mode, copy),
      items: items.filter((item) => item.mode === mode),
    }))
    .filter((group) => group.items.length > 0);

  return (
    <>
      <div
        className={cn(
          "fixed inset-0 z-40 bg-black/30 lg:hidden",
          isOpen ? "block" : "hidden",
        )}
        onClick={onClose}
      />
      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-50 flex w-[280px] shrink-0 flex-col border-r border-[#dfd3c0] bg-[#f7f1e8] text-[#17130f] transition-transform lg:static lg:z-auto lg:w-[265px] lg:translate-x-0",
          isOpen ? "translate-x-0" : "-translate-x-full",
        )}
      >
        <div className="border-b border-[#dfd3c0] p-6">
          <div className="flex items-center justify-between gap-3">
            <div className="flex min-w-0 items-center gap-3">
              <div className="grid h-9 w-9 shrink-0 place-items-center rounded-lg border border-[#d2c4ad] bg-[#fffaf2] text-[#176b4d]">
                <Sparkles size={18} />
              </div>
              <div className="min-w-0">
                <h1 className="text-lg font-semibold tracking-normal text-[#17130f]">
                  Memoria
                </h1>
                <p className="truncate text-xs text-[#7b7166]">
                  {copy.brandLine}
                </p>
              </div>
            </div>
            <Button
              type="button"
              aria-label="关闭导航"
              className="h-9 w-9 px-0 lg:hidden"
              onClick={onClose}
            >
              <X size={16} />
            </Button>
          </div>
        </div>

        <nav className="flex-1 space-y-6 overflow-auto px-4 py-5">
          <div>
            <p className="px-3 text-[11px] font-medium uppercase tracking-[0.12em] text-[#9a8d7c]">
              {copy.quickRecord}
            </p>
            <button
              type="button"
              onClick={() => onSelectSection("home")}
              className="mt-2 flex h-10 w-full items-center gap-2 rounded-full bg-[#17130f] px-4 text-sm font-medium text-white"
            >
              <Plus size={16} />
              {copy.captureAction}
            </button>
          </div>

          <div className="space-y-5">
            {groupedItems.map((group) => (
              <div key={group.mode}>
                <p className="px-3 text-[11px] font-medium uppercase tracking-[0.12em] text-[#9a8d7c]">
                  {group.title}
                </p>
                <div className="mt-2 space-y-1">
                  {group.items.map((item) => {
                    const Icon = item.icon;
                    const badge = item.badgeKey ? badgeCounts[item.badgeKey] || 0 : 0;
                    const isActive = activeSection === item.section && !groupFilter;
                    const ariaLabel = copy.navAria[item.section];
                    return (
                      <button
                        key={item.section}
                        type="button"
                        aria-label={badge ? `${ariaLabel} ${badge}` : ariaLabel}
                        onClick={() => onSelectSection(item.section)}
                        className={cn(
                          "flex min-h-11 w-full items-center justify-between gap-3 rounded-full border border-transparent px-3 text-sm text-[#5f564b] transition hover:border-[#dfd3c0] hover:bg-[#fffaf2]",
                          isActive && "border-[#17130f] bg-[#17130f] text-white",
                        )}
                      >
                        <span className="flex min-w-0 items-center gap-3">
                          <Icon size={17} className="shrink-0" />
                          <span className="truncate">{item.label}</span>
                        </span>
                        {badge ? (
                          <span className={cn("rounded-full bg-[#eadfce] px-2 py-0.5 text-[11px] text-[#5f564b]", isActive && "bg-white/15 text-white")}>
                            {badge}
                          </span>
                        ) : null}
                      </button>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>

          <div>
            <p className="px-3 text-[11px] font-medium uppercase tracking-[0.12em] text-[#9a8d7c]">
              分组
            </p>
            <div className="mt-2 space-y-1">
              {groups.map((group) => (
                <button
                  key={group.id}
                  type="button"
                  aria-label={group.label}
                  onClick={() => onSelectGroup(group.id)}
                  className={cn(
                    "flex min-h-10 w-full items-center gap-3 rounded-full border border-transparent px-3 text-sm text-[#6c6256] hover:border-[#dfd3c0] hover:bg-[#fffaf2]",
                    groupFilter === group.id && "border-[#17130f] bg-[#17130f] text-white",
                  )}
                >
                  <span
                    className="h-2.5 w-2.5 rounded-full"
                    style={{ backgroundColor: group.color }}
                  />
                  <span className="truncate">{group.label}</span>
                  <span className={cn("ml-auto text-[11px] text-[#9a8d7c]", groupFilter === group.id && "text-white/70")}>
                    {group.memberCount}
                  </span>
                </button>
              ))}
            </div>
          </div>
        </nav>

        <div className="space-y-4 p-4">
          <div className="rounded-xl border border-[#dfd3c0] bg-[#fffaf2] p-4 text-sm text-[#5f564b]">
            <div className="flex items-center justify-between text-[#17130f]">
              <span className="font-medium">隐私边界清楚</span>
              <Lock size={15} />
            </div>
            <p className="mt-2 text-xs leading-5 text-[#756d63]">
              {privacyNote}
            </p>
          </div>
          <div className="flex items-center justify-between border-t border-[#dfd3c0] pt-4">
            <div className="flex min-w-0 items-center gap-3">
              <div className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#17130f] text-sm font-semibold text-white">
                {userName ? userName[0]?.toUpperCase() : "E"}
              </div>
              <div className="min-w-0">
                <p className="truncate text-sm font-medium text-[#17130f]">
                  {userName || "Me"}
                </p>
                <p className="text-xs text-[#7b7166]">
                  {isAuthenticated ? "已登录" : "预览账号"}
                </p>
              </div>
            </div>
            <ChevronRight size={16} />
          </div>
        </div>
      </aside>
    </>
  );
}

function navigationModeLabel(
  mode: NavigationMode,
  copy: (typeof productCopy)[UiLanguage],
): string {
  const isChinese = copy.navLabels.home === "首页";
  const labels: Record<NavigationMode, string> = {
    home: "Memoria",
    selfThread: isChinese ? "自我脉络" : "Self Thread",
    friendMemory: isChinese ? "朋友记忆" : "Friend Memory",
    system: isChinese ? "系统" : "System",
  };
  return labels[mode];
}

function ModeLandingPanel({
  analytics,
  dashboard,
  uiLanguage,
  onSelectSection,
}: {
  analytics: ReturnType<typeof deriveDashboardAnalytics>;
  dashboard: DashboardData;
  uiLanguage: UiLanguage;
  onSelectSection: (section: AppSection) => void;
}) {
  const isChinese = uiLanguage === "zh";
  const modeCards = [
    {
      title: isChinese ? "自我脉络" : "Self Thread",
      subtitle: "Self Thread",
      icon: Sparkles,
      section: "brief" as AppSection,
      secondarySection: "inbox" as AppSection,
      body: isChinese
        ? "个人反思、近期记录和 AI 待确认建议先在这里形成自己的记忆脉络。"
        : "Personal reflection, recent captures, and AI review form your own memory thread here.",
      metrics: [
        { label: isChinese ? "待确认" : "AI review", value: dashboard.stats.inbox },
        { label: isChinese ? "今日重点" : "Focus", value: analytics.focusItems.length },
      ],
    },
    {
      title: isChinese ? "朋友记忆" : "Friend Memory",
      subtitle: "Friend Memory",
      icon: Users,
      section: "people" as AppSection,
      secondarySection: "map" as AppSection,
      body: isChinese
        ? "朋友档案、确认记忆、关系星图和礼物提醒收在一个安静的关系工作区。"
        : "People profiles, confirmed memories, relationship map, and gift cues live together.",
      metrics: [
        { label: isChinese ? "朋友" : "People", value: dashboard.people.length },
        { label: isChinese ? "关系边" : "Edges", value: dashboard.relationshipGraph.edges.length },
      ],
    },
  ];

  return (
    <section className="rounded-xl border border-[#dfd3c0] bg-[#fffaf2] p-4 shadow-[0_1px_2px_rgba(48,38,24,0.04)]">
      <div className="flex flex-col gap-2 border-b border-[#e6dccb] pb-3 md:flex-row md:items-center md:justify-between">
        <div>
          <p className="font-mono text-xs uppercase tracking-[0.16em] text-[#9a8d7c]">
            Memoria
          </p>
          <h3 className="mt-1 text-xl font-semibold tracking-normal text-[#17130f]">
            {isChinese ? "两个工作模式" : "Two workspace modes"}
          </h3>
        </div>
        <span className="inline-flex items-center gap-1 rounded-full border border-[#dfd3c0] bg-white px-3 py-1.5 text-xs text-[#6c6256]">
          <ShieldCheck size={14} />
          {isChinese ? "确认后才入库" : "Confirm before saving"}
        </span>
      </div>

      <div className="mt-4 grid gap-3 md:grid-cols-2">
        {modeCards.map((mode) => {
          const Icon = mode.icon;
          return (
            <article
              key={mode.title}
              className="rounded-lg border border-[#e6dccb] bg-white p-4 shadow-[0_1px_0_rgba(48,38,24,0.03)]"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <span className="inline-flex items-center gap-2 text-xs font-medium text-[#176b4d]">
                    <Icon size={15} />
                    {mode.subtitle}
                  </span>
                  <h4 className="mt-2 text-2xl font-semibold tracking-normal text-[#17130f]">
                    {mode.title}
                  </h4>
                  <p className="mt-2 text-sm leading-6 text-[#6c6256]">
                    {mode.body}
                  </p>
                </div>
                <button
                  type="button"
                  aria-label={`${mode.title} ${isChinese ? "打开" : "open"}`}
                  onClick={() => onSelectSection(mode.section)}
                  className="grid h-10 w-10 shrink-0 place-items-center rounded-lg border border-[#dfd3c0] bg-[#fffaf2] text-[#176b4d] transition hover:border-[#17130f] hover:text-[#17130f]"
                >
                  <ArrowUpRight size={17} />
                </button>
              </div>
              <div className="mt-4 grid grid-cols-2 gap-2">
                {mode.metrics.map((metric) => (
                  <div key={metric.label} className="rounded-md border border-[#efe5d6] bg-[#fbf8f1] p-3">
                    <p className="text-[11px] text-[#8a7c6b]">{metric.label}</p>
                    <p className="mt-1 text-2xl font-semibold tracking-normal text-[#17130f]">
                      {metric.value}
                    </p>
                  </div>
                ))}
              </div>
              <div className="mt-4 flex flex-wrap gap-2">
                <Button type="button" variant="primary" onClick={() => onSelectSection(mode.section)}>
                  {isChinese ? "进入" : "Open"}
                </Button>
                <Button type="button" onClick={() => onSelectSection(mode.secondarySection)}>
                  {mode.secondarySection === "map"
                    ? isChinese ? "看关系星图" : "View map"
                    : isChinese ? "处理待确认" : "Review inbox"}
                </Button>
              </div>
            </article>
          );
        })}
      </div>
    </section>
  );
}

function TodayFocusPanel({
  analytics,
  uiLanguage,
  onSelectSection,
}: {
  analytics: ReturnType<typeof deriveDashboardAnalytics>;
  uiLanguage: UiLanguage;
  onSelectSection: (section: AppSection) => void;
}) {
  const firstFocus = analytics.focusItems[0];

  return (
    <section className="mb-24 overflow-hidden rounded-lg border border-[#d1ddd5] bg-[#10231f] text-white shadow-[0_16px_42px_rgba(16,35,31,0.16)] sm:mb-0">
      <div className="grid gap-4 p-4 md:grid-cols-[1fr_1.3fr] md:p-5">
        <div className="flex flex-col justify-between gap-4">
          <div>
            <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.14em] text-[#9eb5aa]">
              <WandSparkles size={15} />
              今日重点
            </div>
            <h3 className="mt-3 text-xl font-semibold tracking-normal">
              {firstFocus?.label || "先记一条新近况"}
            </h3>
            <p className="mt-2 text-sm leading-6 text-[#bfd0c8]">
              {firstFocus?.detail ||
                "随手记一条朋友近况，确认有用的信息后，这里会整理出下一步。"}
            </p>
          </div>
          <div className="grid grid-cols-3 gap-2">
            <FocusStat label="待确认" value={analytics.relationshipHealth.pendingReviews} />
            <FocusStat label="要联系" value={analytics.relationshipHealth.upcomingReminders} />
            <FocusStat label="礼物" value={analytics.relationshipHealth.giftOpportunities} />
          </div>
        </div>

        <div className="grid gap-2">
          {analytics.focusItems.length ? (
            analytics.focusItems.map((item, index) => (
              <button
                key={item.id}
                type="button"
                onClick={() => onSelectSection(item.section)}
                className={cn(
                  "group gap-1 rounded-lg border border-white/10 bg-white/[0.06] p-3 text-left transition hover:bg-white/[0.1]",
                  index > 1 ? "hidden sm:grid" : "grid",
                )}
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold text-white">
                      {item.label}
                    </p>
                    <p className="mt-1 line-clamp-2 text-xs leading-5 text-[#bfd0c8]">
                      {item.detail}
                    </p>
                  </div>
                  <span className="shrink-0 rounded-full bg-[#d9c987] px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.08em] text-[#17231f]">
                    {item.priority}
                  </span>
                </div>
                <span className="mt-1 inline-flex items-center gap-1 text-xs font-medium text-[#dcebe3]">
                  打开 {sectionDisplayLabel(item.section, uiLanguage)}
                  <ArrowUpRight size={13} className="transition group-hover:translate-x-0.5 group-hover:-translate-y-0.5" />
                </span>
              </button>
            ))
          ) : (
            <div className="grid min-h-32 place-items-center rounded-lg border border-white/10 bg-white/[0.05] p-4 text-center">
              <p className="max-w-sm text-sm leading-6 text-[#bfd0c8]">
                暂时没有特别急的事。先记一条近况或加一个提醒，今日重点就会开始工作。
              </p>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}

function FocusStat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-lg border border-white/10 bg-white/[0.06] p-3">
      <p className="text-[11px] text-[#9eb5aa]">{label}</p>
      <p className="mt-1 text-2xl font-semibold tracking-normal text-white">
        {value}
      </p>
    </div>
  );
}

function MobileBottomNav({
  activeSection,
  badgeCounts,
  copy,
  items,
  onSelectSection,
}: {
  activeSection: AppSection;
  badgeCounts: Record<string, number>;
  copy: (typeof productCopy)[UiLanguage];
  items: typeof navigationItems;
  onSelectSection: (section: AppSection) => void;
}) {
  return (
    <nav className="fixed inset-x-0 bottom-0 z-30 grid grid-cols-5 border-t border-[#dfd3c0] bg-[#fbf8f1]/95 px-2 pb-[calc(0.5rem+env(safe-area-inset-bottom))] pt-2 backdrop-blur lg:hidden">
      {items.map((item) => {
        const Icon = item.icon;
        const badge = item.badgeKey ? badgeCounts[item.badgeKey] || 0 : 0;
        return (
          <button
            key={item.section}
            type="button"
            aria-label={
              badge
                ? `Mobile ${copy.navAria[item.section]} ${badge}`
                : `Mobile ${copy.navAria[item.section]}`
            }
            onClick={() => onSelectSection(item.section)}
            className={cn(
              "relative flex min-h-12 flex-col items-center justify-center gap-1 rounded-md px-1 text-[11px] font-medium text-[#756d63]",
              activeSection === item.section && "bg-[#17130f] text-white",
            )}
          >
            <Icon size={17} />
            <span className="max-w-full truncate">{mobileNavLabel(item.section, item.label)}</span>
            {badge ? (
              <span className="absolute right-2 top-1 rounded-full bg-[#176b4d] px-1.5 text-[10px] text-white">
                {badge}
              </span>
            ) : null}
          </button>
        );
      })}
    </nav>
  );
}

function CaptureCard({
  captureText,
  onCaptureTextChange,
  onSelectSection,
  onSubmit,
}: {
  captureText: string;
  onCaptureTextChange: (value: string) => void;
  onSelectSection: (section: AppSection) => void;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
}) {
  return (
    <form
      onSubmit={onSubmit}
      className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]"
    >
      <label htmlFor="capture" className="text-sm font-semibold text-[#20342b]">
        随手记一条朋友近况
      </label>
      <div className="mt-3 flex min-h-[92px] gap-3 rounded-lg border border-[#dce5de] bg-[#fbfcfb] p-3 focus-within:border-[#184f3c]">
        <textarea
          id="capture"
          value={captureText}
          onChange={(event) => onCaptureTextChange(event.target.value)}
          placeholder="比如：昨天和 Alex 吃火锅，他不吃香菜，最近在准备 5/20 的微积分期中"
          className="min-h-[68px] flex-1 resize-none bg-transparent text-sm leading-6 text-[#17231f] outline-none placeholder:text-[#8a9891]"
        />
        <div className="flex flex-col justify-between gap-2">
          <Button type="button" aria-label="语音输入" className="h-8 w-8 px-0">
            <Mic size={15} />
          </Button>
          <Button
            type="submit"
            variant="primary"
            aria-label="记录记忆"
            className="h-8 w-8 px-0"
          >
            <Send size={15} />
          </Button>
        </div>
      </div>
      <div className="mt-3 flex flex-wrap gap-2">
        <Button type="button" onClick={() => onSelectSection("people")}>
          <Users size={15} />
          加朋友
        </Button>
        <Button type="button" onClick={() => onSelectSection("reminders")}>
          <Bell size={15} />
          加提醒
        </Button>
        <Button type="button" onClick={() => onSelectSection("files")}>
          <FileUp size={15} />
          传文件
        </Button>
        <Button type="button" onClick={() => onSelectSection("search")}>
          <MessageCircle size={15} />
          问记忆
        </Button>
      </div>
    </form>
  );
}

function StatusGrid({ dashboard }: { dashboard: DashboardData }) {
  return (
    <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
      <StatusCard
        label="待确认"
        value={dashboard.stats.inbox}
        helper="条建议"
        icon={<Inbox size={17} />}
      />
      <StatusCard
        label="提醒"
        value={dashboard.stats.reminders}
        helper="近期"
        icon={<Bell size={17} />}
      />
      <StatusCard
        label="生日"
        value={dashboard.stats.birthdays}
        helper="7 天内"
        icon={<CalendarDays size={17} />}
      />
      <StatusCard
        label="文件"
        value={dashboard.stats.files}
        helper="处理中"
        icon={<FileUp size={17} />}
      />
    </div>
  );
}

function mobileNavLabel(section: AppSection, label: string): string {
  const compactLabels: Partial<Record<AppSection, string>> = {
    people: label === "People" ? "People" : "朋友",
    map: label === "Map" || label === "Relationship Map" ? "Map" : "星图",
    settings: label === "Settings" ? "Settings" : "设置",
  };
  return compactLabels[section] || label;
}

function ActiveSection({
  activeSection,
  analytics,
  accountEmail,
  accountName,
  accountPassword,
  authBusy,
  authMode,
  askResult,
  askText,
  dashboard,
  deepSeekApiKey,
  deepSeekBusy,
  deepSeekModel,
  deepSeekSavedKey,
  deepSeekStatus,
  deepSeekThinking,
  languageMode,
  groupFilter,
  hasAuthSecret,
  hasDatabaseUrl,
  hasGoogleAuth,
  hasPasswordAuth,
  isAuthenticated,
  newGroupColor,
  newGroupDescription,
  newGroupLabel,
  profileName,
  reminderDueAt,
  reminderTitle,
  uploadStatus,
  userEmail,
  userName,
  visiblePeople,
  onAccountEmailChange,
  onAccountNameChange,
  onAccountPasswordChange,
  onAccountSubmit,
  onAddPersonToGroup,
  onAskTextChange,
  onCreateGroup,
  onCreateReminder,
  onDeleteGroup,
  onDeepSeekApiKeyChange,
  onDeepSeekModelChange,
  onDeepSeekThinkingChange,
  onFileUpload,
  onLanguageModeChange,
  onNewGroupColorChange,
  onNewGroupDescriptionChange,
  onNewGroupLabelChange,
  onProfileNameChange,
  onProfileSubmit,
  onRemovePersonFromGroup,
  onSignOut,
  onReminderDueAtChange,
  onReminderTitleChange,
  onReviewPending,
  onRemoveDeepSeekSettings,
  onSaveDeepSeekSettings,
  onSearch,
  onSelectSection,
  onSetAuthMode,
  onTestDeepSeekSettings,
  onUpdateGroup,
}: {
  activeSection: AppSection;
  analytics: ReturnType<typeof deriveDashboardAnalytics>;
  accountEmail: string;
  accountName: string;
  accountPassword: string;
  authBusy: boolean;
  authMode: "sign-in" | "register";
  askResult: AskResult | null;
  askText: string;
  dashboard: DashboardData;
  deepSeekApiKey: string;
  deepSeekBusy: boolean;
  deepSeekModel: DeepSeekModel;
  deepSeekSavedKey: string;
  deepSeekStatus: string;
  deepSeekThinking: boolean;
  languageMode: LanguageMode;
  groupFilter: string | null;
  hasAuthSecret: boolean;
  hasDatabaseUrl: boolean;
  hasGoogleAuth: boolean;
  hasPasswordAuth: boolean;
  isAuthenticated: boolean;
  newGroupColor: string;
  newGroupDescription: string;
  newGroupLabel: string;
  profileName: string;
  reminderDueAt: string;
  reminderTitle: string;
  uploadStatus: string;
  userEmail?: string | null;
  userName?: string | null;
  visiblePeople: DashboardData["people"];
  onAccountEmailChange: (value: string) => void;
  onAccountNameChange: (value: string) => void;
  onAccountPasswordChange: (value: string) => void;
  onAccountSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onAddPersonToGroup: (personId: string, groupId: string) => void;
  onAskTextChange: (value: string) => void;
  onCreateGroup: (event: FormEvent<HTMLFormElement>) => void;
  onCreateReminder: (event: FormEvent<HTMLFormElement>) => void;
  onDeleteGroup: (groupId: string, event: FormEvent<HTMLFormElement>) => void;
  onDeepSeekApiKeyChange: (value: string) => void;
  onDeepSeekModelChange: (value: DeepSeekModel) => void;
  onDeepSeekThinkingChange: (value: boolean) => void;
  onFileUpload: (event: FormEvent<HTMLFormElement>) => void;
  onLanguageModeChange: (mode: LanguageMode) => void;
  onNewGroupColorChange: (value: string) => void;
  onNewGroupDescriptionChange: (value: string) => void;
  onNewGroupLabelChange: (value: string) => void;
  onProfileNameChange: (value: string) => void;
  onProfileSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onRemovePersonFromGroup: (personId: string, groupId: string) => void;
  onSignOut: () => void;
  onReminderDueAtChange: (value: string) => void;
  onReminderTitleChange: (value: string) => void;
  onReviewPending: (id: string, action: "confirm" | "discard") => void;
  onRemoveDeepSeekSettings: () => void;
  onSaveDeepSeekSettings: (event: FormEvent<HTMLFormElement>) => void;
  onSearch: (event: FormEvent<HTMLFormElement>) => void;
  onSelectSection: (section: AppSection) => void;
  onSetAuthMode: (mode: "sign-in" | "register") => void;
  onTestDeepSeekSettings: () => void;
  onUpdateGroup: (groupId: string, event: FormEvent<HTMLFormElement>) => void;
}) {
  if (activeSection === "settings") {
    return (
      <AccountSettingsView
        accountEmail={accountEmail}
        accountName={accountName}
        accountPassword={accountPassword}
        authBusy={authBusy}
        authMode={authMode}
        deepSeekApiKey={deepSeekApiKey}
        deepSeekBusy={deepSeekBusy}
        deepSeekModel={deepSeekModel}
        deepSeekSavedKey={deepSeekSavedKey}
        deepSeekStatus={deepSeekStatus}
        deepSeekThinking={deepSeekThinking}
        hasAuthSecret={hasAuthSecret}
        hasDatabaseUrl={hasDatabaseUrl}
        hasGoogleAuth={hasGoogleAuth}
        hasPasswordAuth={hasPasswordAuth}
        isAuthenticated={isAuthenticated}
        languageMode={languageMode}
        profileName={profileName}
        userEmail={userEmail}
        userName={userName}
        onAccountEmailChange={onAccountEmailChange}
        onAccountNameChange={onAccountNameChange}
        onAccountPasswordChange={onAccountPasswordChange}
        onAccountSubmit={onAccountSubmit}
        onDeepSeekApiKeyChange={onDeepSeekApiKeyChange}
        onDeepSeekModelChange={onDeepSeekModelChange}
        onDeepSeekThinkingChange={onDeepSeekThinkingChange}
        onLanguageModeChange={onLanguageModeChange}
        onProfileNameChange={onProfileNameChange}
        onProfileSubmit={onProfileSubmit}
        onRemoveDeepSeekSettings={onRemoveDeepSeekSettings}
        onSaveDeepSeekSettings={onSaveDeepSeekSettings}
        onSetAuthMode={onSetAuthMode}
        onSignOut={onSignOut}
        onTestDeepSeekSettings={onTestDeepSeekSettings}
      />
    );
  }

  if (activeSection === "people") {
    return (
      <PeopleView
        groups={dashboard.groups}
        groupFilter={groupFilter}
        gifts={dashboard.gifts}
        nextActionsByPerson={analytics.nextActionsByPerson}
        people={visiblePeople}
        pendingUpdates={dashboard.pendingUpdates}
        relationshipGraph={dashboard.relationshipGraph}
        relationshipScores={dashboard.relationshipScores}
        onAddPersonToGroup={onAddPersonToGroup}
        onRemovePersonFromGroup={onRemovePersonFromGroup}
      />
    );
  }

  if (activeSection === "groups") {
    return (
      <GroupsView
        groups={dashboard.groups}
        newGroupColor={newGroupColor}
        newGroupDescription={newGroupDescription}
        newGroupLabel={newGroupLabel}
        people={dashboard.people}
        onCreateGroup={onCreateGroup}
        onDeleteGroup={onDeleteGroup}
        onNewGroupColorChange={onNewGroupColorChange}
        onNewGroupDescriptionChange={onNewGroupDescriptionChange}
        onNewGroupLabelChange={onNewGroupLabelChange}
        onUpdateGroup={onUpdateGroup}
      />
    );
  }

  if (activeSection === "calendar") {
    return (
      <CalendarView
        events={dashboard.calendarEvents}
        groups={dashboard.groups}
        people={dashboard.people}
      />
    );
  }

  if (activeSection === "reminders") {
    return (
      <RemindersView
        dueAt={reminderDueAt}
        reminders={dashboard.reminders}
        title={reminderTitle}
        workload={analytics.reminderWindowCounts}
        onDueAtChange={onReminderDueAtChange}
        onSubmit={onCreateReminder}
        onTitleChange={onReminderTitleChange}
      />
    );
  }

  if (activeSection === "gifts") {
    return <GiftIdeasView gifts={dashboard.gifts} />;
  }

  if (activeSection === "search") {
    return (
      <SearchView
        askResult={askResult}
        askSuggestions={analytics.askSuggestions}
        askText={askText}
        onAskTextChange={onAskTextChange}
        onSearch={onSearch}
      />
    );
  }

  if (activeSection === "map") {
    return (
      <RelationshipMapView
        graph={dashboard.relationshipGraph}
        scores={dashboard.relationshipScores}
      />
    );
  }

  if (activeSection === "files") {
    return (
      <FilesView
        fileStatusCounts={analytics.fileStatusCounts}
        files={dashboard.files}
        uploadStatus={uploadStatus}
        onFileUpload={onFileUpload}
      />
    );
  }

  if (activeSection === "brief") {
    return (
      <DailyBriefView
        dashboard={dashboard}
        analytics={analytics}
        onSelectSection={onSelectSection}
      />
    );
  }

  return (
    <div className="space-y-5">
      <AnalyticsOverview analytics={analytics} />
      <InboxView
        pendingUpdates={dashboard.pendingUpdates}
        onReviewPending={onReviewPending}
      />
      <div className="grid gap-5 xl:grid-cols-3">
        <CompactPeoplePanel
          nextActionsByPerson={analytics.nextActionsByPerson}
          people={dashboard.people}
          onSelectSection={onSelectSection}
        />
        <CompactRemindersPanel
          reminders={dashboard.reminders}
          onSelectSection={onSelectSection}
        />
        <CompactGiftsPanel gifts={dashboard.gifts} onSelectSection={onSelectSection} />
      </div>
      <RelationshipMapPreview
        graph={dashboard.relationshipGraph}
        onSelectSection={onSelectSection}
      />
    </div>
  );
}

function AnalyticsOverview({
  analytics,
}: {
  analytics: ReturnType<typeof deriveDashboardAnalytics>;
}) {
  return (
    <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
      <div className="flex flex-col gap-2 border-b border-[#e3eae5] pb-3 md:flex-row md:items-center md:justify-between">
        <div>
          <h3 className="text-sm font-semibold text-[#1d3128]">
            关系维护总览
          </h3>
          <p className="mt-1 text-xs text-[#68766f]">
            这些不是给朋友打分，而是提醒你哪些关系需要补一句问候、补一条资料或确认一条建议。
          </p>
        </div>
        <Sparkles size={17} className="text-[#184f3c]" />
      </div>

      <div className="mt-4 grid gap-4 xl:grid-cols-[1.1fr_1fr]">
        <div className="grid grid-cols-2 gap-3">
          <MetricTile
            helper="最近有明确互动、提醒或资料更新的人。"
            label="近期活跃"
            value={analytics.relationshipHealth.activePeople}
          />
          <MetricTile
            helper="AI 还在等你确认的建议，确认后才写进档案。"
            label="待确认"
            value={analytics.relationshipHealth.pendingReviews}
          />
          <MetricTile
            helper="近期需要联系、问候或准备的事项。"
            label="近期提醒"
            value={analytics.relationshipHealth.upcomingReminders}
          />
          <MetricTile
            helper="生日、喜好和生活节点带来的礼物机会。"
            label="礼物机会"
            value={analytics.relationshipHealth.giftOpportunities}
          />
        </div>
        <SparklineChart items={analytics.activityTimeline} />
      </div>

      <div className="mt-4 grid gap-4 md:grid-cols-3">
        <BarList title="分组人数" items={analytics.groupCounts} />
        <BarList title="待确认类型" items={analytics.pendingTypeCounts} />
        <BarList title="提醒时间" items={analytics.reminderWindowCounts} />
      </div>
    </section>
  );
}

function InboxView({
  pendingUpdates,
  onReviewPending,
}: {
  pendingUpdates: DashboardData["pendingUpdates"];
  onReviewPending: (id: string, action: "confirm" | "discard") => void;
}) {
  return (
    <section className="rounded-lg border border-[#dce5de] bg-white shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
      <div className="flex items-center justify-between border-b border-[#e3eae5] px-4 py-3">
        <h3 className="text-sm font-semibold text-[#1d3128]">
          AI Inbox 待确认 ({pendingUpdates.length})
        </h3>
        <span className="text-xs font-medium text-[#184f3c]">保留来源</span>
      </div>
      {pendingUpdates.length ? (
        <div className="divide-y divide-[#eef2ef]">
          {pendingUpdates.map((item) => (
            <article
              key={item.id}
              className="grid gap-3 px-4 py-3 md:grid-cols-[1fr_auto]"
            >
              <div className="min-w-0">
                <div className="flex items-start gap-3">
                  <span className="mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-md bg-[#eef6f1] text-[#184f3c]">
                    <ShieldCheck size={15} />
                  </span>
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="truncate text-sm font-medium text-[#17231f]">
                        {item.summary}
                      </p>
                      <span className="rounded-full bg-[#eef6f1] px-2 py-0.5 text-[11px] font-medium text-[#184f3c]">
                        {item.type}
                      </span>
                    </div>
                    <p className="mt-1 text-xs text-[#68766f]">
                      {item.createdLabel} · {item.evidence}
                    </p>
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className="hidden text-xs text-[#68766f] md:inline">
                  {item.personName}
                </span>
                <Button
                  type="button"
                  onClick={() => onReviewPending(item.id, "discard")}
                >
                  丢弃
                </Button>
                <Button
                  type="button"
                  variant="primary"
                  onClick={() => onReviewPending(item.id, "confirm")}
                >
                  确认
                </Button>
              </div>
            </article>
          ))}
        </div>
      ) : (
        <EmptyState
          icon={<Inbox size={19} />}
          title="没有待确认"
          body="随手记一条近况，AI 建议会先等在这里，确认后才会改人物档案。"
        />
      )}
    </section>
  );
}

function PeopleView({
  groups,
  groupFilter,
  gifts,
  nextActionsByPerson,
  people,
  pendingUpdates,
  relationshipGraph,
  relationshipScores,
  onAddPersonToGroup,
  onRemovePersonFromGroup,
}: {
  groups: DashboardData["groups"];
  groupFilter: string | null;
  gifts: DashboardData["gifts"];
  nextActionsByPerson: Record<string, string>;
  people: DashboardData["people"];
  pendingUpdates: DashboardData["pendingUpdates"];
  relationshipGraph: DashboardData["relationshipGraph"];
  relationshipScores: DashboardData["relationshipScores"];
  onAddPersonToGroup: (personId: string, groupId: string) => void;
  onRemovePersonFromGroup: (personId: string, groupId: string) => void;
}) {
  const title = groupFilter ? `${groupLabel(groups, groupFilter)} · 朋友` : "朋友档案";
  const scoreByPerson = new Map(relationshipScores.map((score) => [score.personId, score]));
  const [selectedPersonId, setSelectedPersonId] = useState(people[0]?.id || "");
  const selectedPerson =
    people.find((person) => person.id === selectedPersonId) || people[0] || null;
  const selectedScore = selectedPerson ? scoreByPerson.get(selectedPerson.id) : undefined;

  return (
    <div className="space-y-5">
      {selectedPerson ? (
        <PersonDetailPanel
          groups={groups}
          gifts={gifts}
          person={selectedPerson}
          pendingUpdates={pendingUpdates}
          relationshipGraph={relationshipGraph}
          score={selectedScore}
          onAddPersonToGroup={onAddPersonToGroup}
          onRemovePersonFromGroup={onRemovePersonFromGroup}
        />
      ) : null}

      <section className="rounded-xl border border-[#dfd3c0] bg-white p-4 shadow-[0_1px_2px_rgba(48,38,24,0.04)]">
        <div className="flex flex-col gap-2 border-b border-[#e6dccb] pb-3 md:flex-row md:items-center md:justify-between">
          <div>
            <h3 className="text-sm font-semibold text-[#1d3128]">{title}</h3>
            <p className="mt-1 text-xs text-[#68766f]">
              共 {people.length} 位朋友。点开任何一张卡片，就能看完整人物档案。
            </p>
          </div>
          <span className="rounded-md border border-[#dce5de] px-3 py-1.5 text-xs text-[#52625b]">
            关系维护评分
          </span>
        </div>
        {people.length ? (
          <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {people.map((person) => {
              const score = scoreByPerson.get(person.id);
              return (
              <article
                key={person.id}
                className={cn(
                  "rounded-lg border bg-[#fbfcfb] p-4 shadow-[0_1px_0_rgba(16,35,31,0.03)] transition hover:border-[#17130f] hover:bg-white",
                  selectedPerson?.id === person.id
                    ? "border-[#17130f]"
                    : "border-[#dce5de]",
                )}
              >
                <button
                  type="button"
                  onClick={() => setSelectedPersonId(person.id)}
                  className="flex w-full items-center gap-3 text-left"
                >
                  <div className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-[#dcebe3] text-sm font-semibold text-[#184f3c]">
                    {person.initials}
                  </div>
                  <div className="min-w-0">
                    <h4 className="truncate text-sm font-semibold text-[#17231f]">
                      {person.displayName}
                    </h4>
                    <p className="truncate text-xs text-[#68766f]">
                      {person.relationLabel}
                    </p>
                  </div>
                </button>

                {score ? <ScoreMeter score={score} /> : null}

                <div className="mt-3 flex flex-wrap gap-1.5">
                  {person.groupIds.map((groupId) => {
                    const label = groupLabel(groups, groupId);
                    return (
                      <button
                        key={groupId}
                        type="button"
                        onClick={() => onRemovePersonFromGroup(person.id, groupId)}
                        className="rounded-full border border-[#dce5de] bg-white px-2 py-1 text-[11px] text-[#52625b] hover:border-[#b9c9c0]"
                        title={`把 ${person.displayName} 移出 ${label}`}
                      >
                        {label} ×
                      </button>
                    );
                  })}
                </div>

                <label className="mt-3 block text-xs font-medium text-[#52625b]">
                  加入分组
                  <select
                    className="mt-1 w-full rounded-md border border-[#dce5de] bg-white px-3 py-2 text-sm"
                    defaultValue=""
                    onChange={(event) => {
                      onAddPersonToGroup(person.id, event.target.value);
                      event.currentTarget.value = "";
                    }}
                  >
                    <option value="">选择分组...</option>
                    {groups
                      .filter((group) => !person.groupIds.includes(group.id))
                      .map((group) => (
                        <option key={group.id} value={group.id}>
                          {group.label}
                        </option>
                      ))}
                  </select>
                </label>

                <dl className="mt-4 grid grid-cols-2 gap-2">
                  <Info label="生日" value={person.birthday} />
                  <Info label="忌口" value={person.dietaryRestrictions} />
                  <Info label="爱吃" value={person.favoriteFoods} />
                  <Info label="不喜欢" value={person.dislikedThings} />
                  <Info label="星座" value={person.zodiacSign} />
                  <Info label="MBTI" value={person.mbti} />
                  <Info label="兴趣" value={person.interests} />
                  <Info label="书" value={person.books} />
                  <Info label="运动" value={person.sports} />
                  <Info label="来自" value={person.location} />
                  <Info label="近况" value={person.lastSignal} />
                </dl>
                <div className="mt-3 rounded-md border border-[#dce5de] bg-white p-3">
                  <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[#7a8a82]">
                    下一步
                  </p>
                  <p className="mt-1 text-sm font-medium text-[#20342b]">
                    {nextActionsByPerson[person.id] || "补一条最近互动"}
                  </p>
                </div>
              </article>
              );
            })}
          </div>
        ) : (
          <EmptyState
            icon={<Users size={19} />}
            title="这个分组还没有朋友"
            body="先记录一条带分组语境的近况，确认 AI 建议后就会出现在这里。"
          />
        )}
      </section>
    </div>
  );
}

function GroupsView({
  groups,
  newGroupColor,
  newGroupDescription,
  newGroupLabel,
  people,
  onCreateGroup,
  onDeleteGroup,
  onNewGroupColorChange,
  onNewGroupDescriptionChange,
  onNewGroupLabelChange,
  onUpdateGroup,
}: {
  groups: DashboardData["groups"];
  newGroupColor: string;
  newGroupDescription: string;
  newGroupLabel: string;
  people: DashboardData["people"];
  onCreateGroup: (event: FormEvent<HTMLFormElement>) => void;
  onDeleteGroup: (groupId: string, event: FormEvent<HTMLFormElement>) => void;
  onNewGroupColorChange: (value: string) => void;
  onNewGroupDescriptionChange: (value: string) => void;
  onNewGroupLabelChange: (value: string) => void;
  onUpdateGroup: (groupId: string, event: FormEvent<HTMLFormElement>) => void;
}) {
  return (
    <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_340px]">
      <section className="rounded-xl border border-[#dfd3c0] bg-[#fffaf2] p-4 shadow-[0_1px_2px_rgba(48,38,24,0.04)]">
        <div className="flex flex-col gap-2 border-b border-[#e6dccb] pb-3 md:flex-row md:items-center md:justify-between">
          <div>
            <h3 className="text-base font-semibold text-[#17130f]">分组编辑</h3>
            <p className="mt-1 max-w-2xl text-sm leading-6 text-[#6c6256]">
              给不同圈子留清楚的边界。一个朋友可以在多个分组里，比如同学、室友、项目队友、实习同事。
            </p>
          </div>
          <span className="rounded-full border border-[#dfd3c0] bg-[#fbf8f1] px-3 py-1.5 text-xs text-[#6c6256]">
            {groups.length} 个分组
          </span>
        </div>

        <form onSubmit={onCreateGroup} className="mt-4 grid gap-3 md:grid-cols-[1fr_1fr_auto_auto]">
          <label className="text-xs font-medium text-[#6c6256]">
            分组名称
            <input
              value={newGroupLabel}
              onChange={(event) => onNewGroupLabelChange(event.target.value)}
              className="mt-1 w-full rounded-md border border-[#dfd3c0] bg-white px-3 py-2 text-sm outline-none focus:border-[#17130f]"
              placeholder="比如：室友、文学社、实习"
            />
          </label>
          <label className="text-xs font-medium text-[#6c6256]">
            这个圈子怎么认识的
            <input
              value={newGroupDescription}
              onChange={(event) => onNewGroupDescriptionChange(event.target.value)}
              className="mt-1 w-full rounded-md border border-[#dfd3c0] bg-white px-3 py-2 text-sm outline-none focus:border-[#17130f]"
              placeholder="一句话就够，方便以后想起来"
            />
          </label>
          <label className="text-xs font-medium text-[#6c6256]">
            颜色
            <input
              value={newGroupColor}
              onChange={(event) => onNewGroupColorChange(event.target.value)}
              type="color"
              className="mt-1 h-10 w-full rounded-md border border-[#dfd3c0] bg-white p-1"
            />
          </label>
          <Button type="submit" variant="primary" className="self-end">
            <UserPlus size={15} />
            新建分组
          </Button>
        </form>

        <div className="mt-4 grid gap-3 xl:grid-cols-2">
          {groups.map((group) => (
            <article key={group.id} className="rounded-lg border border-[#e6dccb] bg-[#fbf8f1] p-3">
              <form onSubmit={(event) => onUpdateGroup(group.id, event)} className="grid gap-2 md:grid-cols-[1fr_auto_auto]">
                <label className="min-w-0 text-xs font-medium text-[#6c6256]">
                  名称
                  <input
                    name="label"
                    defaultValue={group.label}
                    className="mt-1 w-full rounded-md border border-[#dfd3c0] bg-white px-3 py-2 text-sm outline-none focus:border-[#17130f]"
                  />
                </label>
                <label className="text-xs font-medium text-[#6c6256]">
                  颜色
                  <input
                    name="color"
                    defaultValue={group.color}
                    type="color"
                    className="mt-1 h-10 w-16 rounded-md border border-[#dfd3c0] bg-white p-1"
                  />
                </label>
                <Button type="submit" className="self-end">
                  <Check size={15} />
                  保存
                </Button>
                <label className="md:col-span-3 text-xs font-medium text-[#6c6256]">
                  描述
                  <input
                    name="description"
                    defaultValue={group.description}
                    className="mt-1 w-full rounded-md border border-[#dfd3c0] bg-white px-3 py-2 text-sm outline-none focus:border-[#17130f]"
                  />
                </label>
              </form>
              <form
                onSubmit={(event) => onDeleteGroup(group.id, event)}
                className="mt-3 flex flex-wrap items-center gap-2 border-t border-[#e6dccb] pt-3"
              >
                <span
                  className="h-2.5 w-2.5 rounded-full"
                  style={{ backgroundColor: group.color }}
                />
                <span className="text-xs text-[#6c6256]">{group.memberCount} 位朋友</span>
                <select
                  name="mergeInto"
                  className="ml-auto rounded-md border border-[#dfd3c0] bg-white px-2 py-1.5 text-xs text-[#6c6256]"
                  defaultValue=""
                  aria-label={`Merge target for ${group.label}`}
                >
                  <option value="">只删除分组</option>
                  {groups
                    .filter((candidate) => candidate.id !== group.id)
                    .map((candidate) => (
                      <option key={candidate.id} value={candidate.id}>
                        合并到 {candidate.label}
                      </option>
                    ))}
                </select>
                <Button type="submit" variant="secondary">
                  <Trash2 size={15} />
                  删除
                </Button>
              </form>
            </article>
          ))}
        </div>
      </section>

      <section className="rounded-xl border border-[#dfd3c0] bg-white p-4 shadow-[0_1px_2px_rgba(48,38,24,0.04)]">
        <h3 className="text-sm font-semibold text-[#17130f]">分组里都有谁</h3>
        <div className="mt-4 space-y-3">
          {groups.map((group) => {
            const members = people.filter((person) => person.groupIds.includes(group.id));
            return (
              <div key={group.id} className="rounded-lg border border-[#e6dccb] bg-[#fffaf2] p-3">
                <div className="flex items-center justify-between gap-3">
                  <span className="flex min-w-0 items-center gap-2 text-sm font-medium text-[#17130f]">
                    <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: group.color }} />
                    <span className="truncate">{group.label}</span>
                  </span>
                  <span className="text-xs text-[#756d63]">{members.length} 人</span>
                </div>
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {members.length ? (
                    members.map((member) => (
                      <span key={member.id} className="rounded-full border border-[#dfd3c0] bg-white px-2.5 py-1 text-xs text-[#6c6256]">
                        {member.displayName}
                      </span>
                    ))
                  ) : (
                    <span className="text-xs text-[#9a8d7c]">还没有朋友在这个分组里。</span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </section>
    </div>
  );
}

function PersonDetailPanel({
  gifts,
  groups,
  person,
  pendingUpdates,
  relationshipGraph,
  score,
  onAddPersonToGroup,
  onRemovePersonFromGroup,
}: {
  gifts: DashboardData["gifts"];
  groups: DashboardData["groups"];
  person: DashboardData["people"][number];
  pendingUpdates: DashboardData["pendingUpdates"];
  relationshipGraph: DashboardData["relationshipGraph"];
  score?: DashboardData["relationshipScores"][number];
  onAddPersonToGroup: (personId: string, groupId: string) => void;
  onRemovePersonFromGroup: (personId: string, groupId: string) => void;
}) {
  const firstName = person.displayName.split(" ")[0] || person.displayName;
  const closenessLevel = person.manualClosenessLevel ?? scoreTotalToCloseness(score?.total);
  const sourceMemories = pendingUpdates
    .filter(
      (update) =>
        update.personName === person.displayName ||
        update.summary.includes(person.displayName) ||
        update.summary.includes(firstName),
    )
    .slice(0, 3);
  const graphEdges = relationshipGraph.edges
    .filter((edge) => edge.source === person.id || edge.target === person.id)
    .slice(0, 3);
  const giftIdeas = gifts
    .filter((gift) => gift.personName === person.displayName)
    .slice(0, 2);
  const profileBlocks = [
    {
      title: "生活",
      icon: Coffee,
      items: [
        ["所在地", person.location],
        ["生活习惯", person.lifeNotes],
        ["旅行想法", person.travel],
        ["沟通方式", person.communicationStyle],
      ],
    },
    {
      title: "学习 / 事业",
      icon: Target,
      items: [
        ["学习压力", person.studyNotes],
        ["事业线索", person.careerNotes],
        ["最近信号", person.lastSignal],
      ],
    },
    {
      title: "情感与边界",
      icon: Heart,
      items: [
        ["关系线索", person.relationshipNotes],
        ["不喜欢", person.dislikedThings],
        ["忌口", person.dietaryRestrictions],
      ],
    },
    {
      title: "口味与兴趣",
      icon: Star,
      items: [
        ["喜欢的食物", person.favoriteFoods],
        ["喜欢的东西", person.favoriteThings],
        ["兴趣", person.interests],
        ["音乐影视", person.musicAndMedia],
      ],
    },
    {
      title: "书、游戏、运动",
      icon: Gamepad2,
      items: [
        ["游戏", person.games],
        ["玩多久", person.gameTime],
        ["书", person.books],
        ["运动", person.sports],
      ],
    },
    {
      title: "人格标签",
      icon: BookOpen,
      items: [
        ["生日", person.birthday],
        ["星座", person.zodiacSign],
        ["MBTI", person.mbti],
        ["标签", person.profileTags],
      ],
    },
  ];

  return (
    <section className="space-y-4 rounded-xl border border-[#dfd3c0] bg-[#fffaf2] p-4 shadow-[0_1px_2px_rgba(48,38,24,0.04)] md:p-5">
      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_340px]">
        <div className="rounded-lg border border-[#e6dccb] bg-white p-4">
          <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
            <div className="flex min-w-0 gap-4">
              <div className="grid h-16 w-16 shrink-0 place-items-center rounded-xl bg-[#17130f] text-xl font-semibold text-white">
                {person.initials}
              </div>
              <div className="min-w-0">
                <p className="font-mono text-xs uppercase tracking-[0.16em] text-[#9a8d7c]">
                  朋友档案
                </p>
                <h3 className="mt-1 text-3xl font-semibold tracking-normal text-[#17130f]">
                  {person.displayName}
                </h3>
                <p className="mt-2 text-sm leading-6 text-[#6c6256]">
                  {score?.explanation || "这个人的资料还在补全中。"}
                </p>
              </div>
            </div>
            <span className="w-fit rounded-full border border-[#dfd3c0] bg-[#fffaf2] px-3 py-1.5 text-xs text-[#6c6256]">
              {person.relationLabel}
            </span>
          </div>

          <div className="mt-4 flex flex-wrap gap-2">
            {person.groupIds.map((groupId) => (
              <button
                key={groupId}
                type="button"
                onClick={() => onRemovePersonFromGroup(person.id, groupId)}
                className="rounded-full border border-[#dfd3c0] bg-[#fbf8f1] px-3 py-1.5 text-xs text-[#6c6256]"
              >
                {groupLabel(groups, groupId)} ×
              </button>
            ))}
          </div>
          <label className="mt-4 block max-w-sm text-xs font-medium text-[#6c6256]">
            加入分组
            <select
              className="mt-1 w-full rounded-md border border-[#dfd3c0] bg-white px-3 py-2 text-sm"
              defaultValue=""
              onChange={(event) => {
                onAddPersonToGroup(person.id, event.target.value);
                event.currentTarget.value = "";
              }}
            >
              <option value="">选择一个分组...</option>
              {groups
                .filter((group) => !person.groupIds.includes(group.id))
                .map((group) => (
                  <option key={group.id} value={group.id}>
                    {group.label}
                  </option>
                ))}
            </select>
          </label>
        </div>

        <aside className="rounded-lg border border-[#e6dccb] bg-white p-4">
          <div className="flex items-center justify-between gap-3">
            <div>
              <h4 className="text-sm font-semibold text-[#17130f]">亲近度</h4>
              <p className="mt-1 text-xs text-[#756d63]">
                手动维护，AI 只提供来源线索。
              </p>
            </div>
            <span className="rounded-full border border-[#dfd3c0] bg-[#fffaf2] px-2.5 py-1 text-xs text-[#6c6256]">
              {closenessLevel}/6
            </span>
          </div>
          <ClosenessRangeBar level={closenessLevel} />
          {person.closenessSignals?.length ? (
            <div className="mt-4 space-y-2">
              {person.closenessSignals.slice(0, 3).map((signal) => (
                <p key={signal} className="rounded-md bg-[#fbf8f1] px-3 py-2 text-xs leading-5 text-[#6c6256]">
                  {signal}
                </p>
              ))}
            </div>
          ) : null}
          {score ? (
            <div className="mt-4 border-t border-[#efe5d6] pt-4">
              <div className="flex items-center justify-between text-xs text-[#756d63]">
                <span>AI 维护线索</span>
                <span className="font-semibold text-[#176b4d]">{score.total}/100</span>
              </div>
              <p className="mt-2 text-sm leading-6 text-[#5f564b]">
                {score.recommendation}
              </p>
            </div>
          ) : null}
        </aside>
      </div>

      <section className="rounded-lg border border-[#e6dccb] bg-white p-4">
        <div className="flex items-center justify-between gap-3 border-b border-[#efe5d6] pb-3">
          <h4 className="text-sm font-semibold text-[#17130f]">精选档案</h4>
          <span className="text-xs text-[#8a7c6b]">用户可读字段</span>
        </div>
        <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {profileBlocks.map((block) => {
            const Icon = block.icon;
            return (
              <article
                key={block.title}
                className="rounded-lg border border-[#efe5d6] bg-[#fffaf2] p-4"
              >
                <div className="flex items-center justify-between">
                  <h4 className="flex items-center gap-2 text-sm font-semibold text-[#17130f]">
                    <Icon size={16} className="text-[#176b4d]" />
                    {block.title}
                  </h4>
                  <span className="font-mono text-[11px] text-[#a79a87]">
                    {block.items.filter(([, value]) => isFilledProfileValue(value)).length}/
                    {block.items.length}
                  </span>
                </div>
                <dl className="mt-3 space-y-3">
                  {block.items.map(([label, value]) => (
                    <div key={label}>
                      <dt className="text-[11px] text-[#9a8d7c]">{label}</dt>
                      <dd className="mt-1 text-sm leading-6 text-[#3a332c]">
                        {isFilledProfileValue(value) ? value : "还没记"}
                      </dd>
                    </div>
                  ))}
                </dl>
              </article>
            );
          })}
        </div>
      </section>

      <div className="grid gap-3 lg:grid-cols-3">
        <article className="rounded-lg border border-[#e6dccb] bg-white p-4">
          <h4 className="text-sm font-semibold text-[#17130f]">来源记忆</h4>
          <div className="mt-3 space-y-2">
            {sourceMemories.length ? (
              sourceMemories.map((memory) => (
                <div key={memory.id} className="rounded-md bg-[#fbf8f1] p-3">
                  <p className="text-sm leading-6 text-[#3a332c]">{memory.summary}</p>
                  <p className="mt-1 text-xs text-[#8a7c6b]">
                    {memory.createdLabel} · {memory.evidence}
                  </p>
                </div>
              ))
            ) : (
              <p className="text-sm leading-6 text-[#756d63]">
                暂时没有可展示的来源记忆。确认新建议后，这里会补上证据。
              </p>
            )}
          </div>
        </article>

        <article className="rounded-lg border border-[#e6dccb] bg-white p-4">
          <div className="flex items-center justify-between gap-3">
            <h4 className="text-sm font-semibold text-[#17130f]">关系星图摘要</h4>
            <Network size={16} className="text-[#176b4d]" />
          </div>
          <p className="mt-2 text-sm leading-6 text-[#756d63]">
            批准入库后，AI 会从来源明确的记忆自动整理星图。
          </p>
          <div className="mt-3 space-y-2">
            {graphEdges.length ? (
              graphEdges.map((edge) => (
                <div key={edge.id} className="rounded-md bg-[#fbf8f1] p-3 text-sm text-[#3a332c]">
                  {edge.label} · 强度 {edge.strength}/5
                </div>
              ))
            ) : (
              <p className="rounded-md bg-[#fbf8f1] p-3 text-sm text-[#756d63]">
                还没有来源支持的关系边。
              </p>
            )}
          </div>
          <details className="mt-3 rounded-md border border-[#efe5d6] bg-[#fffaf2] p-3 text-xs text-[#6c6256]">
            <summary className="cursor-pointer font-medium text-[#17130f]">
              手动补充关系
            </summary>
            <p className="mt-2 leading-5">
              仅在 AI 漏掉明确关系时使用。常规情况下，关系边应来自已确认记忆。
            </p>
          </details>
        </article>

        <article className="rounded-lg border border-[#e6dccb] bg-white p-4">
          <h4 className="text-sm font-semibold text-[#17130f]">礼物建议</h4>
          <div className="mt-3 space-y-2">
            {giftIdeas.length ? (
              giftIdeas.map((gift) => (
                <div key={gift.id} className="rounded-md bg-[#fbf8f1] p-3">
                  <div className="flex items-center justify-between gap-3">
                    <p className="text-sm font-medium text-[#3a332c]">{gift.title}</p>
                    <span className="text-xs font-medium text-[#176b4d]">{gift.priceBand}</span>
                  </div>
                  <p className="mt-1 text-xs leading-5 text-[#756d63]">{gift.rationale}</p>
                </div>
              ))
            ) : (
              <p className="text-sm leading-6 text-[#756d63]">
                还没有足够来源生成礼物建议。
              </p>
            )}
          </div>
        </article>
      </div>

      <details className="rounded-lg border border-[#e6dccb] bg-white p-4">
        <summary className="cursor-pointer text-sm font-semibold text-[#17130f]">
          AI 分类规则
        </summary>
        <p className="mt-2 text-sm leading-6 text-[#6c6256]">
          分类档案 Schema 只用于告诉 AI 和数据库：哪些记忆应进入生日、偏好、边界、学习、事业、礼物等字段。它不是档案页正文，档案页只展示整理后的可读信息。
        </p>
        <p className="mt-2 text-xs leading-5 text-[#8a7c6b]">
          当前标签：{person.profileTags || "还没有标签"}
        </p>
      </details>
    </section>
  );
}

function scoreTotalToCloseness(total?: number): number {
  if (!total) return 3;
  return Math.min(6, Math.max(1, Math.round(total / 18)));
}

function ClosenessRangeBar({ level }: { level: number }) {
  const clampedLevel = Math.min(6, Math.max(1, Math.round(level)));
  const markerPosition = ((6 - clampedLevel) / 5) * 100;

  return (
    <div className="mt-4" aria-label={`亲近度 ${clampedLevel}/6`}>
      <div className="mb-2 flex items-center justify-between text-xs text-[#756d63]">
        <span>亲密</span>
        <span>生疏</span>
      </div>
      <div className="relative h-3 rounded-full bg-gradient-to-r from-[#176b4d] via-[#d9c987] to-[#d8d0c4]">
        <span
          className="absolute top-1/2 h-5 w-5 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white bg-[#17130f] shadow-[0_3px_10px_rgba(23,19,15,0.24)]"
          style={{ left: `${markerPosition}%` }}
        />
      </div>
      <div className="mt-2 flex items-center justify-between text-[11px] text-[#9a8d7c]">
        <span>6</span>
        <span>1</span>
      </div>
    </div>
  );
}

function ScoreMeter({ score }: { score: DashboardData["relationshipScores"][number] }) {
  const parts = [
    ["新鲜度", score.freshness],
    ["资料", score.profileDepth],
    ["节点", score.milestoneCoverage],
    ["互动", score.interactionWarmth],
    ["边界", score.boundaryCare],
    ["生活", score.lifeContext],
    ["学习事业", score.studyCareer],
    ["情感", score.emotionalContext],
    ["口味", score.tasteMap],
    ["游戏文化", score.playCulture],
  ] as const;

  return (
    <div className="mt-4 rounded-md border border-[#dce5de] bg-white p-3">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[#7a8a82]">
            AI 维护线索
          </p>
          <p className="mt-1 text-xs leading-5 text-[#68766f]">{score.explanation}</p>
        </div>
        <div className="text-right">
          <p className="text-2xl font-semibold text-[#184f3c]">{score.total}</p>
          <p className="text-[11px] text-[#7a8a82]">/100</p>
        </div>
      </div>
      <div className="mt-3 grid gap-1.5">
        {parts.map(([label, value]) => (
          <div key={label} className="grid grid-cols-[82px_1fr_30px] items-center gap-2 text-[11px]">
            <span className="text-[#68766f]">{label}</span>
            <span className="h-1.5 rounded-full bg-[#edf2ee]">
              <span
                className="block h-1.5 rounded-full bg-[#184f3c]"
                style={{ width: `${value}%` }}
              />
            </span>
            <span className="text-right font-semibold text-[#184f3c]">{value}</span>
          </div>
        ))}
      </div>
      <p className="mt-3 text-xs leading-5 text-[#52625b]">{score.recommendation}</p>
    </div>
  );
}

function CalendarView({
  events,
  groups,
  people,
}: {
  events: DashboardData["calendarEvents"];
  groups: DashboardData["groups"];
  people: DashboardData["people"];
}) {
  const [typeFilter, setTypeFilter] = useState<string>("all");
  const [groupFilter, setGroupFilter] = useState<string>("all");
  const firstEventDate = events[0] ? new Date(events[0].date) : new Date();
  const [visibleMonth, setVisibleMonth] = useState(
    new Date(Date.UTC(firstEventDate.getUTCFullYear(), firstEventDate.getUTCMonth(), 1)),
  );
  const peopleByGroup = useMemo(() => {
    const map = new Map<string, Set<string>>();
    for (const group of groups) {
      map.set(
        group.id,
        new Set(
          people
            .filter((person) => person.groupIds.includes(group.id))
            .map((person) => person.displayName),
        ),
      );
    }
    return map;
  }, [groups, people]);
  const filteredEvents = events.filter((event) => {
    if (typeFilter !== "all" && event.type !== typeFilter) return false;
    if (groupFilter !== "all") {
      const peopleInGroup = peopleByGroup.get(groupFilter);
      if (peopleInGroup && !peopleInGroup.has(event.personName)) return false;
    }
    return true;
  });
  const monthCells = buildMonthCells(visibleMonth, filteredEvents);
  const monthTitle = visibleMonth.toLocaleDateString("zh-CN", {
    month: "long",
    timeZone: "UTC",
    year: "numeric",
  });
  const eventTypeCounts = [
    "birthday",
    "reminder",
    "gift",
    "life_event",
    "ai_suggestion",
  ].map((type) => ({
    count: filteredEvents.filter((event) => event.type === type).length,
    label: calendarEventTypeLabel(type),
    type,
  }));
  const featuredEvents = filteredEvents.slice(0, 4);

  return (
    <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_340px]">
      <section className="overflow-hidden rounded-xl border border-[#dfd3c0] bg-[#fffaf2] shadow-[0_1px_2px_rgba(48,38,24,0.04)]">
        <div className="border-b border-[#dfd3c0] bg-[#fbf4e8] p-5">
          <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
            <div>
              <p className="font-mono text-xs uppercase tracking-[0.16em] text-[#9a8d7c]">
                关系日历
              </p>
              <h3 className="mt-2 text-3xl font-semibold tracking-normal text-[#17130f]">
                关系日历
              </h3>
              <p className="mt-2 max-w-2xl text-sm leading-6 text-[#6c6256]">
                把生日、提醒、礼物时机、考试、面试、旅行、搬家这些生活节点放到一张月历里看。
              </p>
            </div>
            <div className="grid grid-cols-2 gap-2 text-sm sm:grid-cols-5 md:min-w-[520px]">
              {eventTypeCounts.map((item) => (
                <div key={item.type} className="rounded-lg border border-[#dfd3c0] bg-white px-3 py-2">
                  <p className="text-xs text-[#8a7c6b]">{item.label}</p>
                  <p className="mt-1 text-2xl font-semibold text-[#17130f]">{item.count}</p>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="p-4">
          <div className="flex flex-wrap items-center gap-2">
          <Button
            type="button"
            onClick={() => setVisibleMonth(addMonths(visibleMonth, -1))}
          >
            上个月
          </Button>
          <div className="rounded-full border border-[#dfd3c0] bg-white px-4 py-2 text-sm font-semibold text-[#17130f]">
            {monthTitle}
          </div>
          <Button
            type="button"
            onClick={() => setVisibleMonth(addMonths(visibleMonth, 1))}
          >
            下个月
          </Button>
          <select
            value={typeFilter}
            onChange={(event) => setTypeFilter(event.target.value)}
            className="rounded-md border border-[#dfd3c0] bg-white px-3 py-2 text-sm text-[#6c6256]"
          >
            <option value="all">全部事件</option>
            <option value="birthday">生日</option>
            <option value="reminder">提醒</option>
            <option value="gift">礼物时机</option>
            <option value="ai_suggestion">待确认</option>
            <option value="life_event">生活节点</option>
          </select>
          <select
            value={groupFilter}
            onChange={(event) => setGroupFilter(event.target.value)}
            className="rounded-md border border-[#dfd3c0] bg-white px-3 py-2 text-sm text-[#6c6256]"
          >
            <option value="all">全部分组</option>
            {groups.map((group) => (
              <option key={group.id} value={group.id}>
                {group.label}
              </option>
            ))}
          </select>
          </div>

          <div className="mt-4 grid grid-cols-7 overflow-hidden rounded-xl border border-[#dfd3c0] bg-[#dfd3c0]">
          {["日", "一", "二", "三", "四", "五", "六"].map((day) => (
            <div key={day} className="bg-[#f3eadb] px-2 py-2 text-center text-[11px] font-semibold text-[#756d63]">
              周{day}
            </div>
          ))}
          {monthCells.map((cell) => (
            <div
              key={cell.key}
              className={cn(
                "min-h-[120px] border-t border-[#dfd3c0] bg-[#fffaf2] p-2",
                !cell.inMonth && "bg-[#f6efe3] text-[#a79a87]",
              )}
            >
              <div className="flex items-center justify-between">
                <span className="grid h-6 w-6 place-items-center rounded-full text-xs font-semibold">
                  {cell.day}
                </span>
                {cell.events.length ? (
                  <span className="rounded-full bg-[#17130f] px-1.5 py-0.5 text-[10px] text-white">
                    {cell.events.length}
                  </span>
                ) : null}
              </div>
              <div className="mt-2 space-y-1.5">
                {cell.events.slice(0, 3).map((event) => (
                  <div
                    key={event.id}
                    className={cn(
                      "truncate rounded-md border px-1.5 py-1 text-[11px] shadow-[inset_2px_0_0_currentColor]",
                      calendarEventToneClass(event.type),
                    )}
                    title={`${event.title} · ${event.personName}`}
                  >
                    {event.title}
                  </div>
                ))}
                {cell.events.length > 3 ? (
                  <p className="text-[11px] text-[#8a7c6b]">
                    还有 {cell.events.length - 3} 条
                  </p>
                ) : null}
              </div>
            </div>
          ))}
          </div>
        </div>
      </section>

      <section className="space-y-5">
        <CalendarDensityCard cells={monthCells} />

        <div className="rounded-xl border border-[#dfd3c0] bg-white p-4 shadow-[0_1px_2px_rgba(48,38,24,0.04)]">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-semibold text-[#17130f]">
              最近要留意
            </h3>
            <CalendarDays size={17} className="text-[#176b4d]" />
          </div>
          <div className="mt-4 space-y-3">
            {featuredEvents.map((event, index) => (
              <div key={event.id} className="grid grid-cols-[auto_1fr] gap-3 rounded-lg border border-[#e6dccb] bg-[#fffaf2] p-3">
                <span className="grid h-7 w-7 place-items-center rounded-full bg-[#17130f] font-mono text-xs text-white">
                  {String(index + 1).padStart(2, "0")}
                </span>
                <div className="min-w-0">
                  <div className="flex items-center justify-between gap-3">
                    <p className="min-w-0 truncate text-sm font-semibold text-[#17130f]">{event.title}</p>
                    <span className={cn("shrink-0 rounded-full border px-2 py-1 text-[11px]", calendarEventToneClass(event.type))}>
                      {calendarEventTypeLabel(event.type)}
                    </span>
                  </div>
                  <p className="mt-1 text-xs text-[#756d63]">
                    {event.personName} · {event.dayLabel}
                  </p>
                </div>
              </div>
            ))}
            {!featuredEvents.length ? (
              <EmptyState
                icon={<CalendarDays size={19} />}
                title="暂时没有事件"
                body="换个分组或事件类型试试，也可以先记录生日、考试、旅行和礼物时机。"
              />
            ) : null}
          </div>
        </div>

        <div className="rounded-xl border border-[#dfd3c0] bg-[#17130f] p-4 text-white shadow-[0_1px_2px_rgba(48,38,24,0.08)]">
          <h3 className="text-sm font-semibold">
            时间线
          </h3>
          <div className="mt-4 space-y-3">
            {filteredEvents.slice(0, 10).map((event) => (
              <div key={event.id} className="rounded-lg border border-white/10 bg-white/[0.06] p-3">
                <div className="flex items-center justify-between gap-3">
                  <p className="min-w-0 truncate text-sm font-medium">{event.title}</p>
                  <span className="shrink-0 rounded-full bg-white/10 px-2 py-1 text-[11px] text-[#e8ded0]">
                    {calendarEventTypeLabel(event.type)}
                  </span>
                </div>
                <p className="mt-1 text-xs text-[#c7baa8]">
                  {event.personName} · {event.dayLabel}
                </p>
                <div className="mt-2 h-1.5 rounded-full bg-white/10">
                  <div
                    className="h-1.5 rounded-full bg-[#e6c56c]"
                    style={{ width: `${Math.max(22, event.density * 30)}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}

function CalendarDensityCard({
  cells,
}: {
  cells: ReturnType<typeof buildMonthCells>;
}) {
  const visibleCells = cells.filter((cell) => cell.inMonth).slice(0, 35);

  return (
    <div className="rounded-xl border border-[#dfd3c0] bg-[#111827] p-4 text-white shadow-[0_1px_2px_rgba(48,38,24,0.08)]">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h3 className="text-sm font-semibold">事件热力</h3>
          <p className="mt-1 text-xs text-[#b8c2d4]">看这个月哪几天关系事件更密集。</p>
        </div>
        <div className="flex items-center gap-1 text-[11px] text-[#b8c2d4]">
          <span>少</span>
          {[0, 1, 2, 3].map((level) => (
            <span
              key={level}
              className={cn("h-2.5 w-2.5 rounded-[3px]", densityToneClass(level))}
            />
          ))}
          <span>多</span>
        </div>
      </div>
      <div className="mt-4 grid grid-cols-7 gap-1.5">
        {visibleCells.map((cell) => (
          <span
            key={cell.key}
            title={`${cell.day} 日 · ${cell.events.length} 条事件`}
            className={cn(
              "h-7 rounded-md border border-white/5 transition-transform hover:scale-110",
              densityToneClass(cell.events.length),
            )}
          />
        ))}
      </div>
    </div>
  );
}

function RemindersView({
  dueAt,
  reminders,
  title,
  workload,
  onDueAtChange,
  onSubmit,
  onTitleChange,
}: {
  dueAt: string;
  reminders: DashboardData["reminders"];
  title: string;
  workload: { label: string; count: number }[];
  onDueAtChange: (value: string) => void;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onTitleChange: (value: string) => void;
}) {
  return (
    <div className="grid gap-5 xl:grid-cols-[1fr_320px]">
      <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
        <h3 className="text-sm font-semibold text-[#1d3128]">
          近期提醒
        </h3>
        <div className="mt-4 space-y-2">
          {reminders.map((reminder) => (
            <div
              key={reminder.id}
              className="rounded-md border border-[#e4ebe6] p-3"
            >
              <p className="text-sm font-medium">{reminder.title}</p>
              <p className="mt-1 text-xs text-[#68766f]">
                {reminder.personName} · {reminder.dueLabel}
              </p>
            </div>
          ))}
        </div>
      </section>
      <div className="space-y-5">
        <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
          <h3 className="text-sm font-semibold text-[#1d3128]">
            新建提醒
          </h3>
          <form onSubmit={onSubmit} className="mt-3 space-y-3">
            <label className="block text-xs font-medium text-[#52625b]">
              提醒内容
              <input
                value={title}
                onChange={(event) => onTitleChange(event.target.value)}
                className="mt-1 w-full rounded-md border border-[#dce5de] bg-[#fbfcfb] px-3 py-2 text-sm outline-none focus:border-[#184f3c]"
                placeholder="比如：考试前问候一下 Alex"
              />
            </label>
            <label className="block text-xs font-medium text-[#52625b]">
              时间
              <input
                type="datetime-local"
                value={dueAt}
                onChange={(event) => onDueAtChange(event.target.value)}
                className="mt-1 w-full rounded-md border border-[#dce5de] bg-[#fbfcfb] px-3 py-2 text-sm outline-none focus:border-[#184f3c]"
              />
            </label>
            <Button type="submit" variant="primary" className="w-full">
              <Bell size={15} />
              保存提醒
            </Button>
          </form>
        </section>
        <BarList title="提醒时间" items={workload} />
      </div>
    </div>
  );
}

function GiftIdeasView({ gifts }: { gifts: DashboardData["gifts"] }) {
  const [priceFilter, setPriceFilter] = useState<"all" | "$" | "$$" | "$$$">("all");
  const filteredGifts =
    priceFilter === "all" ? gifts : gifts.filter((gift) => gift.priceBand === priceFilter);

  return (
    <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
      <div className="flex flex-col gap-3 border-b border-[#e3eae5] pb-3 md:flex-row md:items-center md:justify-between">
        <div>
          <h3 className="text-sm font-semibold text-[#1d3128]">礼物灵感</h3>
          <p className="mt-1 text-xs leading-5 text-[#68766f]">
            先选预算，再看为什么适合这个人。礼物建议必须能追溯到偏好、忌口、兴趣或近期生活节点。
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {[
            ["all", "全部价位"],
            ["$", "低预算"],
            ["$$", "中等"],
            ["$$$", "高预算"],
          ].map(([value, label]) => (
            <button
              key={value}
              type="button"
              onClick={() => setPriceFilter(value as "all" | "$" | "$$" | "$$$")}
              className={cn(
                "rounded-full border px-3 py-1.5 text-xs font-medium",
                priceFilter === value
                  ? "border-[#184f3c] bg-[#184f3c] text-white"
                  : "border-[#dce5de] bg-[#fbfcfb] text-[#52625b]",
              )}
            >
              {label}
            </button>
          ))}
          <Gift size={17} className="text-[#184f3c]" />
        </div>
      </div>
      <div className="mt-4 grid gap-3 md:grid-cols-2">
        {filteredGifts.map((gift) => (
          <article
            key={gift.id}
            className="rounded-lg border border-[#e4ebe6] bg-[#fbfcfb] p-4"
          >
            <div className="flex items-start justify-between gap-3">
              <div>
                <h4 className="text-sm font-semibold">{gift.title}</h4>
                <p className="mt-1 text-xs text-[#68766f]">{gift.personName}</p>
              </div>
              <span className="rounded-md bg-[#dcebe3] px-2 py-1 text-xs font-semibold text-[#184f3c]">
                {gift.priceBand}
              </span>
            </div>
            <div className="mt-4 rounded-md border border-[#dce5de] bg-white p-3">
              <p className="text-xs font-semibold uppercase tracking-[0.12em] text-[#7a8a82]">
                为什么适合这个人
              </p>
              <p className="mt-2 text-sm leading-6 text-[#20342b]">
                {gift.rationale}
              </p>
            </div>
          </article>
        ))}
      </div>
      {!filteredGifts.length ? (
        <EmptyState
          icon={<Gift size={19} />}
          title="这个价位暂时没有建议"
          body="换个价位看看，或先在朋友档案里补充兴趣、忌口、喜欢的游戏和最近想买的东西。"
        />
      ) : null}
    </section>
  );
}

function SearchView({
  askResult,
  askSuggestions,
  askText,
  onAskTextChange,
  onSearch,
}: {
  askResult: AskResult | null;
  askSuggestions: string[];
  askText: string;
  onAskTextChange: (value: string) => void;
  onSearch: (event: FormEvent<HTMLFormElement>) => void;
}) {
  return (
    <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
      <h3 className="text-sm font-semibold text-[#1d3128]">
        记忆搜索
      </h3>
      <div className="mt-4 rounded-lg border border-[#dce5de] bg-[#fbfcfb] p-3">
        <form onSubmit={onSearch} className="flex gap-2">
          <input
            value={askText}
            onChange={(event) => onAskTextChange(event.target.value)}
            placeholder="问问你的朋友记忆..."
            className="min-w-0 flex-1 rounded-md border border-[#dce5de] bg-white px-3 py-2 text-sm outline-none focus:border-[#184f3c]"
          />
          <Button type="submit" variant="primary" className="px-3">
            <Send size={15} />
          </Button>
        </form>
        <div className="mt-3 flex flex-wrap gap-2">
          {askSuggestions.map((suggestion) => (
            <button
              key={suggestion}
              type="button"
              onClick={() => onAskTextChange(suggestion)}
              className="rounded-full border border-[#dce5de] bg-white px-3 py-1.5 text-xs font-medium text-[#52625b] transition hover:border-[#b8ccc0] hover:text-[#184f3c]"
            >
              {suggestion}
            </button>
          ))}
        </div>
      </div>
      {askResult ? (
        <div className="mt-4 rounded-lg border border-[#e4ebe6] bg-[#fbfcfb] p-4">
          <p className="text-sm leading-6 text-[#20342b]">{askResult.answer}</p>
          <div className="mt-3 flex flex-wrap gap-2">
            {askResult.citations.map((citation) => (
              <span
                key={`${citation.type}-${citation.id}`}
                className="rounded-full bg-white px-2.5 py-1 text-xs text-[#52625b] ring-1 ring-[#dce5de]"
              >
                {citation.type}: {citation.label}
              </span>
            ))}
          </div>
        </div>
      ) : (
        <EmptyState
          icon={<Search size={19} />}
          title="只从已保存的记忆里回答"
          body="这里不会凭空编故事，只会引用你存过的人物、提醒和记忆。"
        />
      )}
    </section>
  );
}

function RelationshipMapView({
  graph,
  scores,
}: {
  graph: DashboardData["relationshipGraph"];
  scores: DashboardData["relationshipScores"];
}) {
  const topScores = [...scores].sort((first, second) => second.total - first.total).slice(0, 4);
  const sampleNodes = graph.nodes.slice(0, 5);

  return (
    <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_360px]">
      <section className="rounded-xl border border-[#dfd3c0] bg-[#fffaf2] p-4 shadow-[0_1px_2px_rgba(48,38,24,0.04)]">
        <div className="flex flex-col gap-2 border-b border-[#dfd3c0] pb-3 md:flex-row md:items-center md:justify-between">
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.16em] text-[#9a8d7c]">
              3D 关系星图
            </p>
            <h3 className="mt-1 text-2xl font-semibold tracking-normal text-[#17130f]">
              关系星图
            </h3>
            <p className="mt-1 max-w-2xl text-sm leading-6 text-[#6c6256]">
              {graph.me.name} 在中心。关系边由确认记忆自动整理；分组是轨道，亲近度和近期信号只影响展示距离、亮度和连线粗细。
            </p>
          </div>
          <Network size={20} className="text-[#176b4d]" />
        </div>
        <div className="mt-4">
          <RelationshipGalaxy graph={graph} />
        </div>
        <div className="mt-4 rounded-xl border border-[#dfd3c0] bg-white p-4">
          <div className="flex items-center justify-between">
            <h4 className="text-sm font-semibold text-[#17130f]">可读版星图</h4>
            <span className="text-xs text-[#756d63]">WebGL 不可用时也能看</span>
          </div>
          <div className="mt-3 rounded-lg bg-[#f8faf8] p-3">
            <RelationshipSvg graph={graph} />
          </div>
        </div>
      </section>

      <section className="space-y-5">
        <div className="rounded-xl border border-[#dfd3c0] bg-white p-4 shadow-[0_1px_2px_rgba(48,38,24,0.04)]">
          <h3 className="text-sm font-semibold text-[#17130f]">
            星图示例
          </h3>
          <div className="mt-4 rounded-xl border border-[#dfd3c0] bg-[#17130f] p-4 text-white">
            <div className="flex items-center justify-between">
              <span className="grid h-12 w-12 place-items-center rounded-full bg-white text-sm font-semibold text-[#17130f]">
                {graph.me.initials}
              </span>
              <div className="text-right">
                <p className="text-xs text-[#c7baa8]">中心点 Me</p>
                <p className="text-sm font-semibold">{graph.me.name}</p>
              </div>
            </div>
            <div className="mt-4 space-y-2">
              {sampleNodes.map((node) => (
                <div key={node.id} className="flex items-center justify-between rounded-lg border border-white/10 bg-white/[0.06] px-3 py-2">
                  <span className="flex min-w-0 items-center gap-2">
                    <span className="h-2.5 w-2.5 rounded-full bg-[#e6c56c]" />
                    <span className="truncate text-sm">{node.label}</span>
                  </span>
                  <span className="text-xs text-[#c7baa8]">
                    {node.groupLabel} · {node.score}
                  </span>
                </div>
              ))}
            </div>
          </div>
          <div className="mt-4 grid gap-2 text-xs text-[#6c6256]">
            <p>离中心越近，说明最近互动和资料完整度越高。</p>
            <p>星点越亮，说明可引用的关系线索越充分；连线越粗，说明来源支持越明确。</p>
            <p>出现小光环，代表近期有生日、提醒、礼物或待确认建议，仍需确认后入库。</p>
          </div>
          <div className="relative mt-5 h-28">
            <div className="absolute inset-x-6 bottom-0 h-20 rotate-[-2deg] rounded-xl bg-[#d7c6f2]" />
            <div className="absolute inset-x-3 bottom-3 h-20 rotate-[1.5deg] rounded-xl bg-[#b9d8c9]" />
            <div className="absolute inset-x-0 bottom-6 rounded-xl border border-[#dfd3c0] bg-[#fffaf2] p-4 shadow-[0_18px_40px_rgba(48,38,24,0.14)]">
              <p className="text-xs font-semibold text-[#17130f]">确认记忆驱动</p>
              <p className="mt-1 text-xs leading-5 text-[#6c6256]">
                背景是分组轨道，中层是来源支持的关系边，前景才是你下一步该关心的人。
              </p>
            </div>
          </div>
        </div>

        <div className="rounded-xl border border-[#dfd3c0] bg-white p-4 shadow-[0_1px_2px_rgba(48,38,24,0.04)]">
          <h3 className="text-sm font-semibold text-[#17130f]">
            轨道分组
          </h3>
          <div className="mt-4 space-y-3">
            {graph.groups.map((group) => (
              <div key={group.id} className="flex items-center justify-between rounded-md border border-[#e6dccb] bg-[#fffaf2] p-3">
                <span className="flex min-w-0 items-center gap-2 text-sm font-medium text-[#20342b]">
                  <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: group.color }} />
                  <span className="truncate">{group.label}</span>
                </span>
                <span className="text-xs text-[#756d63]">{group.memberCount} 人</span>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-xl border border-[#dfd3c0] bg-white p-4 shadow-[0_1px_2px_rgba(48,38,24,0.04)]">
          <h4 className="text-xs font-semibold uppercase tracking-[0.12em] text-[#8a7c6b]">
            维护评分靠前
          </h4>
          <div className="mt-3 space-y-2">
            {topScores.map((score) => (
              <div key={score.personId} className="rounded-md bg-[#fffaf2] p-3 ring-1 ring-[#e6dccb]">
                <div className="flex items-center justify-between gap-3">
                  <p className="truncate text-sm font-medium text-[#17130f]">{score.personName}</p>
                  <p className="text-sm font-semibold text-[#176b4d]">{score.total}</p>
                </div>
                <p className="mt-1 text-xs leading-5 text-[#6c6256]">
                  {score.recommendation}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}

function FilesView({
  fileStatusCounts,
  files,
  uploadStatus,
  onFileUpload,
}: {
  fileStatusCounts: { label: string; count: number }[];
  files: DashboardData["files"];
  uploadStatus: string;
  onFileUpload: (event: FormEvent<HTMLFormElement>) => void;
}) {
  return (
    <div className="grid gap-5 xl:grid-cols-[1fr_320px]">
      <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
        <h3 className="text-sm font-semibold text-[#1d3128]">
          文件导入
        </h3>
        <div className="mt-4 space-y-3">
          {files.map((file) => (
            <div key={file.id} className="rounded-md border border-[#e4ebe6] p-3">
              <div className="flex items-center justify-between gap-3">
                <p className="truncate text-sm font-medium">{file.filename}</p>
                <span className="text-xs text-[#68766f]">{file.progress}%</span>
              </div>
              <p className="mt-1 text-xs text-[#68766f]">{file.status}</p>
              <div className="mt-3 h-1.5 rounded-full bg-[#e5ece7]">
                <div
                  className="h-1.5 rounded-full bg-[#184f3c]"
                  style={{ width: `${file.progress}%` }}
                />
              </div>
            </div>
          ))}
        </div>
      </section>
      <div className="space-y-5">
        <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
          <h3 className="text-sm font-semibold text-[#1d3128]">
            导入文件
          </h3>
          <form onSubmit={onFileUpload} className="mt-3 space-y-3">
            <input
              name="file"
              type="file"
              className="block w-full text-sm text-[#52625b] file:mr-3 file:rounded-md file:border-0 file:bg-[#184f3c] file:px-3 file:py-2 file:text-sm file:font-medium file:text-white"
            />
            <Button type="submit" variant="primary" className="w-full">
              <Upload size={15} />
              上传文件
            </Button>
          </form>
          <p className="mt-3 text-xs leading-5 text-[#68766f]">{uploadStatus}</p>
        </section>
        <BarList title="导入进度" items={fileStatusCounts} />
      </div>
    </div>
  );
}

function DailyBriefView({
  analytics,
  dashboard,
  onSelectSection,
}: {
  analytics: ReturnType<typeof deriveDashboardAnalytics>;
  dashboard: DashboardData;
  onSelectSection: (section: AppSection) => void;
}) {
  const topReminder = dashboard.reminders[0];
  const topUpdate = dashboard.pendingUpdates[0];
  const topGift = dashboard.gifts[0];

  return (
    <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
      <div className="flex items-center justify-between border-b border-[#e3eae5] pb-3">
        <h3 className="text-sm font-semibold text-[#1d3128]">今日简报</h3>
        <Sparkles size={17} className="text-[#184f3c]" />
      </div>
      <div className="mt-4 grid gap-3 md:grid-cols-3">
        <BriefCard
          title="待确认"
          body={
            topUpdate
              ? `${topUpdate.personName}: ${topUpdate.summary}`
              : "暂时没有 AI 建议。"
          }
          action="打开待确认"
          onClick={() => onSelectSection("inbox")}
        />
        <BriefCard
          title="联系"
          body={
            topReminder
              ? `${topReminder.title} · ${topReminder.dueLabel}`
              : "近期没有提醒。"
          }
          action="打开提醒"
          onClick={() => onSelectSection("reminders")}
        />
        <BriefCard
          title="礼物"
          body={
            topGift
              ? `${topGift.personName}: ${topGift.title}`
              : "暂时没有礼物灵感。"
          }
          action="打开礼物"
          onClick={() => onSelectSection("gifts")}
        />
      </div>
      <div className="mt-4">
        <SparklineChart items={analytics.activityTimeline} />
      </div>
    </section>
  );
}

function AccountSettingsView({
  accountEmail,
  accountName,
  accountPassword,
  authBusy,
  authMode,
  deepSeekApiKey,
  deepSeekBusy,
  deepSeekModel,
  deepSeekSavedKey,
  deepSeekStatus,
  deepSeekThinking,
  hasAuthSecret,
  hasDatabaseUrl,
  hasGoogleAuth,
  hasPasswordAuth,
  isAuthenticated,
  languageMode,
  profileName,
  userEmail,
  userName,
  onAccountEmailChange,
  onAccountNameChange,
  onAccountPasswordChange,
  onAccountSubmit,
  onDeepSeekApiKeyChange,
  onDeepSeekModelChange,
  onDeepSeekThinkingChange,
  onLanguageModeChange,
  onProfileNameChange,
  onProfileSubmit,
  onRemoveDeepSeekSettings,
  onSaveDeepSeekSettings,
  onSetAuthMode,
  onSignOut,
  onTestDeepSeekSettings,
}: {
  accountEmail: string;
  accountName: string;
  accountPassword: string;
  authBusy: boolean;
  authMode: "sign-in" | "register";
  deepSeekApiKey: string;
  deepSeekBusy: boolean;
  deepSeekModel: DeepSeekModel;
  deepSeekSavedKey: string;
  deepSeekStatus: string;
  deepSeekThinking: boolean;
  hasAuthSecret: boolean;
  hasDatabaseUrl: boolean;
  hasGoogleAuth: boolean;
  hasPasswordAuth: boolean;
  isAuthenticated: boolean;
  languageMode: LanguageMode;
  profileName: string;
  userEmail?: string | null;
  userName?: string | null;
  onAccountEmailChange: (value: string) => void;
  onAccountNameChange: (value: string) => void;
  onAccountPasswordChange: (value: string) => void;
  onAccountSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onDeepSeekApiKeyChange: (value: string) => void;
  onDeepSeekModelChange: (value: DeepSeekModel) => void;
  onDeepSeekThinkingChange: (value: boolean) => void;
  onLanguageModeChange: (mode: LanguageMode) => void;
  onProfileNameChange: (value: string) => void;
  onProfileSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onRemoveDeepSeekSettings: () => void;
  onSaveDeepSeekSettings: (event: FormEvent<HTMLFormElement>) => void;
  onSetAuthMode: (mode: "sign-in" | "register") => void;
  onSignOut: () => void;
  onTestDeepSeekSettings: () => void;
}) {
  return (
    <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_360px]">
      <div className="space-y-5">
        <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
          <div className="flex flex-col gap-2 border-b border-[#e3eae5] pb-4 md:flex-row md:items-center md:justify-between">
            <div>
              <h3 className="text-sm font-semibold text-[#1d3128]">账号与同步</h3>
              <p className="mt-1 max-w-2xl text-xs leading-5 text-[#68766f]">
                注册是免费的。登录后，Web 端会保存联系人、记忆、提醒和分组；DeepSeek API key 仍由你自己提供。
              </p>
            </div>
            <span className="rounded-md border border-[#dce5de] bg-[#f7faf7] px-3 py-1.5 text-xs text-[#52625b]">
              {isAuthenticated ? "已登录" : "未登录"}
            </span>
          </div>

          {isAuthenticated ? (
            <div className="mt-4 grid gap-4 md:grid-cols-2">
              <form onSubmit={onProfileSubmit} className="rounded-lg border border-[#dce5de] bg-[#fbfcfb] p-3 md:col-span-2">
                <label className="block text-sm font-medium text-[#20342b]">
                  显示名
                  <input
                    value={profileName}
                    onChange={(event) => onProfileNameChange(event.target.value)}
                    className="mt-2 w-full rounded-md border border-[#dce5de] bg-white px-3 py-2 text-sm outline-none focus:border-[#184f3c]"
                    placeholder={userName || "Me"}
                  />
                </label>
                <Button type="submit" className="mt-3" disabled={authBusy}>
                  保存资料
                </Button>
              </form>
              <InfoCard label="名称" value={profileName || userName || "还没有显示名"} />
              <InfoCard label="邮箱" value={userEmail || "当前会话没有邮箱"} />
              <InfoCard label="工作区" value="私密 Web 管理端" />
              <InfoCard label="同步规则" value="朋友数据跟账号走，API key 留在本机" />
              <div className="md:col-span-2">
                <Button type="button" onClick={onSignOut} disabled={authBusy}>
                  退出登录
                </Button>
              </div>
            </div>
          ) : (
            <form onSubmit={onAccountSubmit} className="mt-4 space-y-4">
              <div className="flex flex-wrap gap-2">
                <Button
                  type="button"
                  variant={authMode === "sign-in" ? "primary" : "secondary"}
                  onClick={() => onSetAuthMode("sign-in")}
                >
                  登录
                </Button>
                <Button
                  type="button"
                  variant={authMode === "register" ? "primary" : "secondary"}
                  onClick={() => onSetAuthMode("register")}
                >
                  免费注册
                </Button>
              </div>

              {authMode === "register" ? (
                <label className="block text-sm font-medium text-[#20342b]">
                  名称
                  <input
                    value={accountName}
                    onChange={(event) => onAccountNameChange(event.target.value)}
                    className="mt-2 w-full rounded-md border border-[#dce5de] bg-[#fbfcfb] px-3 py-2 text-sm outline-none focus:border-[#184f3c]"
                    placeholder="比如：Ethan"
                    autoComplete="name"
                  />
                </label>
              ) : null}

              <label className="block text-sm font-medium text-[#20342b]">
                邮箱
                <input
                  value={accountEmail}
                  onChange={(event) => onAccountEmailChange(event.target.value)}
                  className="mt-2 w-full rounded-md border border-[#dce5de] bg-[#fbfcfb] px-3 py-2 text-sm outline-none focus:border-[#184f3c]"
                  placeholder="you@example.com"
                  autoComplete="email"
                  type="email"
                />
              </label>

              <label className="block text-sm font-medium text-[#20342b]">
                密码
                <input
                  value={accountPassword}
                  onChange={(event) => onAccountPasswordChange(event.target.value)}
                  className="mt-2 w-full rounded-md border border-[#dce5de] bg-[#fbfcfb] px-3 py-2 text-sm outline-none focus:border-[#184f3c]"
                  placeholder="至少 8 个字符"
                  autoComplete={authMode === "register" ? "new-password" : "current-password"}
                  type="password"
                />
              </label>

              <div className="flex flex-wrap items-center gap-3">
                <Button type="submit" variant="primary" disabled={authBusy}>
                  {authMode === "register" ? "注册并登录" : "登录"}
                </Button>
                {!hasPasswordAuth ? (
                  <span className="text-xs leading-5 text-[#a05a2c]">
                    现在不能完成账号操作：{authSetupMessage(hasDatabaseUrl, hasAuthSecret)}
                  </span>
                ) : null}
              </div>
            </form>
          )}
        </section>

        <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
          <div className="flex flex-col gap-2 border-b border-[#e3eae5] pb-4 md:flex-row md:items-center md:justify-between">
            <div>
              <h3 className="text-sm font-semibold text-[#1d3128]">DeepSeek API</h3>
              <p className="mt-1 max-w-2xl text-xs leading-5 text-[#68766f]">
                每个用户填自己的 key。这里仅保存在当前浏览器会话里，Capture 时随请求使用，不写入朋友档案、服务器数据库或持久化本机存储。
              </p>
            </div>
            <a
              href={deepSeekPlatformUrl}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-1 rounded-md border border-[#dce5de] px-3 py-1.5 text-xs font-medium text-[#184f3c]"
            >
              去 DeepSeek 平台 <ArrowUpRight size={13} />
            </a>
          </div>

          <form onSubmit={onSaveDeepSeekSettings} className="mt-4 space-y-4">
            <label className="block text-sm font-medium text-[#20342b]">
              API key
              <input
                value={deepSeekApiKey}
                onChange={(event) => onDeepSeekApiKeyChange(event.target.value)}
                className="mt-2 w-full rounded-md border border-[#dce5de] bg-[#fbfcfb] px-3 py-2 text-sm outline-none focus:border-[#184f3c]"
                placeholder={deepSeekSavedKey ? maskSecret(deepSeekSavedKey) : "sk-..."}
                type="password"
                autoComplete="off"
              />
            </label>

            <div className="grid gap-3 md:grid-cols-2">
              <label className="block text-sm font-medium text-[#20342b]">
                模型
                <select
                  value={deepSeekModel}
                  onChange={(event) => onDeepSeekModelChange(event.target.value as DeepSeekModel)}
                  className="mt-2 w-full rounded-md border border-[#dce5de] bg-[#fbfcfb] px-3 py-2 text-sm outline-none focus:border-[#184f3c]"
                >
                  {deepSeekModels.map((model) => (
                    <option key={model.value} value={model.value}>
                      {model.value}
                    </option>
                  ))}
                </select>
              </label>
              <label className="flex items-center justify-between gap-3 rounded-md border border-[#dce5de] bg-[#fbfcfb] px-3 py-2 text-sm font-medium text-[#20342b]">
                <span>
                  深度思考
                  <span className="mt-0.5 block text-xs font-normal text-[#68766f]">
                    开启后发送 reasoning_effort: high
                  </span>
                </span>
                <input
                  checked={deepSeekThinking}
                  onChange={(event) => onDeepSeekThinkingChange(event.target.checked)}
                  type="checkbox"
                  className="h-4 w-4 accent-[#184f3c]"
                />
              </label>
            </div>

            <div className="grid gap-2 md:grid-cols-2">
              {deepSeekModels.map((model) => (
                <div
                  key={model.value}
                  className={cn(
                    "rounded-md border p-3 text-xs leading-5",
                    deepSeekModel === model.value
                      ? "border-[#184f3c] bg-[#eef6f1] text-[#184f3c]"
                      : "border-[#dce5de] bg-[#fbfcfb] text-[#52625b]",
                  )}
                >
                  <p className="font-semibold">{model.label}</p>
                  <p className="mt-1">{model.detail}</p>
                </div>
              ))}
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <Button type="submit" variant="primary">
                保存 DeepSeek 设置
              </Button>
              <Button type="button" onClick={onTestDeepSeekSettings} disabled={deepSeekBusy}>
                测试连接
              </Button>
              <Button type="button" variant="secondary" onClick={onRemoveDeepSeekSettings}>
                移除 key
              </Button>
              <a
                href={deepSeekDocsUrl}
                target="_blank"
                rel="noreferrer"
                className="text-xs font-medium text-[#184f3c]"
              >
                API 文档
              </a>
            </div>
            <p className="rounded-md border border-[#e4ebe6] bg-[#fbfcfb] px-3 py-2 text-xs leading-5 text-[#52625b]">
              {deepSeekStatus}
            </p>
          </form>
        </section>
      </div>

      <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
        <h3 className="text-sm font-semibold text-[#1d3128]">服务器状态</h3>
        <dl className="mt-4 space-y-3 text-sm">
          <Info label="数据库" value={hasDatabaseUrl ? "已配置 DATABASE_URL" : "缺 DATABASE_URL"} />
          <Info label="登录密钥" value={hasAuthSecret ? "已配置 Auth Secret" : "缺 NEXTAUTH_SECRET / AUTH_SECRET"} />
          <Info label="邮箱密码" value={hasPasswordAuth ? "可以注册登录" : "暂时不能用"} />
          <Info label="Google 登录" value={hasGoogleAuth ? "已配置" : "可选，未配置"} />
          <Info label="DeepSeek key" value={deepSeekSavedKey ? `本次会话已保存 ${maskSecret(deepSeekSavedKey)}` : "由用户自己输入"} />
        </dl>
        <div className="mt-5 rounded-lg border border-[#e4ebe6] bg-[#fbfcfb] p-3 text-xs leading-5 text-[#52625b]">
          <p className="font-semibold text-[#20342b]">现在的结论</p>
          <p className="mt-1">{authSetupMessage(hasDatabaseUrl, hasAuthSecret)}</p>
        </div>
        <div className="mt-5 border-t border-[#e4ebe6] pt-4">
          <div className="flex items-center gap-2">
            <Globe2 size={16} className="text-[#184f3c]" />
            <h4 className="text-sm font-semibold text-[#1d3128]">界面语言</h4>
          </div>
          <div className="mt-3 grid gap-2">
            {[
              ["system", "跟随系统", "自动跟随浏览器语言"],
              ["zh", "中文", "中文会按中文产品的说法来写"],
              ["en", "English", "Use English interface copy"],
            ].map(([mode, label, detail]) => (
              <button
                key={mode}
                type="button"
                onClick={() => onLanguageModeChange(mode as LanguageMode)}
                className={cn(
                  "rounded-md border px-3 py-2 text-left text-sm",
                  languageMode === mode
                    ? "border-[#184f3c] bg-[#eef6f1] text-[#184f3c]"
                    : "border-[#dce5de] bg-[#fbfcfb] text-[#52625b]",
                )}
              >
                <span className="font-medium">{label}</span>
                <span className="mt-0.5 block text-xs opacity-75">{detail}</span>
              </button>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}

function InfoCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-[#dce5de] bg-[#fbfcfb] p-3">
      <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[#7a8a82]">
        {label}
      </p>
      <p className="mt-1 text-sm font-medium text-[#20342b]">{value}</p>
    </div>
  );
}

function ContextRail({
  firstPerson,
  hasGoogleAuth,
  hasPasswordAuth,
  isAuthenticated,
  nextActionsByPerson,
  selectedFile,
  userEmail,
  onSelectSection,
}: {
  firstPerson: DashboardData["people"][number];
  hasGoogleAuth: boolean;
  hasPasswordAuth: boolean;
  isAuthenticated: boolean;
  nextActionsByPerson: Record<string, string>;
  selectedFile?: DashboardData["files"][number];
  userEmail?: string | null;
  onSelectSection: (section: AppSection) => void;
}) {
  return (
    <aside className="space-y-5">
      <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
        <div className="flex items-center gap-3">
          <div className="grid h-14 w-14 place-items-center rounded-full bg-[#dcebe3] text-lg font-semibold text-[#184f3c]">
            {firstPerson.initials}
          </div>
          <div className="min-w-0">
            <h3 className="truncate text-lg font-semibold">
              {firstPerson.displayName}
            </h3>
            <p className="text-sm text-[#68766f]">{firstPerson.relationLabel}</p>
          </div>
        </div>
        <dl className="mt-4 grid grid-cols-2 gap-3 text-sm">
          <Info label="生日" value={firstPerson.birthday} />
          <Info label="忌口" value={firstPerson.dietaryRestrictions} />
          <Info label="爱吃" value={firstPerson.favoriteFoods} />
          <Info label="不喜欢" value={firstPerson.dislikedThings} />
          <Info label="星座" value={firstPerson.zodiacSign} />
          <Info label="MBTI" value={firstPerson.mbti} />
          <Info label="兴趣" value={firstPerson.interests} />
          <Info label="书" value={firstPerson.books} />
          <Info label="运动" value={firstPerson.sports} />
          <Info label="标签" value={firstPerson.profileTags} />
          <Info label="来自" value={firstPerson.location} />
          <Info label="分组" value={firstPerson.groupLabel} />
          <Info label="近况" value={firstPerson.lastSignal} />
        </dl>
        <div className="mt-3 rounded-md border border-[#dce5de] bg-[#fbfcfb] p-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[#7a8a82]">
            下一步
          </p>
          <p className="mt-1 text-sm font-medium text-[#20342b]">
            {nextActionsByPerson[firstPerson.id] || "补一条最近互动"}
          </p>
        </div>
      </section>

      <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-semibold text-[#1d3128]">
            文件导入
          </h3>
          <button
            type="button"
            aria-label="打开文件导入"
            onClick={() => onSelectSection("files")}
            className="text-[#184f3c]"
          >
            <FileUp size={16} />
          </button>
        </div>
        {selectedFile ? (
          <div className="mt-4 rounded-md border border-[#e4ebe6] p-3">
            <p className="truncate text-sm font-medium">{selectedFile.filename}</p>
            <p className="mt-1 text-xs text-[#68766f]">{selectedFile.status}</p>
            <div className="mt-3 h-1.5 rounded-full bg-[#e5ece7]">
              <div
                className="h-1.5 rounded-full bg-[#184f3c]"
                style={{ width: `${selectedFile.progress}%` }}
              />
            </div>
          </div>
        ) : (
          <p className="mt-3 text-xs leading-5 text-[#68766f]">
            还没有导入文件。可以上传聊天记录、照片备注或 PDF，后续再整理成待确认信息。
          </p>
        )}
      </section>

      <section
        id="settings"
        className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]"
      >
        <div className="flex items-center gap-2">
          <Settings size={16} className="text-[#184f3c]" />
          <h3 className="text-sm font-semibold text-[#1d3128]">
            账号和同步
          </h3>
        </div>
        <ul className="mt-3 space-y-2 text-xs leading-5 text-[#617069]">
          <li>账号：{isAuthenticated ? userEmail || "已登录" : "未登录"}</li>
          <li>邮箱密码：{hasPasswordAuth ? "可以使用" : "还缺服务器配置"}</li>
          <li>Google 登录：{hasGoogleAuth ? "已配置" : "未配置，可选"}</li>
          <li>同步：联系人和提醒跟账号走，API key 留在本机</li>
          <li>数据库：Prisma / Postgres</li>
        </ul>
        <Button
          type="button"
          className="mt-3 w-full"
          onClick={() => onSelectSection("settings")}
        >
          打开账号设置
        </Button>
      </section>
    </aside>
  );
}

function CompactPeoplePanel({
  nextActionsByPerson,
  people,
  onSelectSection,
}: {
  nextActionsByPerson: Record<string, string>;
  people: DashboardData["people"];
  onSelectSection: (section: AppSection) => void;
}) {
  return (
    <Panel title="朋友" action="查看全部" onAction={() => onSelectSection("people")}>
      <div className="space-y-3">
        {people.map((person) => (
          <div key={person.id} className="flex items-center gap-3 rounded-md p-2 hover:bg-[#f6f8f5]">
            <div className="grid h-10 w-10 place-items-center rounded-full bg-[#dcebe3] text-sm font-semibold text-[#184f3c]">
              {person.initials}
            </div>
            <div className="min-w-0">
              <p className="truncate text-sm font-medium">{person.displayName}</p>
              <p className="truncate text-xs text-[#68766f]">{person.relationLabel}</p>
              <p className="truncate text-xs text-[#8a9891]">{person.lastSignal}</p>
              <p className="mt-1 truncate text-[11px] font-medium text-[#184f3c]">
                {nextActionsByPerson[person.id] || "补一条最近互动"}
              </p>
            </div>
          </div>
        ))}
      </div>
    </Panel>
  );
}

function CompactRemindersPanel({
  reminders,
  onSelectSection,
}: {
  reminders: DashboardData["reminders"];
  onSelectSection: (section: AppSection) => void;
}) {
  return (
    <Panel
      title="近期"
      action="看日历"
      onAction={() => onSelectSection("calendar")}
    >
      <div className="space-y-2">
        {reminders.map((reminder) => (
          <div key={reminder.id} className="rounded-md border border-[#e4ebe6] p-3">
            <p className="text-sm font-medium">{reminder.title}</p>
            <p className="mt-1 text-xs text-[#68766f]">
              {reminder.personName} · {reminder.dueLabel}
            </p>
          </div>
        ))}
      </div>
    </Panel>
  );
}

function CompactGiftsPanel({
  gifts,
  onSelectSection,
}: {
  gifts: DashboardData["gifts"];
  onSelectSection: (section: AppSection) => void;
}) {
  return (
    <Panel title="礼物灵感" action="查看全部" onAction={() => onSelectSection("gifts")}>
      <div className="space-y-2">
        {gifts.map((gift) => (
          <div key={gift.id} className="grid grid-cols-[1fr_auto] gap-3 rounded-md border border-[#e4ebe6] p-3">
            <div>
              <p className="text-sm font-medium">{gift.title}</p>
              <p className="mt-1 text-xs text-[#68766f]">
                {gift.personName} · {gift.rationale}
              </p>
            </div>
            <span className="text-xs font-medium text-[#184f3c]">
              {gift.priceBand}
            </span>
          </div>
        ))}
      </div>
    </Panel>
  );
}

function RelationshipMapPreview({
  graph,
  onSelectSection,
}: {
  graph: DashboardData["relationshipGraph"];
  onSelectSection: (section: AppSection) => void;
}) {
  return (
    <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-sm font-semibold text-[#1d3128]">
            关系星图预览
          </h3>
          <p className="mt-1 text-xs text-[#68766f]">
            由确认记忆自动整理。
          </p>
        </div>
        <button
          type="button"
          onClick={() => onSelectSection("map")}
          className="text-xs font-medium text-[#184f3c]"
        >
          查看完整星图
        </button>
      </div>
      <div className="mt-5 rounded-lg bg-[#f8faf8] p-4">
        <RelationshipSvg compact graph={graph} />
      </div>
    </section>
  );
}

function RelationshipSvg({
  compact = false,
  graph,
}: {
  compact?: boolean;
  graph: DashboardData["relationshipGraph"];
}) {
  const nodes = graph.nodes.slice(0, compact ? 3 : 6);
  const positions = [
    { x: 18, y: 52 },
    { x: 75, y: 28 },
    { x: 78, y: 76 },
    { x: 32, y: 24 },
    { x: 58, y: 18 },
    { x: 36, y: 78 },
  ];

  return (
    <svg
      role="img"
      aria-label="关系星图"
      viewBox="0 0 100 100"
      className={cn("h-[220px] w-full", compact && "h-[170px]")}
    >
      {nodes.map((person, index) => (
        <line
          key={`${person.id}-edge`}
          x1="50"
          y1="50"
          x2={positions[index].x}
          y2={positions[index].y}
          stroke="#9eb5aa"
          strokeDasharray="2 2"
          strokeWidth="0.7"
        />
      ))}
      <MapSvgNode x={50} y={50} label={graph.me.name} variant="primary" />
      {nodes.map((node, index) => (
        <MapSvgNode
          key={node.id}
          x={positions[index].x}
          y={positions[index].y}
          label={node.label}
        />
      ))}
    </svg>
  );
}

function MapSvgNode({
  label,
  variant = "secondary",
  x,
  y,
}: {
  label: string;
  variant?: "primary" | "secondary";
  x: number;
  y: number;
}) {
  const width = Math.min(31, Math.max(18, label.length * 1.25 + 8));

  return (
    <g transform={`translate(${x - width / 2} ${y - 4})`}>
      <rect
        width={width}
        height="8"
        rx="4"
        fill={variant === "primary" ? "#132821" : "#dcebe3"}
      />
      <text
        x={width / 2}
        y="5.25"
        textAnchor="middle"
        fontSize="3"
        fontWeight="600"
        fill={variant === "primary" ? "#ffffff" : "#184f3c"}
      >
        {label}
      </text>
    </g>
  );
}

function MetricTile({
  helper,
  label,
  value,
}: {
  helper?: string;
  label: string;
  value: number;
}) {
  return (
    <div className="rounded-lg border border-[#e4ebe6] bg-[#fbfcfb] p-3">
      <p className="text-xs text-[#68766f]">{label}</p>
      <p className="mt-2 text-2xl font-semibold tracking-normal text-[#14231c]">
        {value}
      </p>
      {helper ? (
        <p className="mt-2 text-xs leading-5 text-[#68766f]">{helper}</p>
      ) : null}
    </div>
  );
}

function BarList({
  items,
  title,
}: {
  items: { label: string; count: number }[];
  title: string;
}) {
  const max = Math.max(1, ...items.map((item) => item.count));

  return (
    <section className="rounded-lg border border-[#e4ebe6] bg-[#fbfcfb] p-3">
      <h4 className="text-xs font-semibold uppercase tracking-[0.12em] text-[#7a8a82]">
        {title}
      </h4>
      {items.length ? (
        <div className="mt-3 space-y-2">
          {items.map((item) => (
            <div key={item.label}>
              <div className="flex items-center justify-between gap-2 text-xs">
                <span className="truncate text-[#52625b]">{item.label}</span>
                <span className="font-semibold text-[#184f3c]">{item.count}</span>
              </div>
              <div className="mt-1 h-1.5 rounded-full bg-[#e5ece7]">
                <div
                  className="h-1.5 rounded-full bg-[#184f3c]"
                  style={{ width: `${Math.max(8, (item.count / max) * 100)}%` }}
                />
              </div>
            </div>
          ))}
        </div>
      ) : (
        <p className="mt-3 text-xs leading-5 text-[#68766f]">暂时没有数据。</p>
      )}
    </section>
  );
}

function SparklineChart({ items }: { items: { label: string; count: number }[] }) {
  const max = Math.max(1, ...items.map((item) => item.count));
  const points = items
    .map((item, index) => {
      const x = items.length === 1 ? 50 : (index / (items.length - 1)) * 100;
      const y = 84 - (item.count / max) * 60;
      return `${x},${y}`;
    })
    .join(" ");

  return (
    <section className="rounded-lg border border-[#e4ebe6] bg-[#fbfcfb] p-3">
      <div className="flex items-center justify-between">
        <h4 className="text-xs font-semibold uppercase tracking-[0.12em] text-[#7a8a82]">
          互动节奏
        </h4>
        <span className="text-xs text-[#68766f]">最近走势</span>
      </div>
      <svg
        role="img"
        aria-label="互动节奏趋势"
        viewBox="0 0 100 100"
        className="mt-2 h-24 w-full"
      >
        <line x1="0" y1="84" x2="100" y2="84" stroke="#dce5de" />
        <polyline
          points={points}
          fill="none"
          stroke="#184f3c"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth="3"
        />
        {items.map((item, index) => {
          const x = items.length === 1 ? 50 : (index / (items.length - 1)) * 100;
          const y = 84 - (item.count / max) * 60;
          return (
            <circle key={item.label} cx={x} cy={y} r="2.5" fill="#184f3c" />
          );
        })}
      </svg>
      <div className="grid grid-cols-4 gap-2">
        {items.map((item) => (
          <div key={item.label} className="min-w-0 text-center">
            <p className="truncate text-[11px] text-[#68766f]">{item.label}</p>
            <p className="text-xs font-semibold text-[#184f3c]">{item.count}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

function BriefCard({
  action,
  body,
  title,
  onClick,
}: {
  action: string;
  body: string;
  title: string;
  onClick: () => void;
}) {
  return (
    <article className="rounded-lg border border-[#e4ebe6] bg-[#fbfcfb] p-4">
      <h4 className="text-sm font-semibold text-[#1d3128]">{title}</h4>
      <p className="mt-2 min-h-12 text-sm leading-6 text-[#52625b]">{body}</p>
      <button
        type="button"
        onClick={onClick}
        className="mt-3 text-xs font-semibold text-[#184f3c]"
      >
        {action}
      </button>
    </article>
  );
}

function EmptyState({
  body,
  icon,
  title,
}: {
  body: string;
  icon: ReactNode;
  title: string;
}) {
  return (
    <div className="grid min-h-44 place-items-center px-4 py-8 text-center">
      <div>
        <div className="mx-auto grid h-11 w-11 place-items-center rounded-lg bg-[#eef6f1] text-[#184f3c]">
          {icon}
        </div>
        <p className="mt-3 text-sm font-semibold text-[#20342b]">{title}</p>
        <p className="mt-1 max-w-md text-sm leading-6 text-[#68766f]">{body}</p>
      </div>
    </div>
  );
}

function Panel({
  title,
  action,
  children,
  onAction,
}: {
  title: string;
  action: string;
  children: ReactNode;
  onAction?: () => void;
}) {
  return (
    <section className="rounded-lg border border-[#dce5de] bg-white p-4 shadow-[0_1px_2px_rgba(15,30,24,0.03)]">
      <div className="mb-3 flex items-center justify-between">
        <h3 className="text-sm font-semibold text-[#1d3128]">{title}</h3>
        <button
          type="button"
          onClick={onAction}
          className="text-xs font-medium text-[#184f3c]"
        >
          {action}
        </button>
      </div>
      {children}
    </section>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div className="min-w-0 rounded-md bg-[#f7faf7] p-3">
      <dt className="text-xs text-[#68766f]">{label}</dt>
      <dd className="mt-1 truncate text-sm font-medium text-[#17231f]">{value}</dd>
    </div>
  );
}

function isFilledProfileValue(value: string) {
  const normalized = value.trim().toLowerCase();
  return Boolean(
    normalized &&
      normalized !== "not set" &&
      normalized !== "unknown" &&
      normalized !== "none" &&
      normalized !== "未设置",
  );
}

function updateGroupLocally(
  dashboard: DashboardData,
  groupId: string,
  patch: Partial<DashboardData["groups"][number]>,
): DashboardData {
  const previous = dashboard.groups.find((group) => group.id === groupId);
  const nextLabel = patch.label || previous?.label || "朋友";

  return enrichDashboardData({
    ...dashboard,
    groups: dashboard.groups.map((group) =>
      group.id === groupId ? { ...group, ...patch } : group,
    ),
    people: dashboard.people.map((person) =>
      person.groupIds.includes(groupId)
        ? {
            ...person,
            groupLabel: person.groupIds[0] === groupId ? nextLabel : person.groupLabel,
            groupLabels: person.groupIds.map((id) =>
              id === groupId ? nextLabel : groupLabel(dashboard.groups, id),
            ),
          }
        : person,
    ),
  }, dashboard.relationshipGraph.me);
}

function deleteGroupLocally(
  dashboard: DashboardData,
  groupId: string,
  mergeIntoGroupId: string | null,
): DashboardData {
  const targetLabel = mergeIntoGroupId
    ? groupLabel(dashboard.groups, mergeIntoGroupId)
    : "";
  const people = dashboard.people.map((person) => {
    if (!person.groupIds.includes(groupId)) return person;
    const nextGroupIds = person.groupIds.filter((id) => id !== groupId);
    if (mergeIntoGroupId && !nextGroupIds.includes(mergeIntoGroupId)) {
      nextGroupIds.push(mergeIntoGroupId);
    }
    const nextGroupLabels = nextGroupIds.map((id) => groupLabel(dashboard.groups, id));
    return {
      ...person,
      groupIds: nextGroupIds,
      groupLabels: nextGroupLabels,
      groupLabel: nextGroupLabels[0] || targetLabel || "朋友",
    };
  });

  return recountGroups({
    ...dashboard,
    groups: dashboard.groups.filter((group) => group.id !== groupId),
    people,
  });
}

function addPersonToGroupLocally(
  dashboard: DashboardData,
  personId: string,
  groupId: string,
): DashboardData {
  const label = groupLabel(dashboard.groups, groupId);
  const people = dashboard.people.map((person) => {
    if (person.id !== personId || person.groupIds.includes(groupId)) return person;
    return {
      ...person,
      groupIds: [...person.groupIds, groupId],
      groupLabels: [...person.groupLabels, label],
      groupLabel: person.groupLabel || label,
    };
  });
  return recountGroups({ ...dashboard, people });
}

function removePersonFromGroupLocally(
  dashboard: DashboardData,
  personId: string,
  groupId: string,
): DashboardData {
  const people = dashboard.people.map((person) => {
    if (person.id !== personId) return person;
    const groupIds = person.groupIds.filter((id) => id !== groupId);
    const groupLabels = groupIds.map((id) => groupLabel(dashboard.groups, id));
    return {
      ...person,
      groupIds,
      groupLabels,
      groupLabel: groupLabels[0] || "朋友",
    };
  });
  return recountGroups({ ...dashboard, people });
}

function recountGroups(dashboard: DashboardData): DashboardData {
  const recounted = {
    ...dashboard,
    groups: dashboard.groups.map((group) => ({
      ...group,
      memberCount: dashboard.people.filter((person) =>
        person.groupIds.includes(group.id),
      ).length,
    })),
  };

  return enrichDashboardData(recounted, recounted.relationshipGraph.me);
}

function groupLabel(groups: DashboardData["groups"], groupId: string) {
  return groups.find((group) => group.id === groupId)?.label || "朋友";
}

function addMonths(date: Date, months: number) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + months, 1));
}

function buildMonthCells(
  visibleMonth: Date,
  events: DashboardData["calendarEvents"],
) {
  const first = new Date(Date.UTC(visibleMonth.getUTCFullYear(), visibleMonth.getUTCMonth(), 1));
  const start = new Date(first);
  start.setUTCDate(first.getUTCDate() - first.getUTCDay());
  const eventMap = new Map<string, DashboardData["calendarEvents"]>();

  for (const event of events) {
    const date = new Date(event.date);
    const key = dateKey(date);
    eventMap.set(key, [...(eventMap.get(key) || []), event]);
  }

  return Array.from({ length: 42 }, (_, index) => {
    const date = new Date(start);
    date.setUTCDate(start.getUTCDate() + index);
    const key = dateKey(date);

    return {
      key,
      day: date.getUTCDate(),
      inMonth: date.getUTCMonth() === visibleMonth.getUTCMonth(),
      events: eventMap.get(key) || [],
    };
  });
}

function dateKey(date: Date) {
  return date.toISOString().slice(0, 10);
}

function calendarEventTypeLabel(type: DashboardData["calendarEvents"][number]["type"] | string) {
  const labels: Record<string, string> = {
    ai_suggestion: "待确认",
    birthday: "生日",
    gift: "礼物",
    life_event: "生活节点",
    reminder: "提醒",
  };

  return labels[type] || "事件";
}

function calendarEventToneClass(type: DashboardData["calendarEvents"][number]["type"] | string) {
  const tones: Record<string, string> = {
    ai_suggestion: "border-[#d9c776] bg-[#fff8d8] text-[#75681e]",
    birthday: "border-[#e5b7c9] bg-[#fff0f5] text-[#7b3f5c]",
    gift: "border-[#e2c199] bg-[#fff3df] text-[#8f5a33]",
    life_event: "border-[#adc0dc] bg-[#eef4ff] text-[#365d8c]",
    reminder: "border-[#a8cdbf] bg-[#eff8f3] text-[#256f56]",
  };

  return tones[type] || "border-[#dfd3c0] bg-white text-[#6c6256]";
}

function densityToneClass(count: number) {
  if (count >= 3) return "bg-[#38bdf8]";
  if (count === 2) return "bg-[#0284c7]";
  if (count === 1) return "bg-[#1e3a5f]";
  return "bg-[#1f2937]";
}

function getInitialNavigation(): {
  section: AppSection;
  group: string | null;
} {
  if (typeof window === "undefined") {
    return { section: "inbox", group: null };
  }

  const params = new URLSearchParams(window.location.search);
  const group = params.get("group");

  return {
    section: group ? "people" : parseAppSection(params.get("section")),
    group,
  };
}

function syncUrl(section: AppSection, group: string | null) {
  if (typeof window === "undefined") return;

  const url = new URL(window.location.href);
  url.searchParams.set("section", section);

  if (group) {
    url.searchParams.set("group", group);
  } else {
    url.searchParams.delete("group");
  }

  window.history.pushState({}, "", `${url.pathname}${url.search}${url.hash}`);
}

function isAskResult(value: unknown): value is AskResult {
  return (
    typeof value === "object" &&
    value !== null &&
    "answer" in value &&
    "citations" in value &&
    Array.isArray((value as { citations: unknown }).citations)
  );
}

function getErrorMessage(value: unknown): string | null {
  if (
    typeof value === "object" &&
    value !== null &&
    "error" in value &&
    typeof (value as { error?: unknown }).error === "string"
  ) {
    return (value as { error: string }).error;
  }

  return null;
}

function resolveLanguageMode(mode: LanguageMode): UiLanguage {
  if (mode === "zh" || mode === "en") return mode;
  if (typeof window === "undefined") return "zh";
  return window.navigator.language.toLowerCase().startsWith("en") ? "en" : "zh";
}

function parseLanguageMode(value: string | null): LanguageMode | null {
  return value === "system" || value === "zh" || value === "en" ? value : null;
}

function readDeepSeekSettings():
  | { apiKey: string; model: DeepSeekModel; thinkingEnabled: boolean }
  | null {
  try {
    const raw = localStorage.getItem(deepSeekStorageKey);
    const parsed = raw ? JSON.parse(raw) as {
      apiKey?: unknown;
      model?: unknown;
      thinkingEnabled?: unknown;
      hasSessionKey?: unknown;
    } : {};
    const model =
      parsed.model === "deepseek-v4-pro" || parsed.model === "deepseek-v4-flash"
        ? parsed.model
        : "deepseek-v4-flash";
    const thinkingEnabled = Boolean(parsed.thinkingEnabled);
    const legacyKey = typeof parsed.apiKey === "string" ? parsed.apiKey.trim() : "";
    const sessionKey = sessionStorage.getItem(deepSeekSessionKey)?.trim() || "";

    if (legacyKey) {
      sessionStorage.setItem(deepSeekSessionKey, legacyKey);
      localStorage.setItem(
        deepSeekStorageKey,
        JSON.stringify({ model, thinkingEnabled, hasSessionKey: true }),
      );
      return {
        apiKey: legacyKey,
        model,
        thinkingEnabled,
      };
    }

    if (!sessionKey) return null;

    return {
      apiKey: sessionKey,
      model,
      thinkingEnabled,
    };
  } catch {
    return null;
  }
}

function buildDeepSeekRequestPayload(
  apiKey: string,
  model: DeepSeekModel,
  thinkingEnabled: boolean,
) {
  const trimmed = apiKey.trim();
  if (!trimmed) return undefined;
  return {
    apiKey: trimmed,
    model,
    thinkingEnabled,
  };
}

function maskSecret(secret: string) {
  const trimmed = secret.trim();
  if (trimmed.length <= 10) return "已保存";
  return `${trimmed.slice(0, 6)}...${trimmed.slice(-4)}`;
}

function authSetupMessage(hasDatabaseUrl: boolean, hasAuthSecret: boolean) {
  if (hasDatabaseUrl && hasAuthSecret) {
    return "邮箱密码登录已经具备基础配置，可以注册和登录。";
  }
  if (!hasDatabaseUrl && !hasAuthSecret) {
    return "还缺 DATABASE_URL，以及 NEXTAUTH_SECRET 或 AUTH_SECRET。";
  }
  if (!hasDatabaseUrl) {
    return "还缺 DATABASE_URL，注册登录没有数据库可以写入。";
  }
  return "还缺 NEXTAUTH_SECRET 或 AUTH_SECRET，NextAuth 不能安全签发会话。";
}

function sectionDisplayLabel(section: AppSection, language: UiLanguage): string {
  return productCopy[language].navLabels[section];
}

function sectionSubtitle(
  section: AppSection,
  groupFilter: string | null,
  groups: DashboardData["groups"],
  language: UiLanguage = "zh",
): string {
  if (groupFilter) {
    return language === "zh"
      ? `当前只看「${groupLabel(groups, groupFilter)}」这个分组，日历、档案和星图都会按这个视角理解。`
      : `Showing the ${groupLabel(groups, groupFilter)} group across profiles, calendar, and map.`;
  }

  const subtitles: Record<UiLanguage, Record<AppSection, string>> = {
    zh: {
      home: "先在「自我脉络」和「朋友记忆」之间切换：前者处理个人反思与待确认，后者管理朋友档案与关系星图。",
      inbox: "AI 先把建议放在这里，确认后才会写进朋友档案。",
      people: "每个人都有独立档案，生日、忌口、兴趣、学习、事业和边界都能慢慢补齐。",
      groups: "分组单独管理，圈子、颜色、描述和合并删除都在这里处理。",
      calendar: "把生日、提醒、礼物时机和人生节点放到一张关系日历里。",
      reminders: "给重要的人和重要的日子留一个私密提醒。",
      gifts: "礼物建议必须能解释来源，也能按预算筛选。",
      search: "只从你保存过的朋友记忆里查，不凭空编故事。",
      map: "由确认记忆自动整理关系边；星图只展示有来源支持的关系。",
      files: "把聊天记录、截图、笔记和 PDF 放进待解析队列。",
      brief: "把今天真正值得注意的朋友关系先拎出来。",
      settings: "管理账号、语言、DeepSeek、同步准备情况和隐私边界。",
    },
    en: {
      home: "Switch between Self Thread for reflection and review, and Friend Memory for profiles and relationship maps.",
      inbox: "AI suggestions wait here until you confirm them.",
      people: "Each person has a fuller profile: milestones, taste, interests, work, study, and boundaries.",
      groups: "Manage circles, colors, descriptions, deletion, and merge behavior in one place.",
      calendar: "See birthdays, reminders, gifts, and life events in one relationship calendar.",
      reminders: "Keep private reminders for people and dates that matter.",
      gifts: "Filter gift ideas by budget and trace every idea back to known context.",
      search: "Search saved memories only, with source-backed answers.",
      map: "Relationship edges are organized from confirmed memories and source-backed signals.",
      files: "Queue chat logs, screenshots, notes, and PDFs for parsing.",
      brief: "Pull forward the relationships that deserve attention today.",
      settings: "Manage account, language, DeepSeek, sync readiness, and privacy boundaries.",
    },
  };

  return subtitles[language][section];
}
