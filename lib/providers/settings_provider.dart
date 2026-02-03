import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:spotiflac_android/models/settings.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';
import 'package:spotiflac_android/utils/logger.dart';

const _settingsKey = 'app_settings';
const _migrationVersionKey = 'settings_migration_version';
const _currentMigrationVersion = 1;
const _cloudPasswordKey = 'cloud_password';

class SettingsNotifier extends Notifier<AppSettings> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  AppSettings build() {
    _loadSettings();
    return const AppSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await _prefs;
    final json = prefs.getString(_settingsKey);
    if (json != null) {
      state = AppSettings.fromJson(jsonDecode(json));
      
      await _runMigrations(prefs);
    }

    await _loadCloudPassword(prefs);

    _applySpotifyCredentials();
    
    LogBuffer.loggingEnabled = state.enableLogging;
  }

  Future<void> _runMigrations(SharedPreferences prefs) async {
    final lastMigration = prefs.getInt(_migrationVersionKey) ?? 0;
    
    if (lastMigration < 1) {
      if (!state.useCustomSpotifyCredentials) {
        state = state.copyWith(metadataSource: 'deezer');
        await _saveSettings();
      }
    }
    
    if (lastMigration < _currentMigrationVersion) {
      await prefs.setInt(_migrationVersionKey, _currentMigrationVersion);
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await _prefs;
    final settingsToSave = state.copyWith(cloudPassword: '');
    await prefs.setString(_settingsKey, jsonEncode(settingsToSave.toJson()));
  }

  Future<void> _loadCloudPassword(SharedPreferences prefs) async {
    final storedPassword = await _secureStorage.read(key: _cloudPasswordKey);
    final prefsPassword = state.cloudPassword;

    if ((storedPassword == null || storedPassword.isEmpty) &&
        prefsPassword.isNotEmpty) {
      await _secureStorage.write(key: _cloudPasswordKey, value: prefsPassword);
    }

    final effectivePassword = (storedPassword != null && storedPassword.isNotEmpty)
        ? storedPassword
        : (prefsPassword.isNotEmpty ? prefsPassword : '');

    if (effectivePassword != state.cloudPassword) {
      state = state.copyWith(cloudPassword: effectivePassword);
    }

    if (prefsPassword.isNotEmpty) {
      await _saveSettings();
    }
  }

  Future<void> _storeCloudPassword(String password) async {
    if (password.isEmpty) {
      await _secureStorage.delete(key: _cloudPasswordKey);
    } else {
      await _secureStorage.write(key: _cloudPasswordKey, value: password);
    }
  }

  Future<void> _applySpotifyCredentials() async {
    if (state.spotifyClientId.isNotEmpty && 
        state.spotifyClientSecret.isNotEmpty) {
      await PlatformBridge.setSpotifyCredentials(
        state.spotifyClientId,
        state.spotifyClientSecret,
      );
    }
  }

  void setDefaultService(String service) {
    state = state.copyWith(defaultService: service);
    _saveSettings();
  }

  void setAudioQuality(String quality) {
    state = state.copyWith(audioQuality: quality);
    _saveSettings();
  }

  void setFilenameFormat(String format) {
    state = state.copyWith(filenameFormat: format);
    _saveSettings();
  }

  void setDownloadDirectory(String directory) {
    state = state.copyWith(downloadDirectory: directory);
    _saveSettings();
  }

  void setAutoFallback(bool enabled) {
    state = state.copyWith(autoFallback: enabled);
    _saveSettings();
  }

  void setEmbedLyrics(bool enabled) {
    state = state.copyWith(embedLyrics: enabled);
    _saveSettings();
  }

  void setLyricsMode(String mode) {
    if (mode == 'embed' || mode == 'external' || mode == 'both') {
      state = state.copyWith(lyricsMode: mode);
      _saveSettings();
    }
  }

  void setMaxQualityCover(bool enabled) {
    state = state.copyWith(maxQualityCover: enabled);
    _saveSettings();
  }

  void setFirstLaunchComplete() {
    state = state.copyWith(isFirstLaunch: false);
    _saveSettings();
  }

  void setConcurrentDownloads(int count) {
    final clamped = count.clamp(1, 3);
    state = state.copyWith(concurrentDownloads: clamped);
    _saveSettings();
  }

  void setCheckForUpdates(bool enabled) {
    state = state.copyWith(checkForUpdates: enabled);
    _saveSettings();
  }

  void setUpdateChannel(String channel) {
    state = state.copyWith(updateChannel: channel);
    _saveSettings();
  }

  void setHasSearchedBefore() {
    if (!state.hasSearchedBefore) {
      state = state.copyWith(hasSearchedBefore: true);
      _saveSettings();
    }
  }

  void setFolderOrganization(String organization) {
    state = state.copyWith(folderOrganization: organization);
    _saveSettings();
  }

  void setHistoryViewMode(String mode) {
    state = state.copyWith(historyViewMode: mode);
    _saveSettings();
  }

  void setHistoryFilterMode(String mode) {
    state = state.copyWith(historyFilterMode: mode);
    _saveSettings();
  }

  void setAskQualityBeforeDownload(bool enabled) {
    state = state.copyWith(askQualityBeforeDownload: enabled);
    _saveSettings();
  }

  void setSpotifyClientId(String clientId) {
    state = state.copyWith(spotifyClientId: clientId);
    _saveSettings();
  }

  void setSpotifyClientSecret(String clientSecret) {
    state = state.copyWith(spotifyClientSecret: clientSecret);
    _saveSettings();
  }

  void setSpotifyCredentials(String clientId, String clientSecret) {
    state = state.copyWith(
      spotifyClientId: clientId,
      spotifyClientSecret: clientSecret,
    );
    _saveSettings();
    _applySpotifyCredentials();
  }

  void clearSpotifyCredentials() {
    state = state.copyWith(
      spotifyClientId: '',
      spotifyClientSecret: '',
    );
    _saveSettings();
    _applySpotifyCredentials();
  }

  void setUseCustomSpotifyCredentials(bool enabled) {
    state = state.copyWith(useCustomSpotifyCredentials: enabled);
    _saveSettings();
    _applySpotifyCredentials();
  }

  void setMetadataSource(String source) {
    state = state.copyWith(metadataSource: source);
    _saveSettings();
  }

  void setSearchProvider(String? provider) {
    if (provider == null || provider.isEmpty) {
      state = state.copyWith(clearSearchProvider: true);
    } else {
      state = state.copyWith(searchProvider: provider);
    }
    _saveSettings();
  }

  void setEnableLogging(bool enabled) {
    state = state.copyWith(enableLogging: enabled);
    _saveSettings();
    LogBuffer.loggingEnabled = enabled;
  }

  void setUseExtensionProviders(bool enabled) {
    state = state.copyWith(useExtensionProviders: enabled);
    _saveSettings();
  }

  void setSeparateSingles(bool enabled) {
    state = state.copyWith(separateSingles: enabled);
    _saveSettings();
  }

  void setAlbumFolderStructure(String structure) {
    state = state.copyWith(albumFolderStructure: structure);
    _saveSettings();
  }

  void setShowExtensionStore(bool enabled) {
    state = state.copyWith(showExtensionStore: enabled);
    _saveSettings();
  }

  void setLocale(String locale) {
    state = state.copyWith(locale: locale);
    _saveSettings();
  }

  void setTidalHighFormat(String format) {
    state = state.copyWith(tidalHighFormat: format);
    _saveSettings();
  }

void setUseAllFilesAccess(bool enabled) {
    state = state.copyWith(useAllFilesAccess: enabled);
    _saveSettings();
  }

  void setAutoExportFailedDownloads(bool enabled) {
    state = state.copyWith(autoExportFailedDownloads: enabled);
    _saveSettings();
  }

  void setDownloadNetworkMode(String mode) {
    state = state.copyWith(downloadNetworkMode: mode);
    _saveSettings();
  }

  // Cloud Upload Settings
  void setCloudUploadEnabled(bool enabled) {
    state = state.copyWith(cloudUploadEnabled: enabled);
    _saveSettings();
  }

  void setCloudProvider(String provider) {
    state = state.copyWith(cloudProvider: provider);
    _saveSettings();
  }

  void setCloudServerUrl(String url) {
    state = state.copyWith(cloudServerUrl: url);
    _saveSettings();
  }

  void setCloudUsername(String username) {
    state = state.copyWith(cloudUsername: username);
    _saveSettings();
  }

  Future<void> setCloudPassword(String password) async {
    state = state.copyWith(cloudPassword: password);
    await _storeCloudPassword(password);
    _saveSettings();
  }

  void setCloudRemotePath(String path) {
    state = state.copyWith(cloudRemotePath: path);
    _saveSettings();
  }

  Future<void> setCloudSettings({
    bool? enabled,
    String? provider,
    String? serverUrl,
    String? username,
    String? password,
    String? remotePath,
  }) async {
    final nextPassword = password ?? state.cloudPassword;
    state = state.copyWith(
      cloudUploadEnabled: enabled ?? state.cloudUploadEnabled,
      cloudProvider: provider ?? state.cloudProvider,
      cloudServerUrl: serverUrl ?? state.cloudServerUrl,
      cloudUsername: username ?? state.cloudUsername,
      cloudPassword: nextPassword,
      cloudRemotePath: remotePath ?? state.cloudRemotePath,
    );
    if (password != null) {
      await _storeCloudPassword(nextPassword);
    }
    _saveSettings();
  }

  // Local Library Settings
  void setLocalLibraryEnabled(bool enabled) {
    state = state.copyWith(localLibraryEnabled: enabled);
    _saveSettings();
  }

  void setLocalLibraryPath(String path) {
    state = state.copyWith(localLibraryPath: path);
    _saveSettings();
  }

  void setLocalLibraryShowDuplicates(bool show) {
    state = state.copyWith(localLibraryShowDuplicates: show);
    _saveSettings();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
