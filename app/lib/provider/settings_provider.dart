import 'package:collection/collection.dart';
import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/model/persistence/color_mode.dart';
import 'package:dropit_app/model/persistence/glass_quality.dart';
import 'package:dropit_app/model/persistence/quick_save_mode.dart';
import 'package:dropit_app/model/send_mode.dart';
import 'package:dropit_app/model/state/settings_state.dart';
import 'package:dropit_app/provider/persistence_provider.dart';
import 'package:dropit_isolates/isolate.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _listEq = const ListEquality().equals;

final settingsProvider = NotifierProvider<SettingsService, SettingsState>(
  (ref) {
    return SettingsService(ref.read(persistenceProvider));
  },
  onChanged: (_, next, ref) {
    final syncState = ref.read(parentIsolateProvider).syncState;
    if (_listEq(syncState.networkWhitelist, next.networkWhitelist) &&
        _listEq(syncState.networkBlacklist, next.networkBlacklist) &&
        syncState.multicastGroup == next.multicastGroup &&
        syncState.discoveryTimeout == next.discoveryTimeout) {
      return;
    }

    ref
        .redux(parentIsolateProvider)
        .dispatch(
          IsolateSyncSettingsAction(
            networkWhitelist: next.networkWhitelist,
            networkBlacklist: next.networkBlacklist,
            multicastGroup: next.multicastGroup,
            discoveryTimeout: next.discoveryTimeout,
          ),
        );
  },
);

class SettingsService extends PureNotifier<SettingsState> {
  final PersistenceService _persistence;

  SettingsService(this._persistence);

  @override
  SettingsState init() {
    final storedClarity = _persistence.getGlassClarity();
    final storedFrost = _persistence.getGlassFrost();
    final storedRefraction = _persistence.getRefractionIntensity();
    final storedDispersion = _persistence.getGlassDispersion();
    return SettingsState(
      showToken: _persistence.getShowToken(),
      alias: _persistence.getAlias(),
      theme: _persistence.getTheme(),
      colorMode: _persistence.getColorMode(),
      customColor: _persistence.getCustomColor(),
      locale: _persistence.getLocale(),
      port: _persistence.getPort(),
      networkWhitelist: _persistence.getNetworkWhitelist(),
      networkBlacklist: _persistence.getNetworkBlacklist(),
      multicastGroup: _persistence.getMulticastGroup(),
      destination: _persistence.getDestination(),
      saveToGallery: _persistence.isSaveToGallery(),
      saveToHistory: _persistence.isSaveToHistory(),
      quickSave: _persistence.getQuickSave() == QuickSaveMode.on,
      quickSaveFromFavorites: _persistence.getQuickSave() == QuickSaveMode.paired,
      receivePin: _persistence.getReceivePin(),
      autoFinish: _persistence.isAutoFinish(),
      minimizeToTray: _persistence.isMinimizeToTray(),
      https: _persistence.isHttps(),
      sendMode: _persistence.getSendMode(),
      saveWindowPlacement: _persistence.getSaveWindowPlacement(),
      enableAnimations: _persistence.getEnableAnimations(),
      deviceType: _persistence.getDeviceType(),
      deviceModel: _persistence.getDeviceModel(),
      shareViaLinkAutoAccept: _persistence.getShareViaLinkAutoAccept(),
      receiveViaLinkAutoAccept: _persistence.getReceiveViaLinkAutoAccept(),
      createChecksums: _persistence.getCreateChecksums(),
      verifyChecksums: _persistence.getVerifyChecksums(),
      discoveryTimeout: _persistence.getDiscoveryTimeout(),
      advancedSettings: _persistence.getAdvancedSettingsEnabled(),
      glassQuality: _persistence.getGlassQuality() ?? AppGlassQuality.liquid,
      glassClarity: (storedClarity != null && storedClarity.isFinite ? storedClarity : 0.90).clamp(0.0, 1.0),
      glassFrost: (storedFrost != null && storedFrost.isFinite ? storedFrost : 0.0).clamp(0.0, 1.0),
      refractionIntensity: (storedRefraction != null && storedRefraction.isFinite ? storedRefraction : 1.50).clamp(0.0, 2.0),
      glassDispersion: (storedDispersion != null && storedDispersion.isFinite ? storedDispersion : 1.32).clamp(0.0, 12.0),
      deepEdgeTintEnabled: _persistence.getDeepEdgeTintEnabled() ?? false,
      allGlassTintEnabled: _persistence.getAllGlassTintEnabled() ?? false,
      deepEdgeTintColor: _persistence.getDeepEdgeTintColor() ?? const Color(0xFF0A84FF),
      glassOutlines: _persistence.getGlassOutlines() ?? true,
      backgroundAnimation: _persistence.getBackgroundAnimation() ?? true,
    );
  }

