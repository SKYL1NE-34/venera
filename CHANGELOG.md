# 更新日志 / Changelog

> 本仓库是 [venera-app/venera](https://github.com/venera-app/venera)（GPL-3.0）的非官方分支，本文件记录本分支的所有重要改动。
>
> This repository is an unofficial fork of [venera-app/venera](https://github.com/venera-app/venera) (GPL-3.0). All notable changes to this fork are documented in this file.

## [1.6.7] - 2026-09-18

### 新增

- 启动画面：冷启动显示手写体 "Venera Air" 书写动画（跟随深浅色、主题色文字，写完停留约 0.4 秒后淡出）
- 启动流程：Android 先挂载界面、后台初始化，减少冷启动白/黑屏

### 修复

- 冷启动原生窗口背景与启动页不一致导致的白色闪屏（NormalTheme 窗口背景对齐启动色）
- 深链 / 分享文本在启动页期间到达时，因导航上下文未就绪可能失败（改为等待上下文就绪，超时兜底）

### 变更

- 内置 Dancing Script 手写字体（OFL 许可）

### Added

- Splash screen: handwriting "Venera Air" reveal animation on cold start (theme-aware, holds ~0.4s then fades out)
- Startup: on Android the UI mounts first and initialization runs in the background, reducing the white/black cold-start screen

### Fixed

- White flash on cold start caused by the native window background not matching the splash (NormalTheme background aligned)
- Deep links / shared text arriving during the splash could fail because the navigator was not ready (now waits for it with a timeout)

### Changed

- Bundled the Dancing Script handwriting font (OFL license)

## [1.6.6] - 2026-09-14

### 修复

- 阅读器：拖动进度条后偶发无法点击页面收起菜单（`_animationCount` 泄漏导致内容被 `AbsorbPointer` 永久吸收）；动画异常或 future 卡死时计数也会被强制归零（try/catch + 看门狗）
- 阅读器：连续模式下用音量键翻页几页后卡住不动（第三方过渡滚动未搬动内容）——增加兜底：目标页未生效时直接跳转并复位滚动状态
- 阅读器：连续按键翻页时以"待到达的目标页"为基准，避免连续按键都算到同一页
- 阅读器：换章 / 切换每页图片数时可能跳回旧目标页

### 变更

- 拖动阅读进度条时页面立即跳转（同步跟随手指），松手后正常；拖动过程不再产生重叠动画

### 已知限制

- 连续模式的翻页过渡动画来自第三方库 `scrollable_positioned_list`，偶发不搬动内容；已用兜底跳转保证功能可用，动画成功率的改进列为后续计划

### Fixed

- Reader: after dragging the page slider, tapping the page could occasionally fail to close the menu (a leaked `_animationCount` made `AbsorbPointer` swallow all taps). The counter is now force-reset on error or a stuck future (try/catch + watchdog).
- Reader: in continuous mode, volume-key page turns could get stuck after a few pages (the third-party transition scroll did not move the content). Added a fallback that jumps directly and resets the scroll state when the target page did not take effect.
- Reader: next/prev navigation now uses the pending target page while an animation runs, so rapid key presses advance one page at a time.
- Reader: fixed a possible jump back to a stale page when changing chapter or images-per-page.

### Changed

- Dragging the reader slider now jumps the page immediately (follows the finger), and no longer spawns overlapping animations.

### Known limitation

- The continuous-mode page transition animation comes from the third-party `scrollable_positioned_list`; it occasionally fails to move the content. A fallback jump keeps navigation working; improving the animation success rate is planned as future work.

## [1.6.5] - 2026-09-13

### 修复

- 关于页版本号现在显示真实的已安装版本（此前写死为 1.6.3）
- "检查更新"不再误报：此前版本号写死，装了最新版仍提示有更新
- "检查更新"现在也会比较构建号（版本名相同但构建号更高也能检测到）

### Fixed

- The About page now shows the real installed version (previously hardcoded to 1.6.3).
- "Check for updates" no longer falsely reports an update when the latest version is installed.
- "Check for updates" now also compares the build number (a higher build number with the same version name is detected).

## [1.6.4] - 2026-09-13

### 新增

- 本地下载：虚拟分类文件夹（新建 / 重命名 / 删除）
- 本地下载：整理模式，可拖动排序分类与漫画，也可把漫画拖到分类上归类
- 本地下载：新增"自定义"排序，按每本漫画的手动顺序排列
- 本地下载：未分类标题可点击，进入未分类页面

### 变更

- 更名为 **Venera Air**（Android 应用名）；APK 文件名改为 `venera-air-<版本>[-<abi>].apk`
- 关于页：GitHub 与"检查更新"链接指向本分支；移除 Telegram 链接
- 本地下载：文案由"文件夹"改为"分类"

### 修复

- 本地下载：排序弹窗未应用所选顺序
- 本地下载：名称排序改为升序（A→Z）
- 本地下载：整理模式下封面条尺寸不再变化
- 图片加载：对瞬时空数据（例如文件正在写入）进行重试，而不是直接报 "Empty image data"

### 说明

- 首次启动会自动迁移 `local.db`：`comics` 表新增 `folder`、`display_order` 列，并新建 `folders` 表；原有数据保留

---

### Added

- Local downloads: virtual category folders (create / rename / delete).
- Local downloads: arrange mode to reorder categories and comics by dragging,
  and to drag a comic onto a category to move it.
- Local downloads: a `Custom` sort option backed by a per-comic manual order.
- Local downloads: the uncategorized header is tappable to open the
  uncategorized page.

### Changed

- Rebranded as **Venera Air** (Android app label); APK output name is now
  `venera-air-<version>[-<abi>].apk`.
- About page: GitHub and update-check links now point to this fork's
  repository; removed the Telegram link.
- Local downloads: wording changed from "Folder" to "Category".

### Fixed

- Local downloads: the sort dialog did not apply the selected order.
- Local downloads: "Name" sort is now ascending (A to Z).
- Local downloads: arrange-mode cover strip no longer changes size.
- Image loading: transient empty data (e.g. a file that is still being
  written) is retried instead of failing with "Empty image data".

### Notes

- `local.db` is migrated automatically on first launch: the `comics` table
  gains `folder` and `display_order` columns and a new `folders` table is
  created. Existing data is preserved.
