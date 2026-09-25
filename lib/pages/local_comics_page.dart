import 'package:flutter/material.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/image_provider/local_comic_image.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/pages/downloading_page.dart';
import 'package:venera/pages/local_common.dart';
import 'package:venera/pages/local_folder_page.dart';
import 'package:venera/utils/translations.dart';

class LocalComicsPage extends StatefulWidget {
  const LocalComicsPage({super.key});

  @override
  State<LocalComicsPage> createState() => _LocalComicsPageState();
}

class _LocalComicsPageState extends State<LocalComicsPage> {
  List<String> folders = [];
  Map<String, List<LocalComic>> folderComics = {};
  List<LocalComic> uncategorized = [];
  List<LocalComic> searchResults = [];

  late LocalSortType sortType;

  String keyword = "";
  bool searchMode = false;

  bool multiSelectMode = false;
  Map<LocalComic, bool> selectedComics = {};

  bool arrangeMode = false;

  /// Set when a comic is dropped onto another container so the source
  /// reorder callback is skipped.
  bool _skipNextReorder = false;

  final _uncatGridKey = GlobalKey();

  final _scrollController = ScrollController();

  /// A dedicated controller for the (non-scrolling) uncategorized grid.
  ///
  /// The grid lives inside the page's outer scroll view, but the reorder
  /// package computes drop targets relative to the widget it wraps. Passing
  /// this zero-offset controller makes those calculations grid-relative and
  /// independent of the outer scroll position, so drag-reordering stays
  /// accurate even while the page auto-scrolls mid-drag.
  final _uncatGridController = ScrollController();

  List<LocalComic> get currentComics =>
      searchMode ? searchResults : uncategorized;

  void update() {
    setState(() {
      var allFolders = LocalManager().getFolders();
      folders = allFolders
          .where((e) => e != LocalManager.uncategorizedFolder)
          .toList();
      folderComics = {
        for (var folder in folders)
          folder: LocalManager().getFolderComics(folder, sortType),
      };
      uncategorized = LocalManager()
          .getFolderComics(LocalManager.uncategorizedFolder, sortType);
      if (keyword.isNotEmpty) {
        searchResults = LocalManager().search(keyword);
      }
    });
  }

  @override
  void initState() {
    var sort = appdata.implicitData["local_sort"] ?? "name";
    sortType = LocalSortType.fromString(sort);
    update();
    LocalManager().addListener(update);
    super.initState();
  }

  @override
  void dispose() {
    LocalManager().removeListener(update);
    _scrollController.dispose();
    _uncatGridController.dispose();
    super.dispose();
  }

  void enterArrange() {
    sortType = LocalSortType.custom;
    appdata.implicitData["local_sort"] = sortType.value;
    appdata.writeImplicitData();
    setState(() {
      arrangeMode = true;
    });
    update();
  }

  void exitMultiSelect() {
    setState(() {
      multiSelectMode = false;
      selectedComics.clear();
    });
  }

  void exitArrange() {
    setState(() {
      arrangeMode = false;
    });
  }

  void selectAll() {
    setState(() {
      selectedComics = currentComics.asMap().map((k, v) => MapEntry(v, true));
    });
  }

  void deSelect() {
    setState(() {
      selectedComics.clear();
    });
  }

  void invertSelection() {
    setState(() {
      currentComics.asMap().forEach((k, v) {
        selectedComics[v] = !selectedComics.putIfAbsent(v, () => false);
      });
      selectedComics.removeWhere((k, v) => !v);
    });
  }

  void _persistReorder(List<LocalComic> list) {
    if (_skipNextReorder) {
      _skipNextReorder = false;
      return;
    }
    LocalManager().reorderComics(list);
  }

  void _moveToFolder(LocalComic comic, String folder) {
    _skipNextReorder = true;
    LocalManager().moveComicsToFolder([comic], folder);
  }