  Future<void> setAlias(String alias) async {
    await _persistence.setAlias(alias);
    state = state.copyWith(
      alias: alias,
    );
  }

  Future<void> setSystemAlias(String alias) async {
    await _persistence.setSystemAlias(alias);
    state = state.copyWith(
      alias: alias,
    );
  }

  Future<void> setTheme(ThemeMode theme) async {
    await _persistence.setTheme(theme);
    state = state.copyWith(
      theme: theme,
    );
  }

  Future<void> setColorMode(ColorMode mode) async {
    await _persistence.setColorMode(mode);
    state = state.copyWith(
      colorMode: mode,
    );
  }

  Future<void> setCustomColor(Color color) async {
    await _persistence.setCustomColor(color);
    state = state.copyWith(
      customColor: color,
    );
  }

  Future<void> setAdvancedSettingsEnabled(bool isEnabled) async {
    await _persistence.setAdvancedSettingsEnabled(isEnabled);
    state = state.copyWith(
      advancedSettings: isEnabled,
    );
  }

  Future<void> setLocale(AppLocale? locale) async {
    await _persistence.setLocale(locale);
    state = state.copyWith(
      locale: locale,
    );
  }

  Future<void> setPort(int port) async {
    await _persistence.setPort(port);
    state = state.copyWith(
      port: port,
    );
  }

  Future<void> setNetworkWhitelist(List<String>? whitelist) async {
    await _persistence.setNetworkWhitelist(whitelist);
    state = state.copyWith(
      networkWhitelist: whitelist,
    );
  }

  Future<void> setNetworkBlacklist(List<String>? blacklist) async {
    await _persistence.setNetworkBlacklist(blacklist);
    state = state.copyWith(
      networkBlacklist: blacklist,
    );
  }

  Future<void> setDiscoveryTimeout(int timeout) async {
    await _persistence.setDiscoveryTimeout(timeout);
    state = state.copyWith(
      discoveryTimeout: timeout,
    );
  }

  Future<void> setMulticastGroup(String group) async {
    await _persistence.setMulticastGroup(group);
    state = state.copyWith(
      multicastGroup: group,
    );
  }

  Future<void> setDestination(String? destination) async {
    await _persistence.setDestination(destination);
    state = state.copyWith(
      destination: destination,
    );
  }

  Future<void> setSaveToGallery(bool saveToGallery) async {
    await _persistence.setSaveToGallery(saveToGallery);
    state = state.copyWith(
      saveToGallery: saveToGallery,
    );
  }

  Future<void> setSaveToHistory(bool saveToHistory) async {
    await _persistence.setSaveToHistory(saveToHistory);
    state = state.copyWith(
      saveToHistory: saveToHistory,
    );
  }

  Future<void> setQuickSave(bool quickSave) async {
    final old = _persistence.getQuickSave();
    final QuickSaveMode mode;
    if (quickSave) {
      mode = QuickSaveMode.on;
    } else {
      mode = old == QuickSaveMode.on ? QuickSaveMode.off : old;
    }
    await _setQuickSaveMode(mode);
  }

  Future<void> setQuickSaveFromFavorites(bool quickSaveFromFavorites) async {
    final old = _persistence.getQuickSave();
    final QuickSaveMode mode;
    if (quickSaveFromFavorites) {
      mode = QuickSaveMode.paired;
    } else {
      mode = old == QuickSaveMode.paired ? QuickSaveMode.off : old;
    }
    await _setQuickSaveMode(mode);
  }

  Future<void> _setQuickSaveMode(QuickSaveMode mode) async {
    await _persistence.setQuickSave(mode);
    state = state.copyWith(
      quickSave: mode == QuickSaveMode.on,
      quickSaveFromFavorites: mode == QuickSaveMode.paired,
    );
  }

  Future<void> setReceivePin(String? receivePin) async {
    await _persistence.setReceivePin(receivePin);
    state = state.copyWith(
      receivePin: receivePin,
    );
  }

  Future<void> setAutoFinish(bool autoFinish) async {
    await _persistence.setAutoFinish(autoFinish);
    state = state.copyWith(
      autoFinish: autoFinish,
    );
  }

  Future<void> setMinimizeToTray(bool minimizeToTray) async {
    await _persistence.setMinimizeToTray(minimizeToTray);
    state = state.copyWith(
      minimizeToTray: minimizeToTray,
    );
  }

