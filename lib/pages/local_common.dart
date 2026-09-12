import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/pages/comic_details_page/comic_page.dart';
import 'package:venera/pages/favorites/favorites_page.dart';
import 'package:venera/utils/cbz.dart';
import 'package:venera/utils/epub.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/pdf.dart';
import 'package:venera/utils/translations.dart';
import 'package:zip_flutter/zip_flutter.dart';

typedef ExportComicFunc = Future<File> Function(
    LocalComic comic, String outFilePath);

/// Sort dialog shared by the folder list and folder detail pages.
void showLocalSortDialog(BuildContext context, LocalSortType current,
    ValueChanged<LocalSortType> onChanged) {
  var value = current;
  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return ContentDialog(
          title: "Sort".tl,
          content: RadioGroup<LocalSortType>(
            groupValue: value,
            onChanged: (v) {
              setState(() {
                value = v ?? value;
              });
            },
            child: Column(
              children: [
                RadioListTile<LocalSortType>(
                  title: Text("Name".tl),
                  value: LocalSortType.name,
                ),
                RadioListTile<LocalSortType>(
                  title: Text("Date".tl),
                  value: LocalSortType.timeAsc,
                ),
                RadioListTile<LocalSortType>(
                  title: Text("Date Desc".tl),
                  value: LocalSortType.timeDesc,
                ),
                RadioListTile<LocalSortType>(
                  title: Text("Custom".tl),
                  value: LocalSortType.custom,
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                appdata.implicitData["local_sort"] = value.value;
                appdata.writeImplicitData();
                context.pop();
                onChanged(value);
              },
              child: Text("Confirm".tl),
            ),
          ],
        );
      });
    },
  );
}

const _invalidFolderChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];

/// Returns an error message key if [name] is not a valid folder name,
/// otherwise null. [exclude] is the current name when renaming.
String? validateFolderName(String name, {String? exclude}) {
  name = name.trim();
  if (name.isEmpty) {
    return "Category name cannot be empty";
  }
  if (name.length > 30) {
    return "Category name is too long";
  }
  if (_invalidFolderChars.any(name.contains)) {
    return "Invalid category name";
  }
  if (name != exclude && LocalManager().folderExists(name)) {
    return "A category with the same name already exists";
  }
  return null;
}

/// Opens the folder containing the comic in the system file explorer.
Future<void> openComicFolder(LocalComic comic) async {
  try {
    final folderPath = comic.baseDir;

    if (App.isWindows) {
      await Process.run('explorer', [folderPath]);
    } else if (App.isMacOS) {
      await Process.run('open', [folderPath]);
    } else if (App.isLinux) {
      try {
        await Process.run('xdg-open', [folderPath]);
      } catch (e) {
        try {
          await Process.run('nautilus', [folderPath]);
        } catch (e) {
          try {
            await Process.run('dolphin', [folderPath]);
          } catch (e) {
            try {
              await Process.run('thunar', [folderPath]);
            } catch (e) {
              await launchUrlString('file://$folderPath');
            }
          }
        }
      }
    } else {
      await launchUrlString('file://$folderPath');
    }
  } catch (e, s) {
    Log.error("Open Folder", "Failed to open comic folder: $e", s);
    if (App.rootContext.mounted) {
      App.rootContext.showMessage(message: "Failed to open folder: $e");
    }
  }
}

void showDeleteChaptersPopWindow(BuildContext context, LocalComic comic) {
  var chapters = <String>[];

  showPopUpWidget(
    context,
    PopUpWidgetScaffold(
      title: "Delete Chapters".tl,
      body: StatefulBuilder(builder: (context, setState) {
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: comic.downloadedChapters.length,
                itemBuilder: (context, index) {
                  var id = comic.downloadedChapters[index];
                  var chapter = comic.chapters![id] ?? "Unknown Chapter";
                  return CheckboxListTile(
                    title: Text(chapter),
                    value: chapters.contains(id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          chapters.add(id);
                        } else {
                          chapters.remove(id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () {
                      Future.delayed(const Duration(milliseconds: 200), () {
                        LocalManager().deleteComicChapters(comic, chapters);
                      });
                      App.rootContext.pop();
                    },
                    child: Text("Submit".tl),
                  )
                ],
              ),
            )
          ],
        );
      }),
    ),
  );
}