  Widget buildMultiSelectMenu() {
    return MenuButton(entries: [
      ...multiLocalComicMenu(
        context,
        selectedComics.keys.toList(),
        () {
          setState(() {
            multiSelectMode = false;
            selectedComics.clear();
          });
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> selectActions = [
      IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: "Select All".tl,
          onPressed: selectAll),
      IconButton(
          icon: const Icon(Icons.deselect),
          tooltip: "Deselect".tl,
          onPressed: deSelect),
      IconButton(
          icon: const Icon(Icons.flip),
          tooltip: "Invert Selection".tl,
          onPressed: invertSelection),
      buildMultiSelectMenu(),
    ];

    List<Widget> normalActions = [
      Tooltip(
        message: "Search".tl,
        child: IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            setState(() {
              searchMode = true;
            });
          },
        ),
      ),
      Tooltip(
        message: "Sort".tl,
        child: IconButton(
          icon: const Icon(Icons.sort),
          onPressed: () {
            showLocalSortDialog(context, sortType, (v) {
              sortType = v;
              update();
            });
          },
        ),
      ),
      Tooltip(
        message: "Downloading".tl,
        child: IconButton(
          icon: const Icon(Icons.download),
          onPressed: () {
            showPopUpWidget(context, const DownloadingPage());
          },
        ),
      ),
      Tooltip(
        message: "Arrange".tl,
        child: IconButton(
          icon: const Icon(Icons.dashboard_customize_outlined),
          onPressed: enterArrange,
        ),
      ),
    ];

    List<Widget> arrangeActions = [
      Tooltip(
        message: "Help".tl,
        child: IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: () {
            showInfoDialog(
              context: context,
              title: "Arrange".tl,
              content: "Long press and drag to reorder.".tl,
            );
          },
        ),
      ),
      TextButton(
        onPressed: exitArrange,
        child: Text("Done".tl),
      ),
    ];

    var body = Scaffold(
      floatingActionButton: (!searchMode && !multiSelectMode && !arrangeMode)
          ? FloatingActionButton(
              tooltip: "New Category".tl,
              onPressed: () async {
                var name = await showCreateFolderDialog(context);
                if (name != null) {
                  setState(() {});
                }
              },
              child: const Icon(Icons.create_new_folder_outlined),
            )
          : null,
      body: DragAutoScroller(
        controller: _scrollController,
        child: SmoothCustomScrollView(
          controller: _scrollController,
          slivers: [
          SliverAppbar(
            leading: Tooltip(
              message: multiSelectMode || arrangeMode ? "Cancel".tl : "Back".tl,
              child: IconButton(
                onPressed: () {
                  if (multiSelectMode) {
                    exitMultiSelect();
                  } else if (arrangeMode) {
                    exitArrange();
                  } else if (searchMode) {
                    setState(() {
                      searchMode = false;
                      keyword = "";
                      update();
                    });
                  } else {
                    context.pop();
                  }
                },
                icon: (multiSelectMode || arrangeMode)
                    ? const Icon(Icons.close)
                    : const Icon(Icons.arrow_back),
              ),
            ),
            title: multiSelectMode
                ? Text(selectedComics.length.toString())
                : Text("Local".tl),
            actions: multiSelectMode
                ? selectActions
                : (arrangeMode
                    ? arrangeActions
                    : (searchMode ? [] : normalActions)),
          ),
          if (searchMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Search".tl,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) {
                    keyword = v;
                    update();
                  },
                ),
              ),
            ),
          if (searchMode)
            SliverGridComics(
              comics: searchResults,
              selections: multiSelectMode ? selectedComics : null,
              onLongPressed: (c, heroID) {
                setState(() {
                  multiSelectMode = true;
                  selectedComics[c as LocalComic] = true;
                });
              },
              onTap: (c, heroID) {
                if (multiSelectMode) {
                  setState(() {
                    if (selectedComics.containsKey(c as LocalComic)) {
                      selectedComics.remove(c);
                    } else {
                      selectedComics[c] = true;
                    }
                    if (selectedComics.isEmpty) {
                      multiSelectMode = false;
                    }
                  });
                } else {
                  (c as LocalComic).read();
                }
              },
              menuBuilder: (c) => singleLocalComicMenu(
                  context, c as LocalComic, () => setState(() {})),
            )
          else ...[
            if (arrangeMode)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_indicator),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text("Long press and drag to reorder.".tl),
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: _SectionHeader(title: "Categories".tl),
            ),
            if (folders.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "No comics".tl,
                    style: TextStyle(color: context.colorScheme.outline),
                  ),
                ),
              )
            else if (arrangeMode)
              SliverReorderableList(
                itemCount: folders.length,
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex < newIndex) {
                    newIndex--;
                  }
                  setState(() {
                    var item = folders.removeAt(oldIndex);
                    folders.insert(newIndex, item);
                  });
                  LocalManager().reorderFolders(folders);
                },
                itemBuilder: (context, index) {
                  var folder = folders[index];
                  var comics = folderComics[folder] ?? [];
                  return _FolderSection(
                    key: ValueKey(folder),
                    folder: folder,
                    comics: comics,
                    index: index,
                    arrangeMode: true,
                    onTapHeader: () {},
                    onLongPressHeader: (location) {},
                    onRead: (comic) {},
                    onLongPressComic: (comic, location) {},
                    onMoveToFolder: (comic) => _moveToFolder(comic, folder),
                    onReorder: _persistReorder,
                    onDragStarted: () => _skipNextReorder = false,
                  );
                },
              )
            else
              SliverList.builder(
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  var folder = folders[index];
                  var comics = folderComics[folder] ?? [];
                  return _FolderSection(
                    folder: folder,
                    comics: comics,
                    index: index,
                    arrangeMode: false,
                    onTapHeader: () {
                      context.to(() => LocalFolderPage(folder: folder));
                    },
                    onLongPressHeader: (location) =>
                        _showFolderMenuAt(folder, location),
                    onRead: (comic) => comic.read(),
                    onLongPressComic: (comic, location) {
                      showMenuX(
                        App.rootContext,
                        location,
                        singleLocalComicMenu(
                            context, comic, () => setState(() {})),
                      );
                    },
                    onMoveToFolder: (comic) {},
                    onReorder: (list) {},
                    onDragStarted: () {},
                  );
                },
              ),
            SliverToBoxAdapter(
              child: arrangeMode
                  ? ComicDropTarget(
                      accept: (c) =>
                          c.folder != LocalManager.uncategorizedFolder,
                      onAccept: (comic) => _moveToFolder(
                          comic, LocalManager.uncategorizedFolder),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _UncategorizedHeader(count: uncategorized.length),
                          if (uncategorized.isNotEmpty)
                            ReorderableBuilder<LocalComic>.builder(
                              scrollController: _uncatGridController,
                              enableScrollingWhileDragging: false,
                              onDragStarted: (_) {
                                _skipNextReorder = false;
                                localComicDragActive.value = true;
                              },
                              onDragEnd: (_) =>
                                  localComicDragActive.value = false,
                              onReorder: (reorderFunc) {
                                _persistReorder(reorderFunc(uncategorized));
                              },
                              childBuilder: (itemBuilder) {
                                return GridView.builder(
                                  key: _uncatGridKey,
                                  controller: _uncatGridController,
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  gridDelegate:
                                      SliverGridDelegateWithComics(),
                                  itemCount: uncategorized.length,
                                  itemBuilder: (context, index) {
                                    var comic = uncategorized[index];
                                    return itemBuilder(
                                      CustomDraggable(
                                        key: ValueKey(
                                            "${comic.id}-${comic.comicType.value}"),
                                        data: comic,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ComicTile(
                                              comic: comic,
                                              enableLongPressed: false,
                                              onTap: () {},
                                            ),
                                            const Positioned(
                                              right: 6,
                                              bottom: 6,
                                              child: ComicHandleHint(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      index,
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    )
                  : _UncategorizedHeader(
                      count: uncategorized.length,
                      onTap: () {
                        context.to(() => LocalFolderPage(
                            folder: LocalManager.uncategorizedFolder));
                      },
                    ),
            ),
            if (!arrangeMode)
              SliverGridComics(
                comics: uncategorized,
                selections: multiSelectMode ? selectedComics : null,
                onLongPressed: (c, heroID) {
                  setState(() {
                    multiSelectMode = true;
                    selectedComics[c as LocalComic] = true;
                  });
                },
                onTap: (c, heroID) {
                  if (multiSelectMode) {
                    setState(() {
                      if (selectedComics.containsKey(c as LocalComic)) {
                        selectedComics.remove(c);
                      } else {
                        selectedComics[c] = true;
                      }
                      if (selectedComics.isEmpty) {
                        multiSelectMode = false;
                      }
                    });
                  } else {
                    (c as LocalComic).read();
                  }
                },
                menuBuilder: (c) => singleLocalComicMenu(
                    context, c as LocalComic, () => setState(() {})),
              ),
          ],
        ],
        ),
      ),
    );

    return PopScope(
      canPop: !multiSelectMode && !searchMode && !arrangeMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (multiSelectMode) {
          exitMultiSelect();
        } else if (arrangeMode) {
          exitArrange();
        } else if (searchMode) {
          setState(() {
            searchMode = false;
            keyword = "";
            update();
          });
        }
      },
      child: body,
    );
  }

  void _showFolderMenuAt(String folder, Offset location) {
    showMenuX(App.rootContext, location, [
      MenuEntry(
        icon: Icons.edit_outlined,
        text: "Rename".tl,
        onClick: () {
          showRenameFolderDialog(context, folder);
        },
      ),
      MenuEntry(
        icon: Icons.delete_outline,
        text: "Delete Category".tl,
        onClick: () {
          _confirmDeleteFolder(folder);
        },
      ),
    ]);
  }

  void _confirmDeleteFolder(String folder) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: "Delete Category".tl,
        content: Text("Delete category '@f' ?".tlParams({'f': folder})),
        actions: [
          FilledButton(
            onPressed: () {
              context.pop();
              LocalManager().deleteFolder(folder);
            },
            child: Text("Confirm".tl),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _UncategorizedHeader extends StatelessWidget {
  const _UncategorizedHeader({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    var row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Uncategorized".tl,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (onTap != null) const Icon(Icons.arrow_right),
        ],
      ),
    );
    if (onTap == null) {
      return row;
    }
    return InkWell(onTap: onTap, child: row);
  }
}

/// A category rendered as a titled, horizontally scrollable cover strip.
class _FolderSection extends StatelessWidget {
  const _FolderSection({
    super.key,
    required this.folder,
    required this.comics,
    required this.index,
    required this.arrangeMode,
    required this.onTapHeader,
    required this.onLongPressHeader,
    required this.onRead,
    required this.onLongPressComic,
    required this.onMoveToFolder,
    required this.onReorder,
    required this.onDragStarted,
  });

  final String folder;
  final List<LocalComic> comics;
  final int index;
  final bool arrangeMode;
  final VoidCallback onTapHeader;
  final void Function(Offset location) onLongPressHeader;
  final void Function(LocalComic comic) onRead;
  final void Function(LocalComic comic, Offset location) onLongPressComic;
  final void Function(LocalComic comic) onMoveToFolder;
  final void Function(List<LocalComic> list) onReorder;
  final VoidCallback onDragStarted;

  @override
  Widget build(BuildContext context) {
    if (arrangeMode) {
      return ComicDropTarget(
        accept: (c) => c.folder != folder,
        onAccept: onMoveToFolder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildArrangeHeader(context),
            if (comics.isEmpty)
              SizedBox(
                height: 136,
                child: Center(
                  child: Text(
                    "No comics".tl,
                    style: TextStyle(color: context.colorScheme.outline),
                  ),
                ),
              )
            else
              _CategoryStrip(
                comics: comics,
                onDragStarted: onDragStarted,
                onReorder: onReorder,
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNormalHeader(context),
        if (comics.isEmpty)
          SizedBox(
            height: 136,
            child: Center(
              child: Text(
                "No comics".tl,
                style: TextStyle(color: context.colorScheme.outline),
              ),
            ),
          )
        else
          SizedBox(
            height: 136,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: comics.length,
              itemBuilder: (context, i) {
                var comic = comics[i];
                return _FolderComicTile(
                  comic: comic,
                  onTap: () => onRead(comic),
                  onLongPress: (location) => onLongPressComic(comic, location),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNormalHeader(BuildContext context) {
    var row = _headerRow(context, showHandle: false);
    return Builder(builder: (headerContext) {
      return InkWell(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        onTap: onTapHeader,
        onLongPress: () {
          var box = headerContext.findRenderObject() as RenderBox;
          var size = box.size;
          onLongPressHeader(
            box.localToGlobal(Offset(size.width / 2, size.height / 2)),
          );
        },
        child: row,
      );
    });
  }

  Widget _buildArrangeHeader(BuildContext context) {
    return _headerRow(context, showHandle: true);
  }

  Widget _headerRow(BuildContext context, {required bool showHandle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          if (showHandle)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.drag_indicator, size: 22),
              ),
            )
          else
            const SizedBox(width: 4),
          const Icon(Icons.folder_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              folder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              comics.length.toString(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (!showHandle) const Icon(Icons.arrow_right),
        ],
      ),
    );
  }
}

/// A horizontally reorderable cover strip for one category (arrange mode).
class _CategoryStrip extends StatefulWidget {
  const _CategoryStrip({
    required this.comics,
    required this.onDragStarted,
    required this.onReorder,
  });

  final List<LocalComic> comics;
  final VoidCallback onDragStarted;
  final void Function(List<LocalComic> list) onReorder;

  @override
  State<_CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<_CategoryStrip> {
  final _controller = ScrollController();
  final _gridKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 136,
      child: DragAutoScroller(
        controller: _controller,
        child: ReorderableBuilder<LocalComic>.builder(
          scrollController: _controller,
          enableScrollingWhileDragging: false,
          onDragStarted: (_) {
            localComicDragActive.value = true;
            widget.onDragStarted();
          },
          onDragEnd: (_) => localComicDragActive.value = false,
          onReorder: (reorderFunc) {
            widget.onReorder(reorderFunc(widget.comics));
          },
          childBuilder: (itemBuilder) {
            return GridView.builder(
              key: _gridKey,
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                mainAxisExtent: 106,
              ),
              itemCount: widget.comics.length,
              itemBuilder: (context, index) {
                var comic = widget.comics[index];
                return itemBuilder(
                  CustomDraggable(
                    key: ValueKey("${comic.id}-${comic.comicType.value}"),
                    data: comic,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _FolderComicTile(comic: comic),
                        const Positioned(
                          right: 4,
                          bottom: 4,
                          child: ComicHandleHint(),
                        ),
                      ],
                    ),
                  ),
                  index,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// A single cover in a category strip. Tap to read, long press for the menu.
class _FolderComicTile extends StatelessWidget {
  const _FolderComicTile({
    required this.comic,
    this.onTap,
    this.onLongPress,
  });

  final LocalComic comic;
  final VoidCallback? onTap;
  final void Function(Offset location)? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (tileContext) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          onLongPress: onLongPress == null
              ? null
              : () {
                  var box = tileContext.findRenderObject() as RenderBox;
                  var size = box.size;
                  onLongPress!(
                    box.localToGlobal(Offset(size.width / 2, size.height / 2)),
                  );
                },
          child: Container(
            width: 98,
            height: 136,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: context.colorScheme.secondaryContainer,
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedImage(
              image: LocalComicImageProvider(comic),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      );
    });
  }
}
