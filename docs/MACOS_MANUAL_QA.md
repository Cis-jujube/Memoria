# macOS Manual QA

## Phase 0-4 Smoke Test

1. Build and verify the app with `bash ./script/build_and_run.sh --verify`.
2. Open `记录` from the sidebar.
3. Confirm the segmented picker has exactly three modes: `自我检索`, `朋友档案管理`, and `行程安排`.
4. Choose `自我检索`.
5. Enter: `我好像总是怕麻烦 Alex，所以很多事情没说。`
6. Click `整理` / `Review`.
7. Confirm the app navigates to `整理台` with the `自我检索` partition selected.
8. Confirm a proposal card appears with title, summary, source quote,
   confidence, sensitivity, people, and themes.
9. Click `Edit`, change the title or summary, and click `Save edit`.
10. Click `Approve`.
11. Confirm the approved memory appears in `自我检索` with source quote.
12. Open `朋友档案管理`, select Alex, and confirm the related memory is visible.
13. Repeat `记录` with `朋友档案管理`, then confirm it opens the friend dossier partition in `整理台`.
14. Repeat `记录` with `行程安排`, then confirm it opens the schedule partition in `整理台`.
15. Reject one proposal in `整理台` and confirm rejected proposals do not appear in confirmed memory surfaces.

## Sidebar and Routing QA

1. Confirm the sidebar groups are `总览`, `工作流`, `三种模式`, and `系统`.
2. Confirm `工作流` contains `记录` and `整理台`.
3. Click sidebar `整理台`; confirm no mode partition is preselected and the overview is shown.
4. Click `首页`; confirm the main CTAs include `去记录` and `打开整理台`.
5. From the overview quick-record affordance, confirm it navigates to `记录` instead of writing a default-mode record directly.

## People, Actions, Search QA

1. Open `People`, select May, and confirm the dossier shows basic info,
   relationship info, interest map, food/lifestyle, education/career, life
   events/files, the 25-category schema, closeness signals, relationship map,
   and three scored gift recommendations.
2. Add a relationship edge such as `大学室友 / 关系很好 / close_friend`; confirm it
   appears in the relationship map after reload.
3. Enter `给小雨推荐生日礼物，预算 300 到 500 元，不要太普通，最好有一点心意。`
   and click `生成推荐`; confirm scored gift recommendations are saved.
4. Use `移动分组` to move Alex to `实习/职业`; confirm the group count and filtered
   people list update.
5. Open `Actions`; confirm today's reminder shows time, person, context, and
   location before upcoming reminders.
6. Open `Settings`; click `同步今天的提醒通知` and confirm the status message.
7. Open `自我检索`; switch between memory category and theme filters.
8. Open `对话检索`; search `冰岛`, `陶艺`, `香菜`, and `考试` and confirm Chinese
   results come from local people, reminders, memories, or gifts.

## Keychain and Privacy Checks

1. Open `Settings`.
2. Save a DeepSeek API key.
3. Confirm the UI reports the key as saved.
4. Run local SQLite schema checks and confirm the key does not appear in SQLite.
5. Remove the key from Settings.

## Commands

```bash
cd /Users/zaozaowang/Desktop/friend\ management/macos
swift run MemoriaProtocolChecks
swift build

cd /Users/zaozaowang/Desktop/friend\ management
bash ./script/build_and_run.sh --verify
```

`swift test` is currently not usable on this machine because the installed
CommandLineTools Swift toolchain does not provide `XCTest` or Swift `Testing`.
Use `swift run MemoriaProtocolChecks` for the Phase 0-4 protocol checks.
