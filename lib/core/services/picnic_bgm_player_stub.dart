/// Non-web stub for Collaborative Picnic Memory Game background music player.
class PicnicBgmPlayer {
  bool _isMuted = false;
  bool _isPlaying = false;

  bool get isMuted => _isMuted;
  bool get isPlaying => _isPlaying;

  void startBgm() {
    if (!_isMuted) _isPlaying = true;
  }

  void stopBgm() {
    _isPlaying = false;
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    if (muted) _isPlaying = false;
  }

  void playTapChime({double volume = 0.80}) {}

  void playVictoryChime({double volume = 0.88}) {}

  void dispose() {
    _isPlaying = false;
  }
}