  Future<void> setHttps(bool https) async {
    await _persistence.setHttps(https);
    state = state.copyWith(
      https: https,
    );
  }

  Future<void> setSendMode(SendMode mode) async {
    await _persistence.setSendMode(mode);
    state = state.copyWith(
      sendMode: mode,
    );
  }

  Future<void> setSaveWindowPlacement(bool savePlacement) async {
    await _persistence.setSaveWindowPlacement(savePlacement);
    state = state.copyWith(
      saveWindowPlacement: savePlacement,
    );
  }

  Future<void> setEnableAnimations(bool enableAnimations) async {
    await _persistence.setEnableAnimations(enableAnimations);
    state = state.copyWith(
      enableAnimations: enableAnimations,
    );
  }

  Future<void> setDeviceType(DeviceType deviceType) async {
    await _persistence.setDeviceType(deviceType);
    state = state.copyWith(
      deviceType: deviceType,
    );
  }

  Future<void> setDeviceModel(String deviceModel) async {
    await _persistence.setDeviceModel(deviceModel);
    state = state.copyWith(
      deviceModel: deviceModel,
    );
  }

  Future<void> setShareViaLinkAutoAccept(bool shareViaLinkAutoAccept) async {
    await _persistence.setShareViaLinkAutoAccept(shareViaLinkAutoAccept);

    state = state.copyWith(
      shareViaLinkAutoAccept: shareViaLinkAutoAccept,
    );
  }

  Future<void> setReceiveViaLinkAutoAccept(bool receiveViaLinkAutoAccept) async {
    await _persistence.setReceiveViaLinkAutoAccept(receiveViaLinkAutoAccept);

    state = state.copyWith(
      receiveViaLinkAutoAccept: receiveViaLinkAutoAccept,
    );
  }

  Future<void> setCreateChecksums(bool createChecksums) async {
    await _persistence.setCreateChecksums(createChecksums);
    state = state.copyWith(
      createChecksums: createChecksums,
    );
  }

  Future<void> setVerifyChecksums(bool verifyChecksums) async {
    await _persistence.setVerifyChecksums(verifyChecksums);
    state = state.copyWith(
      verifyChecksums: verifyChecksums,
    );
  }

  Future<void> setGlassQuality(AppGlassQuality quality) async {
    await _persistence.setGlassQuality(quality);
    state = state.copyWith(
      glassQuality: quality,
    );
  }

  Future<void> setGlassClarity(double clarity) async {
    final clamped = clarity.clamp(0.0, 1.0);
    await _persistence.setGlassClarity(clamped);
    state = state.copyWith(
      glassClarity: clamped,
    );
  }

  Future<void> setGlassFrost(double frost) async {
    final clamped = frost.clamp(0.0, 1.0);
    await _persistence.setGlassFrost(clamped);
    state = state.copyWith(
      glassFrost: clamped,
    );
  }

  Future<void> setRefractionIntensity(double intensity) async {
    final clamped = intensity.clamp(0.0, 2.0);
    await _persistence.setRefractionIntensity(clamped);
    state = state.copyWith(
      refractionIntensity: clamped,
    );
  }

  Future<void> setGlassDispersion(double dispersion) async {
    final clamped = dispersion.clamp(0.0, 12.0);
    await _persistence.setGlassDispersion(clamped);
    state = state.copyWith(
      glassDispersion: clamped,
    );
  }

  Future<void> setDeepEdgeTintEnabled(bool enabled) async {
    await _persistence.setDeepEdgeTintEnabled(enabled);
    state = state.copyWith(
      deepEdgeTintEnabled: enabled,
    );
  }

  Future<void> setAllGlassTintEnabled(bool enabled) async {
    await _persistence.setAllGlassTintEnabled(enabled);
    state = state.copyWith(
      allGlassTintEnabled: enabled,
    );
  }

  Future<void> setDeepEdgeTintColor(Color color) async {
    await _persistence.setDeepEdgeTintColor(color);
    state = state.copyWith(
      deepEdgeTintColor: color,
      deepEdgeTintEnabled: state.allGlassTintEnabled ? state.deepEdgeTintEnabled : true,
    );
  }

  Future<void> setGlassOutlines(bool outlines) async {
    await _persistence.setGlassOutlines(outlines);
    state = state.copyWith(
      glassOutlines: outlines,
    );
  }

  Future<void> setBackgroundAnimation(bool enabled) async {
    await _persistence.setBackgroundAnimation(enabled);
    state = state.copyWith(
      backgroundAnimation: enabled,
    );
  }
}
