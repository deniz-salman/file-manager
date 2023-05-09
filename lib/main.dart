import 'dart:io';
import 'dart:math';
import 'package:awesome_icons/awesome_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_app_file/open_app_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:tftp/tftp.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.manageExternalStorage.request();
  await Permission.storage.request();

  runApp(const ProviderScope(child: App()));
}

extension DirectoryHelper on Directory {
  /// Recursively copies a directory + subdirectories into a target directory.
  /// Similar to Copy-Item in PowerShell.
  void copyTo(
    final Directory destination, {
    final List<String> ignoreDirList = const [],
    final List<String> ignoreFileList = const [],
  }) =>
      listSync().forEach((final entity) {
        if (entity is Directory) {
          if (ignoreDirList.contains(path.basename(entity.path))) {
            return;
          }
          final newDirectory = Directory(
            path.join(destination.absolute.path, path.basename(entity.path)),
          )..createSync();
          entity.absolute.copyTo(newDirectory);
        } else if (entity is File) {
          if (ignoreFileList.contains(path.basename(entity.path))) {
            return;
          }
          entity.copySync(
            path.join(destination.path, path.basename(entity.path)),
          );
        }
      });
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(textTheme: Typography.whiteMountainView),
      home: Scaffold(body: DirectoryView(Directory("/storage/emulated/0"))),
    );
  }
}

List<String> moveItems = [];
List<String> copyItems = [];

class DirectoryView extends StatefulWidget {
  const DirectoryView(this.directory, {super.key});
  final Directory directory;

  @override
  State<DirectoryView> createState() => _DirectoryViewState();
}

List<String> selectedItems = [];

