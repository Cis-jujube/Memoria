import {
  Bell,
  CalendarDays,
  FileUp,
  Gift,
  Home,
  Inbox,
  Network,
  Search,
  Settings,
  Sparkles,
  UserPlus,
  Users,
  type LucideIcon,
} from "lucide-react";

export const appSections = [
  "home",
  "inbox",
  "people",
  "groups",
  "calendar",
  "reminders",
  "gifts",
  "search",
  "map",
  "files",
  "brief",
  "settings",
] as const;

export type AppSection = (typeof appSections)[number];
export type NavigationMode = "home" | "selfThread" | "friendMemory" | "system";

export const groupFilters = [
  "classmates",
  "study-abroad",
  "home-friends",
  "internship",
] as const;

export type GroupFilter = (typeof groupFilters)[number];

export type NavigationItem = {
  section: AppSection;
  label: string;
  icon: LucideIcon;
  mode: NavigationMode;
  badgeKey?: "inbox" | "reminders" | "gifts" | "files";
};

export const navigationItems: NavigationItem[] = [
  { section: "home", label: "首页", icon: Home, mode: "home" },
  { section: "inbox", label: "待确认", icon: Inbox, mode: "selfThread", badgeKey: "inbox" },
  { section: "search", label: "记忆搜索", icon: Search, mode: "selfThread" },
  { section: "files", label: "文件导入", icon: FileUp, mode: "selfThread", badgeKey: "files" },
  { section: "brief", label: "今日简报", icon: Sparkles, mode: "selfThread" },
  { section: "people", label: "朋友档案", icon: Users, mode: "friendMemory" },
  { section: "groups", label: "分组编辑", icon: UserPlus, mode: "friendMemory" },
  { section: "map", label: "关系星图", icon: Network, mode: "friendMemory" },
  { section: "calendar", label: "关系日历", icon: CalendarDays, mode: "friendMemory" },
  { section: "reminders", label: "提醒", icon: Bell, mode: "friendMemory", badgeKey: "reminders" },
  { section: "gifts", label: "礼物灵感", icon: Gift, mode: "friendMemory", badgeKey: "gifts" },
  { section: "settings", label: "账号设置", icon: Settings, mode: "system" },
];

export const groupNavigationItems: { filter: GroupFilter; label: string }[] = [
  { filter: "classmates", label: "同学" },
  { filter: "study-abroad", label: "海外学习" },
  { filter: "home-friends", label: "老朋友" },
  { filter: "internship", label: "实习圈" },
];

export function parseAppSection(value: string | null | undefined): AppSection {
  return appSections.includes(value as AppSection)
    ? (value as AppSection)
    : "home";
}

export function parseGroupFilter(
  value: string | null | undefined,
): GroupFilter | null {
  return groupFilters.includes(value as GroupFilter)
    ? (value as GroupFilter)
    : null;
}

export function sectionLabel(section: AppSection): string {
  return (
    navigationItems.find((item) => item.section === section)?.label ||
    "首页"
  );
}

export function groupLabelForFilter(filter: GroupFilter): string {
  return (
    groupNavigationItems.find((item) => item.filter === filter)?.label ||
    "朋友"
  );
}
