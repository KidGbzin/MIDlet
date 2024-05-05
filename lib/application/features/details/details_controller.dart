part of '../details/details_handler.dart';

/// The [InheritedNotifier] for [Details] view.
class _Notifier extends InheritedNotifier<_Controller> {
  const _Notifier({
    required _Controller super.notifier,
    required super.child,
  });

  static _Controller? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_Notifier>()!.notifier;
}

/// The [Details] controller, used to manipulate states and operations.
class _Controller extends ChangeNotifier implements IController {
  final AudioPlayer player;
  final String title;

  late Game game;
  late States state;

  /// The [_Controller] constructor. After create a instance make sure to [initialize] it.
  ///
  /// The parameter [player] is the controller that handle the soundtrack. It is of type [AudioPlayer]. \
  /// The parameter [title] is self-explanatory, just the game's title. It is of type [String].
  _Controller({
    required this.player,
    required this.title,
  });

  /// Initialize the [_Controller] by feching the game's data from [Repository] repository using it's title as key. \
  /// Update the [state] based on whether the game was found [States.finished] or not [States.error].
  @override
  Future<void> initialize() async {
    state = States.loading;
    try {
      game = Repository.collection.firstWhere((element) => element.title == title);
      _playSoundtrack();
      state = States.finished;
    }
    catch (_) {
      Logger.error.log('Unable to find the game $title!');
      state = States.error;
    }
    notifyListeners();
  }

  /// Try to get the game's thumbnail from the cache repository by it's [title].
  /// Return the thumbnail bytes in [Uint8List] if exists or null if not.
  Uint8List? getThumbnail() {
    final String? thumbnail = Cache.thumbnails[title];
    if (thumbnail != null) {
      final Uint8List bytes = base64Decode(thumbnail);
      return bytes;
    }
    return null;
  }

  /// Install the .JAR file into the J2ME Loader emulator.
  /// If the emulator is not installed then redirect to it's page on the PlayStore or GitHub.
  Future<void> install(BuildContext context) async {
    try {
      // First check if the game has a recommended version to install, if not throws an exception.
      final JAR jar = game.jars.firstWhere((element) => element.isRecomended == true,
        orElse: () => throw "Sorry, there's no file to install yet. Please check another game.",
      );

      // If there is a recommended version, then download the file.
      final Response response = await GitHub.getJAR('$title/${jar.file}');
      if (response.statusCode == 401) throw "Sorry, the server runned out the requests, please try again later.";
      if (response.statusCode == 404) throw "Sorry, the $title file was not found!";

      final File file = await Android.write(response.bodyBytes, jar.file);

      // For last call a native Android channel to install the .JAR file into J2ME Loader emulator.
      const MethodChannel channel = MethodChannel('br.com.kidgbzin.j2me_loader/install');
      await channel.invokeMethod('openJarFile', file.path);
    }
    catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '$error',
          style: Typographies.body(Palette.elements).style,
        ),
      ));
    }
  }

  /// Play the audio using the game's [title] as a key. If the audio isn't found, tries to [_fetchSoundtrack] from source. \
  /// The audio file is of type .RTX.
  Future<void> _playSoundtrack() async {
    final String? soundtrack = Cache.soundtracks[game.title];
    if (soundtrack != null) {
      try {
        final Uint8List bytes = base64Decode(soundtrack);
        await player.play(BytesSource(bytes));
      }
      catch (_) {
        Logger.error.log('Unable to play "${game.title}" audio!');
      }
    }
    else {
      Logger.warning.log('The "${game.title}" audio is not cached, trying to download it...');
      _fetchSoundtrack();
    }
  }

  /// Fetch the .RTX from source then stores in the cache system.
  /// When the file is successfully downloaded also play the soundtrack.
  Future<void> _fetchSoundtrack() async {
    final String name = title.replaceAll(':', ' -');
    try {
      final Uint8List bytes = await GitHub.getFile('RTXs/$name.rtx');
      Cache.soundtracks.put(title, base64Encode(bytes));
      await player.play(BytesSource(bytes));
    }
    catch (_) {}
  }

  /// Dispose the [_Controller].
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}