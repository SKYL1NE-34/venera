import 'package:flutter/material.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/pages/local_common.dart';
import 'package:venera/utils/translations.dart';

class LocalFolderPage extends StatefulWidget {
  const LocalFolderPage({super.key, required this.folder});

  /// Empty string means uncategorized.
  final String folder;

  @override
  State<LocalFolderPage> createState() => _LocalFolderPageState();
}

class _LocalFolderPageState extends State<LocalFolderPage> {
  List<LocalComic> comics = [];

  late LocalSortType sortType;

  bool arrangeMode = false;

  bool multiSelectMode = false;
  Map<LocalComic, bool> selectedComics = {};

  final _scrollController = ScrollController();
  final _gridKey = GlobalKey();

  String get title =>
      widget.folder.isEmpty ? "Uncategorized".tl : widget.folder;

  void update() {
    setState(() {
      comics = LocalManager().getFolderComics(widget.folder, sortType);
      selectedComics.removeWhere((c, v) => !comics.any(
          (e) => e.id == c.id && e.comicType.value == c.comicType.value));
      if (selectedComics.isEmpty) {
        multiSelectMode = false;
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
    super.dispose();
  }

  void exitMultiSelect() {
    setState(() {
      multiSelectMode = false;
      selectedComics.clear();
    });
  }

  void enterArrange() {
    setState(() {
      arrangeMode = true;
      // Arrange mode always works on the manual order.
      sortType = LocalSortType.custom;
      appdata.implicitData["local_sort"] = sortType.value;
      appdata.writeImplicitData();
      comics = LocalManager().getFolderComics(widget.folder, sortType);
    });
  }

  void exitArrange() {
    setState(() {
      arrangeMode = false;
    });
  }

  void selectAll() {
    setState(() {
      selectedComics = comics.asMap().map((k, v) => MapEntry(v, true));
    });
  }

  void deSelect() {
    setState(() {
      selectedComics.clear();
    });
  }

  void invertSelection() {
    setState(() {
      comics.asMap().forEach((k, v) {
        selectedComics[v] = !selectedComics.putIfAbsent(v, () => false);
      });
      selectedComics.removeWhere((k, v) => !v);
    });
  }

  Widget _buildLeading() {
    return Tooltip(
      message: multiSelectMode || arrangeMode ? "Cancel".tl : "Back".tl,
      child: IconButton(
        onPressed: () {
          if (multiSelectMode) {
            exitMultiSelect();
          } else if (arrangeMode) {
            exitArrange();
          } else {
            context.pop();
          }
        },
        icon: (multiSelectMode || arrangeMode)
            ? const Icon(Icons.close)
            : const Icon(Icons.arrow_back),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(multiSelectMode ? selectedComics.length.toString() : title);
  }

  List<Widget> _buildActions() {
    if (multiSelectMode) {
      return [
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
        MenuButton(entries: [
          ...multiLocalComicMenu(context, selectedComics.keys.toList(), () {
            setState(() {
              multiSelectMode = false;
              selectedComics.clear();
            });
          }),
        ]),
      ];
    }
    if (arrangeMode) {
      return [
        Tooltip(
          message: "Help".tl,
          child: IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showInfoDialog(
                context: context,
                title: "Arrange".tl,
                content: "Drag the handle to reorder.".tl,
              );
            },
          ),
        ),
        TextButton(
          onPressed: exitArrange,
          child: Text("Done".tl),
        ),
      ];
    }
    return [
      Tooltip(
        message: "Sort".tl,
        child: IconButton(
          icon: const Icon(Icons.sort),
          onPressed: () {
            showLocalSortDialog(context, sortType, (v) {
              setState(() {
                sortType = v;
              });
              update();
            });
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
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !multiSelectMode && !arrangeMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (multiSelectMode) {
          exitMultiSelect();
        } else if (arrangeMode) {
          exitArrange();
        }
      },
      child: arrangeMode
          ? Scaffold(
              appBar: Appbar(
                leading: _buildLeading(),
                title: _buildTitle(),
                actions: _buildActions(),
              ),
              body: _buildArrangeGrid(),
            )
          : Scaffold(
              body: SmoothCustomScrollView(
                slivers: [
                  SliverAppbar(
                    leading: _buildLeading(),
                    title: _buildTitle(),
                    actions: _buildActions(),
                  ),
                  if (comics.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          "No comics".tl,
                          style:
                              TextStyle(color: context.colorScheme.outline),
                        ),
                      ),
                    )
                  else
                    SliverGridComics(
                      comics: comics,
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
              ),
            ),
    );
  }

  Widget _buildArrangeGrid() {
    return DragAutoScroller(
      controller: _scrollController,
      child: ReorderableBuilder<LocalComic>.builder(
        scrollController: _scrollController,
        enableScrollingWhileDragging: false,
        onDragStarted: (_) => localComicDragActive.value = true,
        onDragEnd: (_) => localComicDragActive.value = false,
        onReorder: (reorderFunc) {
          LocalManager().reorderComics(reorderFunc(comics));
        },
        childBuilder: (itemBuilder) {
          return GridView.builder(
            key: _gridKey,
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithComics(),
            itemCount: comics.length,
            itemBuilder: (context, index) {
              var comic = comics[index];
              return itemBuilder(
                CustomDraggable(
                  key: ValueKey("${comic.id}-${comic.comicType.value}"),
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
    );
  }
}
