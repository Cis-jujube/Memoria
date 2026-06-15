import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";

import { FriendCommandCenter } from "@/components/app/friend-command-center";
import { demoDashboardData, type DashboardData } from "@/data/demo";

describe("FriendCommandCenter", () => {
  it("renders preview mode and adds local capture items before sign-in", async () => {
    const user = userEvent.setup();
    render(
      <FriendCommandCenter
        data={demoDashboardData}
        isAuthenticated={false}
        hasGoogleAuth={false}
        userName={null}
      />,
    );

    expect(
      screen.getByRole("heading", { level: 2, name: "首页" }),
    ).toBeInTheDocument();
    expect(screen.getAllByText("自我脉络").length).toBeGreaterThan(0);
    expect(screen.getAllByText("朋友记忆").length).toBeGreaterThan(0);

    await user.type(
      screen.getByLabelText(/随手记一条朋友近况/i),
      "昨天和 Alex 吃火锅，他不吃香菜",
    );
    await user.click(screen.getByRole("button", { name: /记录记忆/i }));

    expect(
      (await screen.findAllByText("昨天和 Alex 吃火锅，他不吃香菜")).length,
    ).toBeGreaterThan(0);
    expect(
      screen.getByText(/登录后可以调用真实 AI/i),
    ).toBeInTheDocument();
  });

  it("renders sidebar badges from current dashboard stats", () => {
    const data: DashboardData = {
      ...demoDashboardData,
      stats: {
        ...demoDashboardData.stats,
        inbox: 7,
        reminders: 5,
        files: 1,
      },
    };

    render(
      <FriendCommandCenter
        data={data}
        isAuthenticated={false}
        hasGoogleAuth={false}
        userName={null}
      />,
    );

    expect(
      screen.getByRole("button", { name: "待确认 7" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "提醒 5" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "文件导入 1" }),
    ).toBeInTheDocument();
  });

  it("opens the capture workspace instead of AI Inbox from the quick record action", async () => {
    const user = userEvent.setup();

    render(
      <FriendCommandCenter
        data={demoDashboardData}
        isAuthenticated={false}
        hasGoogleAuth={false}
        userName={null}
      />,
    );

    await user.click(screen.getByRole("button", { name: /^朋友档案$/i }));
    await user.click(screen.getByRole("button", { name: "记一条新记忆" }));

    expect(
      screen.getByRole("heading", { level: 2, name: "首页" }),
    ).toBeInTheDocument();
    expect(screen.getByLabelText(/随手记一条朋友近况/i)).toBeInTheDocument();
  });

  it("surfaces smart focus items and ask suggestions", async () => {
    const user = userEvent.setup();

    render(
      <FriendCommandCenter
        data={demoDashboardData}
        isAuthenticated={false}
        hasGoogleAuth={false}
        userName={null}
      />,
    );

    expect(screen.getAllByText("今日重点").length).toBeGreaterThan(0);
    expect(screen.getAllByText("确认 Alex Chen 的新信息").length).toBeGreaterThan(0);

    await user.click(screen.getByRole("button", { name: /^记忆搜索$/i }));
    await user.click(
      screen.getByRole("button", {
        name: "Alex Chen 的待确认里有什么？",
      }),
    );

    expect(screen.getByPlaceholderText("问问你的朋友记忆...")).toHaveValue(
      "Alex Chen 的待确认里有什么？",
    );
  });

  it("shows next suggested actions on people cards", async () => {
    const user = userEvent.setup();

    render(
      <FriendCommandCenter
        data={demoDashboardData}
        isAuthenticated={false}
        hasGoogleAuth={false}
        userName={null}
      />,
    );

    await user.click(screen.getByRole("button", { name: /^朋友档案$/i }));

    expect(screen.getAllByText("确认 2 条待处理信息").length).toBeGreaterThan(
      0,
    );
    expect(screen.getByLabelText("亲近度 5/6")).toBeInTheDocument();
    expect(screen.getByText("AI 分类规则")).toBeInTheDocument();
  });

  it("explains that the relationship map is organized from confirmed memories", async () => {
    const user = userEvent.setup();

    render(
      <FriendCommandCenter
        data={demoDashboardData}
        isAuthenticated={false}
        hasGoogleAuth={false}
        userName={null}
      />,
    );

    await user.click(screen.getByRole("button", { name: /^关系星图$/i }));

    expect(
      screen.getByText(/关系边由确认记忆自动整理/i),
    ).toBeInTheDocument();
  });

  it("switches sections and filters people through group navigation", async () => {
    const user = userEvent.setup();

    render(
      <FriendCommandCenter
        data={demoDashboardData}
        isAuthenticated={false}
        hasGoogleAuth={false}
        userName={null}
      />,
    );

    await user.click(screen.getByRole("button", { name: /^朋友档案$/i }));

    expect(
      screen.getByRole("heading", { level: 2, name: /朋友档案/i }),
    ).toBeInTheDocument();
    expect(screen.getAllByText("Alex Chen").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Jason Wu").length).toBeGreaterThan(0);

    await user.click(screen.getByRole("button", { name: /^实习圈$/i }));

    expect(
      screen.getByRole("heading", { level: 2, name: "实习圈 · 朋友" }),
    ).toBeInTheDocument();
    expect(screen.queryByText("Alex Chen")).not.toBeInTheDocument();
    expect(screen.getAllByText("Jason Wu").length).toBeGreaterThan(0);
  });

  it("keeps group editing separate from people profiles", async () => {
    const user = userEvent.setup();

    render(
      <FriendCommandCenter
        data={demoDashboardData}
        isAuthenticated={false}
        hasGoogleAuth={false}
        userName={null}
      />,
    );

    await user.click(screen.getByRole("button", { name: /^朋友档案$/i }));

    expect(
      screen.getByRole("heading", { level: 2, name: "朋友档案" }),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("heading", { name: "分组编辑" }),
    ).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /^分组编辑$/i }));

    expect(
      screen.getByRole("heading", { level: 2, name: "分组编辑" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /新建分组/i })).toBeInTheDocument();
  });

  it("shows DeepSeek settings, server readiness, and language switching", async () => {
    const user = userEvent.setup();

    render(
      <FriendCommandCenter
        data={demoDashboardData}
        isAuthenticated={false}
        hasAuthSecret={false}
        hasDatabaseUrl
        hasGoogleAuth={false}
        hasPasswordAuth={false}
        userName={null}
      />,
    );

    await user.click(screen.getByRole("button", { name: /^账号设置$/i }));

    expect(screen.getByText("DeepSeek API")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /去 DeepSeek 平台/i })).toHaveAttribute(
      "href",
      "https://platform.deepseek.com/",
    );
    expect(screen.getAllByText(/还缺 NEXTAUTH_SECRET/i).length).toBeGreaterThan(0);

    await user.click(screen.getByRole("button", { name: /^English/i }));

    expect(screen.getByRole("heading", { level: 2, name: "Settings" })).toBeInTheDocument();
  });

  it("does not persist the raw DeepSeek API key in localStorage", async () => {
    const user = userEvent.setup();
    localStorage.clear();
    sessionStorage.clear();

    render(
      <FriendCommandCenter
        data={demoDashboardData}
        isAuthenticated={false}
        hasAuthSecret={false}
        hasDatabaseUrl
        hasGoogleAuth={false}
        hasPasswordAuth={false}
        userName={null}
      />,
    );

    await user.click(screen.getByRole("button", { name: /^账号设置$/i }));
    await user.type(screen.getByLabelText(/API key/i), "sk-test-sensitive-key");
    await user.click(screen.getByRole("button", { name: "保存 DeepSeek 设置" }));

    expect(localStorage.getItem("memoria.deepseek-settings")).not.toContain(
      "sk-test-sensitive-key",
    );
    expect(sessionStorage.getItem("memoria.deepseek-session-key")).toBe(
      "sk-test-sensitive-key",
    );
  });

  it("filters gift ideas by price band", async () => {
    const user = userEvent.setup();

    render(
      <FriendCommandCenter
        data={demoDashboardData}
        isAuthenticated={false}
        hasGoogleAuth={false}
        userName={null}
      />,
    );

    await user.click(screen.getByRole("button", { name: /^礼物灵感/i }));
    await user.click(screen.getByRole("button", { name: "中等" }));

    expect(screen.getByText("BYREDO 香氛礼盒")).toBeInTheDocument();
    expect(screen.queryByText("茶样礼盒")).not.toBeInTheDocument();
  });
});