Future<bool> deleteLocalComics(
    BuildContext context, List<LocalComic> comics) async {
  bool isDeleted = false;
  await showDialog(
    context: context,
    builder: (context) {
      bool removeComicFile = true;
      bool removeFavoriteAndHistory = true;
      return StatefulBuilder(builder: (context, state) {
        return ContentDialog(
          title: "Delete".tl,
          content: Column(
            children: [
              CheckboxListTile(
                title: Text("Remove local favorite and history".tl),
                value: removeFavoriteAndHistory,
                onChanged: (v) {
                  state(() {
                    removeFavoriteAndHistory = !removeFavoriteAndHistory;
                  });
                },
              ),
              CheckboxListTile(
                title: Text("Also remove files on disk".tl),
                value: removeComicFile,
                onChanged: (v) {
                  state(() {
                    removeComicFile = !removeComicFile;
                  });
                },
              )
            ],
          ),
          actions: [
            if (comics.length == 1 && comics.first.hasChapters)
              TextButton(
                child: Text("Delete Chapters".tl),
                onPressed: () {
                  context.pop();
                  showDeleteChaptersPopWindow(context, comics.first);
                },
              ),
            FilledButton(
              onPressed: () {
                context.pop();
                LocalManager().batchDeleteComics(
                  comics,
                  removeComicFile,
                  removeFavoriteAndHistory,
                );
                isDeleted = true;
              },
              child: Text("Confirm".tl),
            ),
          ],
        );
      });
    },
  );
  return isDeleted;
}

List<MenuEntry> localExportActions(
    BuildContext context, List<LocalComic> comics) {
  return [
    MenuEntry(
      icon: Icons.outbox_outlined,
      text: "Export as cbz".tl,
      onClick: () {
        exportLocalComics(context, comics, CBZ.export, ".cbz");
      },
    ),
    MenuEntry(
      icon: Icons.picture_as_pdf_outlined,
      text: "Export as pdf".tl,
      onClick: () async {
        exportLocalComics(context, comics, createPdfFromComicIsolate, ".pdf");
      },
    ),
    MenuEntry(
      icon: Icons.import_contacts_outlined,
      text: "Export as epub".tl,
      onClick: () async {
        exportLocalComics(context, comics, createEpubWithLocalComic, ".epub");
      },
    )
  ];
}

/// Export given comics to a file.
void exportLocalComics(BuildContext context, List<LocalComic> comics,
    ExportComicFunc export, String ext) async {
  var current = 0;
  var cacheDir = FilePath.join(App.cachePath, 'comics_export');
  var outFile = FilePath.join(App.cachePath, 'comics_export.zip');
  bool canceled = false;
  if (Directory(cacheDir).existsSync()) {
    Directory(cacheDir).deleteSync(recursive: true);
  }
  Directory(cacheDir).createSync();
  var loadingController = showLoadingDialog(
    context,
    allowCancel: true,
    message: "${"Exporting".tl} $current/${comics.length}",
    withProgress: comics.length > 1,
    onCancel: () {
      canceled = true;
    },
  );
  try {
    var fileName = "";
    for (var comic in comics) {
      fileName = FilePath.join(
        cacheDir,
        sanitizeFileName(comic.title, maxLength: 100) + ext,
      );
      await export(comic, fileName);
      current++;
      if (comics.length > 1) {
        loadingController
            .setMessage("${"Exporting".tl} $current/${comics.length}");
        loadingController.setProgress(current / comics.length);
      }
      if (canceled) {
        return;
      }
    }
    if (comics.length == 1) {
      await saveFile(
        file: File(fileName),
        filename: File(fileName).name,
      );
      Directory(cacheDir).deleteSync(recursive: true);
      loadingController.close();
      return;
    }
    loadingController.setProgress(null);
    loadingController.setMessage("Compressing".tl);
    await ZipFile.compressFolderAsync(cacheDir, outFile);
    if (canceled) {
      File(outFile).deleteIgnoreError();
      return;
    }
  } catch (e, s) {
    Log.error("Export Comics", e, s);
    context.showMessage(message: e.toString());
    loadingController.close();
    return;
  } finally {
    Directory(cacheDir).deleteIgnoreError(recursive: true);
  }
  await saveFile(
    file: File(outFile),
    filename: "comics_export.zip",
  );
  loadingController.close();
  File(outFile).deleteIgnoreError();
}

