part of 'settings_page.dart';

class AboutSettings extends StatefulWidget {
  const AboutSettings({super.key});

  @override
  State<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends State<AboutSettings> {
  bool isCheckingUpdate = false;

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("About".tl)),
        SizedBox(
          height: 112,
          width: double.infinity,
          child: Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(136),
              ),
              clipBehavior: Clip.antiAlias,
              child: const Image(
                image: AssetImage("assets/app_icon.png"),
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ).paddingTop(16).toSliver(),
        Column(
          children: [
            const SizedBox(height: 8),
            Text(
              "V${App.version}",
              style: const TextStyle(fontSize: 16),
            ),
            Text("Venera is a free and open-source app for comic reading.".tl),
            const SizedBox(height: 8),
          ],
        ).toSliver(),
        ListTile(
          title: Text("Check for updates".tl),
          trailing: Button.filled(
            isLoading: isCheckingUpdate,
            child: Text("Check".tl),
            onPressed: () {
              setState(() {
                isCheckingUpdate = true;
              });
              checkUpdateUi().then((value) {
                setState(() {
                  isCheckingUpdate = false;
                });
              });
            },
          ).fixHeight(32),
        ).toSliver(),
        _SwitchSetting(
          title: "Check for updates on startup".tl,
          settingKey: "checkUpdateOnStart",
        ).toSliver(),
        ListTile(
          title: const Text("Github"),
          trailing: const Icon(Icons.open_in_new),
          onTap: () {
            launchUrlString("https://github.com/SKYL1NE-34/venera");
          },
        ).toSliver(),
      ],
    );
  }
}

Future<bool> checkUpdate() async {
  var res = await AppDio()
      .get("https://cdn.jsdelivr.net/gh/SKYL1NE-34/venera@master/pubspec.yaml");
  if (res.statusCode == 200) {
    var data = loadYaml(res.data);
    if (data["version"] != null) {
      var parts = data["version"].toString().split("+");
      var remoteVersion = parts[0];
      var remoteBuild = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      if (_compareVersion(remoteVersion, App.version)) {
        return true;
      }
      if (remoteVersion == App.version &&
          remoteBuild > (int.tryParse(App.buildNumber) ?? 0)) {
        return true;
      }
    }
  }
  return false;
}

Future<void> checkUpdateUi([bool showMessageIfNoUpdate = true, bool delay = false]) async {
  try {
    var value = await checkUpdate();
    if (value) {
      if (delay) {
        await Future.delayed(const Duration(seconds: 2));
      }
      showDialog(
          context: App.rootContext,
          builder: (context) {
            return ContentDialog(
              title: "New version available".tl,
              content: Text(
                      "A new version is available. Do you want to update now?"
                          .tl)
                  .paddingHorizontal(16),
              actions: [
                Button.text(
                  onPressed: () {
                    Navigator.pop(context);
                    launchUrlString(
                        "https://github.com/SKYL1NE-34/venera/releases");
                  },
                  child: Text("Update".tl),
                ),
              ],
            );
          });
    } else if (showMessageIfNoUpdate) {
      App.rootContext.showMessage(message: "No new version available".tl);
    }
  } catch (e, s) {
    Log.error("Check Update", e.toString(), s);
  }
}

/// return true if version1 > version2
bool _compareVersion(String version1, String version2) {
  var v1 = version1.split(".");
  var v2 = version2.split(".");
  var length = v1.length > v2.length ? v1.length : v2.length;
  for (var i = 0; i < length; i++) {
    var n1 = i < v1.length ? int.tryParse(v1[i]) ?? 0 : 0;
    var n2 = i < v2.length ? int.tryParse(v2[i]) ?? 0 : 0;
    if (n1 > n2) {
      return true;
    }
    if (n1 < n2) {
      return false;
    }
  }
  return false;
}
