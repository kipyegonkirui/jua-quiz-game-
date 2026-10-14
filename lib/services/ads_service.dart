import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';
import 'supabase_service.dart';

class AdsService {
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    // Start warming up the first interstitial so it's ready after round one,
    // and the first rewarded video so hints / second chances are ready.
    AdCoordinator.preload();
    AdCoordinator.preloadRewarded();
  }
}

/// The ONE banner in the app. It lives in HomeShell (above the bottom nav) and
/// is hidden while a quiz is on screen, so it never sits next to answer
/// buttons (accidental taps are an AdMob policy problem). Loads on its own;
/// shrinks to nothing if the ad fails so it never leaves a broken-looking gap.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: AppConfig.admobBannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _bannerAd = null);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// What happened when the player was offered a rewarded video.
enum RewardedResult {
  /// Watched far enough to earn the reward.
  earned,

  /// The video was shown but closed early.
  notEarned,

  /// No video could be shown (not loaded, offline, another ad on screen...).
  unavailable,
}

/// Runs the "an interstitial after every round" rule — daily or practice —
/// and also owns the rewarded video used for hints and second chances, so
/// there is ONE place that knows whether a full-screen ad is on screen.
///
/// How it works:
///  1. [preload] keeps the next interstitial loaded (and reloads after each
///     one is shown, so round #2, #3, #4... all get one too).
///  2. When a round finishes, the screen calls [roundFinished]. That marks an
///     ad as "owed" — it does NOT pop up on top of the results screen, so the
///     player always sees their score first.
///  3. The ad is shown at the next natural moment via [showPendingIfAny]:
///     tapping "Play another round", or leaving the tab (HomeShell does this).
///
/// Rules baked in:
///  - The very first round a player ever finishes is ad-free.
///  - An ad that's been owed for more than [_pendingTtl] is dropped, so a
///    stale ad never appears out of the blue much later.
///  - If no ad is loaded, nothing is shown and the player is never blocked.
class AdCoordinator {
  AdCoordinator._();

  static const _pendingTtl = Duration(minutes: 10);
  static const _showTimeout = Duration(seconds: 90);
  // Rewarded videos can run 30s+; don't cut the player off mid-video.
  static const _rewardedShowTimeout = Duration(minutes: 5);
  static const _maxRewardedLoadFailures = 4;

  static InterstitialAd? _ad;
  static bool _loading = false;
  static bool _pending = false;
  static DateTime? _pendingSince;
  static bool _checkedFirstRound = false;
  static bool _showing = false;

  static RewardedAd? _rewarded;
  static bool _rewardedLoading = false;
  static int _rewardedFailures = 0;

  /// True while a rewarded video is loaded and can be shown right now. The
  /// hint / second-chance buttons listen to this.
  static final ValueNotifier<bool> rewardedReady = ValueNotifier<bool>(false);

  /// True while a full-screen ad (interstitial or rewarded) is on screen. The App Open ad (a later phase)
  /// checks this so it never stacks on top of another ad.
  static bool get isShowingFullScreenAd => _showing;

  static void preload() {
    if (_ad != null || _loading) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: AppConfig.admobInterstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (_) {
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  /// Call right after a round's results are on screen (daily or practice).
  static Future<void> roundFinished() async {
    preload(); // make sure the next ad is warming up

    if (!_checkedFirstRound) {
      _checkedFirstRound = true;
      try {
        // Rounds ever finished, including the one that just ended.
        final p = await SupabaseService.instance.getMyProfile();
        if (p.totalAttempts + p.practiceRounds <= 1) return; // first round ever: no ad
      } catch (_) {
        // Couldn't tell — fall through and treat it as a normal round.
      }
    }

    _pending = true;
    _pendingSince = DateTime.now();
  }

  /// Shows the owed ad if there is one and it's loaded; completes once the
  /// player has closed it (or straight away if there's nothing to show).
  static Future<void> showPendingIfAny() async {
    if (_showing) return; // never stack on another full-screen ad; it stays owed
    if (!_pending) return;
    _pending = false;
    final since = _pendingSince;
    _pendingSince = null;
    if (since == null || DateTime.now().difference(since) > _pendingTtl) return;

    final ad = _ad;
    if (ad == null) {
      preload();
      return; // no ad ready: skip rather than make the player wait
    }
    _ad = null;

    final closed = Completer<void>();
    void finish(InterstitialAd a) {
      _showing = false;
      a.dispose();
      preload(); // line up the next one
      if (!closed.isCompleted) closed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _showing = true;
      },
      onAdDismissedFullScreenContent: finish,
      onAdFailedToShowFullScreenContent: (a, _) => finish(a),
    );

    try {
      await ad.show();
    } catch (_) {
      finish(ad);
      return;
    }
    // Belt and braces: never leave the player stuck if a callback is missed.
    await closed.future.timeout(_showTimeout, onTimeout: () {
      _showing = false;
    });
  }

  // -------------------------------------------------------------- Rewarded --

  /// Keeps one rewarded video loaded. Safe to call any time (screens call it
  /// when a question appears). If loading fails it retries a few times with a
  /// growing pause, then waits for the next call — it never loops forever
  /// while offline.
  static void preloadRewarded() {
    if (_rewarded != null || _rewardedLoading) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: AppConfig.admobRewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _rewardedLoading = false;
          _rewardedFailures = 0;
          rewardedReady.value = true;
        },
        onAdFailedToLoad: (_) {
          _rewarded = null;
          _rewardedLoading = false;
          rewardedReady.value = false;
          if (_rewardedFailures < _maxRewardedLoadFailures) {
            _rewardedFailures++;
            Timer(Duration(seconds: 15 * _rewardedFailures), preloadRewarded);
          }
        },
      ),
    );
  }

  /// Shows a rewarded video and reports whether the reward was earned. Never
  /// throws: any problem comes back as [RewardedResult.unavailable] so the
  /// caller can carry on with the game.
  static Future<RewardedResult> showRewarded() async {
    if (_showing) return RewardedResult.unavailable;
    final ad = _rewarded;
    if (ad == null) {
      preloadRewarded();
      return RewardedResult.unavailable;
    }
    _rewarded = null;
    rewardedReady.value = false;
    _showing = true; // claim the slot immediately so nothing else can start

    var earned = false;
    var failedToShow = false;
    final closed = Completer<void>();
    void finish(RewardedAd a) {
      _showing = false;
      a.dispose();
      preloadRewarded(); // line up the next one
      if (!closed.isCompleted) closed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _showing = true;
      },
      onAdDismissedFullScreenContent: finish,
      onAdFailedToShowFullScreenContent: (a, _) {
        failedToShow = true;
        finish(a);
      },
    );

    try {
      await ad.show(onUserEarnedReward: (_, _) {
        earned = true;
      });
    } catch (_) {
      finish(ad);
      return RewardedResult.unavailable;
    }
    await closed.future.timeout(_rewardedShowTimeout, onTimeout: () {
      _showing = false;
    });
    if (failedToShow) return RewardedResult.unavailable;
    return earned ? RewardedResult.earned : RewardedResult.notEarned;
  }
}