/// Menu entries for a single comic (long press menu).
List<MenuEntry> singleLocalComicMenu(
    BuildContext context, LocalComic comic, VoidCallback refresh) {
  return [
    MenuEntry(
      icon: Icons.folder_open,
      text: "Open Folder".tl,
      onClick: () => openComicFolder(comic),
    ),
    MenuEntry(
      icon: Icons.drive_file_move_outline,
      text: "Move to Category".tl,
      onClick: () =>
          showMoveToFolderDialog(context, [comic]).then((_) => refresh()),
    ),
    MenuEntry(
      icon: Icons.delete_outline,
      text: "Delete".tl,
      onClick: () => deleteLocalComics(context, [comic]).then((v) {
        if (v) {
          refresh();
        }
      }),
    ),
    ...localExportActions(context, [comic]),
  ];
}

/// Menu entries for multi selection.
List<MenuEntry> multiLocalComicMenu(BuildContext context,
    List<LocalComic> comics, VoidCallback onDone) {
  return [
    MenuEntry(
      icon: Icons.delete_outline,
      text: "Delete".tl,
      onClick: () {
        deleteLocalComics(context, comics).then((v) {
          if (v) {
            onDone();
          }
        });
      },
    ),
    MenuEntry(
      icon: Icons.favorite_border,
      text: "Add to favorites".tl,
      onClick: () => addFavorite(comics),
    ),
    MenuEntry(
      icon: Icons.drive_file_move_outline,
      text: "Move to Category".tl,
      onClick: () =>
          showMoveToFolderDialog(context, comics).then((_) => onDone()),
    ),
    if (comics.length == 1)
      MenuEntry(
        icon: Icons.folder_open,
        text: "Open Folder".tl,
        onClick: () => openComicFolder(comics.first),
      ),
    if (comics.length == 1)
      MenuEntry(
        icon: Icons.chrome_reader_mode_outlined,
        text: "View Detail".tl,
        onClick: () {
          context.to(() => ComicPage(
                id: comics.first.id,
                sourceKey: comics.first.sourceKey,
              ));
        },
      ),
    ...localExportActions(context, comics),
  ];
}

/// Lets the user pick a folder (including uncategorized) to move [comics] into.
Future<void> showMoveToFolderDialog(
    BuildContext context, List<LocalComic> comics) async {
  if (comics.isEmpty) {
    return;
  }
  var folders = LocalManager().getFolders();
  await showPopUpWidget(
    App.rootContext,
    PopUpWidgetScaffold(
      title: "Move to Category".tl,
      body: ListView(
        children: [
          for (var folder in folders)
            ListTile(
              leading: Icon(folder == LocalManager.uncategorizedFolder
                  ? Icons.folder_off_outlined
                  : Icons.folder_outlined),
              title: Text(
                  folder == LocalManager.uncategorizedFolder
                      ? "Uncategorized".tl
                      : folder),
              onTap: () {
                LocalManager().moveComicsToFolder(comics, folder);
                App.rootContext.pop();
                App.rootContext.showMessage(message: "Moved".tl);
              },
            ),
        ],
      ),
    ),
  );
}

/// Shows a dialog to create a folder. Returns the created name, or null.
Future<String?> showCreateFolderDialog(BuildContext context) async {
  var name = await showDialog<String>(
    context: context,
    builder: (context) => const _FolderNameDialog(title: "New Category"),
  );
  if (name == null) {
    return null;
  }
  LocalManager().createFolder(name);
  return name;
}

