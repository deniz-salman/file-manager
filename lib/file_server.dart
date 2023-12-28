import 'dart:convert';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jaguar/jaguar.dart';
import 'package:local_assets_server/local_assets_server.dart';
import 'package:path/path.dart' as path;

late Jaguar apiServer;
late LocalAssetsServer webServer;

Future<void> startApi() async {
  apiServer = Jaguar(port: 1340);

  apiServer.get('/*', (Context ctx) async {
    String requestPath =
        "/storage/emulated/0${ctx.path == "/" ? "" : ctx.path}";
    bool isDirectory = Directory(requestPath).statSync().type ==
        FileSystemEntityType.directory;
    if (isDirectory) {
      return Directory(requestPath)
          .listSync()
          .map((e) => {
                "path": e.path,
                "basename": path.basename(e.path),
                "stat": {
                  "accessed": e.statSync().accessed,
                  "changed": e.statSync().changed,
                  "mode": e.statSync().mode,
                  "modified": e.statSync().modified,
                  "size": e.statSync().size,
                  "type": e.statSync().type,
                }
              })
          .toList();
    } else {
      final response = await File(requestPath).readAsBytes();
      final headers = {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition':
            'attachment; filename=${path.basename(requestPath)}'
      };
      return Response(body: response, headers: headers);
    }
  });

  apiServer.post('/delete', (ctx) async {
    try {
      await Directory((await ctx.bodyAsMap())?["path"]).delete();
      return Response(statusCode: HttpStatus.ok);
    } catch (e) {
      return Response(statusCode: HttpStatus.forbidden);
    }
  });
  await apiServer.serve();
}

startWebServer() async {
  final webServer = LocalAssetsServer(
      address: InternetAddress.anyIPv4,
      assetsBasePath: "web_file_manager",
      port: 1341);
  webServer
      .serve()
      .then((value) => Fluttertoast.showToast(msg: "server started"));
}

startServer() async {
  startApi();
  startWebServer();
}

stopServer() async {
  apiServer.close();
  webServer.stop();
}
