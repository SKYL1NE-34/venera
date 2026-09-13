# 更新日志 / Changelog

> 本仓库是 [venera-app/venera](https://github.com/venera-app/venera)（GPL-3.0）的非官方分支，本文件记录本分支的所有重要改动。
>
> This repository is an unofficial fork of [venera-app/venera](https://github.com/venera-app/venera) (GPL-3.0). All notable changes to this fork are documented in this file.

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