/// Shows a dialog to rename [oldName]. Returns the new name, or null.
Future<String?> showRenameFolderDialog(
    BuildContext context, String oldName) async {
  var name = await showDialog<String>(
    context: context,
    builder: (context) =>
        _FolderNameDialog(title: "Rename", initialValue: oldName, exclude: oldName),
  );
  if (name == null || name == oldName) {
    return null;
  }
  LocalManager().renameFolder(oldName, name);
  return name;
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog(
      {required this.title, this.initialValue, this.exclude});

  final String title;
  final String? initialValue;
  final String? exclude;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final controller = TextEditingController(text: widget.initialValue);
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    var name = controller.text.trim();
    var err = validateFolderName(name, exclude: widget.exclude);
    if (err != null) {
      setState(() {
        error = err.tl;
      });
      return;
    }
    context.pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: widget.title.tl,
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: "Category Name".tl,
          errorText: error,
        ),
        onSubmitted: (_) => submit(),
      ),
      actions: [
        FilledButton(
          onPressed: submit,
          child: Text("Confirm".tl),
        ),
      ],
    );
  }
}

/// Wraps a child so it can accept a dragged [LocalComic] (cross-category move).
/// When [accept] returns false the drop is ignored. Highlights while a
/// compatible drag hovers.
class ComicDropTarget extends StatelessWidget {
  const ComicDropTarget({
    super.key,
    required this.onAccept,
    this.accept,
    required this.child,
    this.borderRadius = 12,
  });

  final bool Function(LocalComic comic)? accept;
  final void Function(LocalComic comic) onAccept;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return DragTarget<LocalComic>(
      onWillAcceptWithDetails: (details) => accept?.call(details.data) ?? true,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidates, rejected) {
        var hovering = candidates.isNotEmpty;
        return Stack(
          children: [
            child,
            if (hovering)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary.toOpacity(0.2),
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: Border.all(
                        color: context.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A static handle icon shown on tiles in arrange mode as a hint that the
/// item can be dragged (long press to start).
class ComicHandleHint extends StatelessWidget {
  const ComicHandleHint({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.toOpacity(0.55),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.drag_indicator,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Whether a local comic drag is currently active (used for auto-scroll).
final ValueNotifier<bool> localComicDragActive = ValueNotifier<bool>(false);

/// Frame-synced auto-scroll while a local comic drag is near the top/bottom.
///
/// Replaces the package's stepped 10ms timer scroll with a smooth per-frame
/// scroll whose speed is proportional to how deep the pointer is in the edge
/// zone.
class DragAutoScroller extends StatefulWidget {
  const DragAutoScroller({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  State<DragAutoScroller> createState() => _DragAutoScrollerState();
}

class _DragAutoScrollerState extends State<DragAutoScroller>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);

  Offset? _pointer;

  static const double _edge = 80;
  static const double _maxSpeed = 14;

  @override
  void initState() {
    super.initState();
    localComicDragActive.addListener(_onActiveChanged);
  }

  @override
  void dispose() {
    localComicDragActive.removeListener(_onActiveChanged);
    _ticker.dispose();
    super.dispose();
  }

  void _onActiveChanged() {
    if (localComicDragActive.value) {
      if (!_ticker.isActive) {
        _ticker.start();
      }
    } else {
      if (_ticker.isActive) {
        _ticker.stop();
      }
      _pointer = null;
    }
  }

  void _onTick(Duration elapsed) {
    var pointer = _pointer;
    if (pointer == null || !widget.controller.hasClients) {
      return;
    }
    var box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    var local = box.globalToLocal(pointer);
    var size = box.size;
    double velocity = 0;
    if (widget.controller.position.axis == Axis.vertical) {
      // Only act when the pointer is within this scroller horizontally.
      if (local.dx < 0 || local.dx > size.width) {
        return;
      }
      if (local.dy < _edge) {
        velocity = -(1 - local.dy / _edge) * _maxSpeed;
      } else if (local.dy > size.height - _edge) {
        velocity = ((local.dy - (size.height - _edge)) / _edge) * _maxSpeed;
      }
    } else {
      // Only act when the pointer is within this scroller vertically.
      if (local.dy < 0 || local.dy > size.height) {
        return;
      }
      if (local.dx < _edge) {
        velocity = -(1 - local.dx / _edge) * _maxSpeed;
      } else if (local.dx > size.width - _edge) {
        velocity = ((local.dx - (size.width - _edge)) / _edge) * _maxSpeed;
      }
    }
    if (velocity != 0) {
      var position = widget.controller.position;
      widget.controller.jumpTo(
        (widget.controller.offset + velocity)
            .clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _pointer = event.position,
      onPointerMove: (event) => _pointer = event.position,
      child: widget.child,
    );
  }
}