class _DirectoryViewState extends State<DirectoryView> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (selectedItems.isNotEmpty) {
          selectedItems.clear();
          setState(() {});
          return false;
        } else {
          return true;
        }
      },
      child: SafeArea(
        child: Scaffold(
            backgroundColor: Colors.grey.shade900,
            appBar: AppBar(
                elevation: 0,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.directory.path=="/storage/emulated/0"?"Dahili depolama": path.basename(widget.directory.path)),
                    Text(
                      widget.directory.path,
                      style: Theme.of(context).textTheme.labelMedium,
                    )
                  ],
                ),
                actions: [
                  if (selectedItems.isNotEmpty) ...[
                    IconButton(
                        onPressed: () async {
                          for (var item in selectedItems) {
                            await Directory(item).delete(recursive: true);
                          }
                          selectedItems.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.delete)),
                    if (selectedItems.length == 1)
                      IconButton(
                          onPressed: () async {
                            final textFieldController = TextEditingController();
                            textFieldController.text =
                                path.basename(selectedItems.first);
                            await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                content: TextField(
                                  autofocus: true,
                                  controller: textFieldController,
                                  decoration: const InputDecoration(
                                      border: OutlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Colors.white)),
                                      enabledBorder: OutlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Colors.white))),
                                ),
                                backgroundColor: Colors.grey.shade900,
                                actionsAlignment: MainAxisAlignment.spaceAround,
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("İptal")),
                                  TextButton(
                                      onPressed: () async {
                                        switch (Directory(selectedItems.first)
                                            .statSync()
                                            .type) {
                                          case FileSystemEntityType.directory:
                                            await Directory(selectedItems.first)
                                                .rename(
                                                    "${path.dirname(selectedItems.first)}/${textFieldController.text}");
                                            break;
                                          case FileSystemEntityType.file:
                                            await File(selectedItems.first).rename(
                                                "${path.dirname(selectedItems.first)}/${textFieldController.text}");
                                            break;
                                          case FileSystemEntityType.link:
                                            await Link(selectedItems.first).rename(
                                                "${path.dirname(selectedItems.first)}/${textFieldController.text}");
                                            break;
                                          default:
                                        }
                                        // ignore: use_build_context_synchronously
                                        Navigator.pop(context);
                                        selectedItems.clear();
                                        setState(() {});
                                      },
                                      child: const Text("Değiştir"))
                                ],
                              ),
                            );
                            selectedItems.clear();
                            setState(() {});
                          },
                          icon: const Icon(
                              Icons.drive_file_rename_outline_rounded)),
                    IconButton(
                        onPressed: () {
                          moveItems.clear();
                          copyItems.clear();
                          moveItems.addAll(selectedItems);
                          selectedItems.clear();
                          setState(() {});
                        },
                        icon: const Icon(FontAwesomeIcons.cut)),
                    IconButton(
                        onPressed: () {
                          copyItems.clear();
                          moveItems.clear();
                          copyItems.addAll(selectedItems);
                          selectedItems.clear();
                          setState(() {});
                        },
                        icon: const Icon(FontAwesomeIcons.solidCopy)),
                  ],
                  if (moveItems.isNotEmpty || copyItems.isNotEmpty)
                    IconButton(
                        onPressed: () async {
                          if (copyItems.isNotEmpty) {
                            for (String item in copyItems) {
                              Directory(item).copyTo(widget.directory);
                            }
                          } else if (moveItems.isNotEmpty) {
                            for (var item in [...copyItems, ...moveItems]) {
                              await Directory(item).rename(
                                  "${widget.directory.path}/${path.basename(item)}");
                            }
                          }
                          moveItems.clear();
                          copyItems.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.paste)),
                  PopupMenuButton(
                    elevation: 15,
                    color: Colors.grey.shade900,
                    icon: Icon(
                      Icons.adaptive.more,
                      color: Colors.white,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text("Yeni klasör"),
                        onTap: () async {
                          Future.delayed(
                              Duration.zero,
                              () => showDialog(
                                    context: context,
                                    builder: (context) {
                                      final textFieldController =
                                          TextEditingController();
                                      final formKey = GlobalKey<FormState>();
                                      return AlertDialog(
                                        content: Form(
                                          key: formKey,
                                          child: TextFormField(
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty ||
                                                  value.contains("/")) {
                                                return 'Geçersiz klasör adı';
                                              }
                                              return null;
                                            },
                                            controller: textFieldController,
                                            autofocus: true,
                                            decoration: const InputDecoration(
                                                border: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                        color: Colors.white)),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color:
                                                                Colors.white))),
                                          ),
                                        ),
                                        backgroundColor: Colors.grey.shade900,
                                        actionsAlignment:
                                            MainAxisAlignment.spaceAround,
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text("İptal")),
                                          TextButton(
                                              onPressed: () async {
                                                if (formKey.currentState!
                                                    .validate()) {
                                                  await Directory(
                                                          "${widget.directory.path}/${textFieldController.text}")
                                                      .create();
                                                  selectedItems.clear();
                                                  setState(() {});
                                                  // ignore: use_build_context_synchronously
                                                  Navigator.pop(context);
                                                }
                                              },
                                              child: const Text("Oluştur"))
                                        ],
                                      );
                                    },
                                  ));
                        },
                      ),
                      PopupMenuItem(
                        child: const Text("Yeni dosya"),
                        onTap: () async {
                          Future.delayed(
                              Duration.zero,
                              () => showDialog(
                                    context: context,
                                    builder: (context) {
                                      final textFieldController =
                                          TextEditingController();
                                      final formKey = GlobalKey<FormState>();
                                      return AlertDialog(
                                        content: Form(
                                          key: formKey,
                                          child: TextFormField(
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty ||
                                                  value.contains("/")) {
                                                return 'Geçersiz dosya adı';
                                              }
                                              return null;
                                            },
                                            controller: textFieldController,
                                            autofocus: true,
                                            decoration: const InputDecoration(
                                                border: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                        color: Colors.white)),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                        borderSide: BorderSide(
                                                            color:
                                                                Colors.white))),
                                          ),
                                        ),
                                        backgroundColor: Colors.grey.shade900,
                                        actionsAlignment:
                                            MainAxisAlignment.spaceAround,
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text("İptal")),
                                          TextButton(
                                              onPressed: () async {
                                                if (formKey.currentState!
                                                    .validate()) {
                                                  await File(
                                                          "${widget.directory.path}/${textFieldController.text}")
                                                      .create();
                                                  selectedItems.clear();
                                                  setState(() {});
                                                  // ignore: use_build_context_synchronously
                                                  Navigator.pop(context);
                                                }
                                              },
                                              child: const Text("Oluştur"))
                                        ],
                                      );
                                    },
                                  ));
                        },
                      ),
                      PopupMenuItem(
                        child: const Text("Start server"),
                        onTap: () async {
                          var server =
                              await TFtpServer.bind("0.0.0.0", port: 6699);
                          server.listen((socket) {
                            socket.listen(onRead: (file, onProcess) {
                              print("read file from server:$file");
                              onProcess(progressCallback: (count, total) {
                                print("read:${count / total}%");
                              });
                              return "/sdcard/$file"; // server will read file from return value
                            }, onWrite: (file, doTransform) {
                              doTransform();
                              //infoController.add("write file to server:$file");
                              return "/sdcard/$file"; // server will write file to return value
                            }, onError: (code, msg) {
                              // infoController.add("Error[$code]:$msg");
                            });
                          });
                        },
                      )
                    ],
                  )
                ],
                backgroundColor: Colors.grey.shade900),
            body: RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: widget.directory.listSync().isEmpty
                  ? Center(
                      child: Text(
                        "Boş",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          for (FileSystemEntity item
                              in widget.directory.listSync()
                                ..sort((a, b) => path
                                    .basename(a.path)
                                    .compareTo(path.basename(b.path)))
                                ..sort((a, b) => a
                                    .statSync()
                                    .type
                                    .toString()
                                    .compareTo(b.statSync().type.toString())))
                            ListTile(
                              onTap: () {
                                if (selectedItems.isNotEmpty) {
                                  selectedItems.contains(item.path)
                                      ? selectedItems.remove(item.path)
                                      : selectedItems.add(item.path);
                                  setState(() {});
                                } else {
                                  if (item.statSync().type ==
                                      FileSystemEntityType.directory) {
                                    // ignore: use_build_context_synchronously
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DirectoryView(
                                              Directory(item.path)),
                                        ));
                                  } else {
                                    OpenAppFile.open(item.path);
                                  }
                                }
                              },
                              onLongPress: () {
                                selectedItems.contains(item.path)
                                    ? selectedItems.remove(item.path)
                                    : selectedItems.add(item.path);
                                setState(() {});
                              },
                              selected: selectedItems.contains(item.path),
                              selectedTileColor: Colors.blueGrey,
                              leading: Icon(
                                item.statSync().type ==
                                        FileSystemEntityType.directory
                                    ? Icons.folder
                                    : Icons.insert_drive_file_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    path.basename(item.path),
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    "${DateFormat('yyyy-MM-dd kk:mm').format(item.statSync().changed)} | ${formatBytes(item.statSync().size, 2)}",
                                    style:
                                        Theme.of(context).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item.statSync().type ==
                                      FileSystemEntityType.directory)
                                    Text(
                                      "(${Directory(item.path).listSync().length})",
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            )),
      ),
    );
  }
}

String formatBytes(int bytes, int decimals) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}
