# 本地下载文件夹分类 + 拖动排序 设计文档

- 日期: 2026-09-13
- 范围: Venera fork (`com.github.skyline34.venera`)，本地下载子系统
- 目标: 在本地下载中引入虚拟文件夹分类，并支持文件夹之间、文件夹内部漫画的拖动排序

## 1. 需求

1. 本地下载支持虚拟文件夹分类（不移动磁盘文件）
2. 文件夹可拖动排序，文件夹内部漫画也可拖动排序
3. 漫画可通过多选菜单"移动到文件夹"，也可从列表页拖到文件夹卡片归类
4. 页面为两级结构：文件夹列表 -> 文件夹内部
5. 排序菜单新增"自定义"，与现有 name/time 共存
6. 拖动视觉美观
7. 创建文件夹支持自定义分类名

## 2. 数据模型

`local.db` 的 `comics` 表新增：

- `folder TEXT NOT NULL DEFAULT ''`（空串表示未分类）
- `display_order INTEGER NOT NULL DEFAULT 0`

新建表：

- `folders(name TEXT PRIMARY KEY, order_value INTEGER NOT NULL)`

迁移要求幂等：

- 用 `PRAGMA table_info(comics)` 判断列是否存在，缺列才 `ALTER TABLE ADD COLUMN`
- 首次迁移一次性 `UPDATE comics SET display_order = created_at WHERE display_order = 0`
- `CREATE TABLE IF NOT EXISTS folders`

## 3. 已知风险与对策（自查结论）

1. `add()` 位置参数 INSERT 在加列后会崩 -> 改显式列名
2. `INSERT OR REPLACE` 会重置 folder/display_order -> 从 old 继承
3. 新下载 display_order 全 0 -> 分配 MAX+1
4. `getComics` 三元 ORDER BY 无法承载 custom -> 改 switch
5. 长按既多选又拖拽 -> 独立"整理模式"
6. 迁移必须幂等
7. 文件夹卡片重排与拖拽归类手势冲突 -> 文件夹排序独立弹窗
8. 重命名/删除跨表一致性 -> 事务
9. `fromRow` 改列名取值
10. 搜索态平铺、标注分类、禁用拖拽
11. 移动后清空 selectedComics
12. PopScope 并入整理模式
13. feedback 关闭 Hero
14. 命名区分"文件夹分类"与系统目录

## 4. Manager API

- `LocalSortType` 增 `custom`
- `getComics(sortType)` / `getFolderComics(folder, sortType)`
- `getFolders()`（未分类置顶）
- `createFolder` / `renameFolder` / `deleteFolder`
- `moveComicsToFolder(list, folder)`
- `reorderComics(list, folder)` / `reorderFolders(list)`

## 5. UI

- 列表页：文件夹卡片（含未分类，置顶）+ 未分类漫画网格 + 整理开关
- 文件夹内部页：漫画网格 + 自定义排序 + 移动到文件夹
- 整理模式：拖动排序（ReorderableBuilder）、拖拽归类（LongPressDraggable + DragTarget）

## 6. 发布与更新

1. bump versionCode: `1.6.3+163` -> `1.6.3+164`
2. 迁移用旧库回归测试
3. 备份 `android/app/venera.keystore` + `android/key.properties`
4. 安装与旧版相同的 ABI 分包（arm64-v8a）
