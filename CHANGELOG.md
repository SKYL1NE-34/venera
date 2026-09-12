# Changelog

All notable changes to this fork are documented in this file.

This project is an unofficial fork of
[venera-app/venera](https://github.com/venera-app/venera) (GPL-3.0).

## [1.6.4] - 2026-09-13

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
