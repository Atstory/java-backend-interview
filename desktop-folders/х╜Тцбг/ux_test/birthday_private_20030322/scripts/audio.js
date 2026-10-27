(function initializeBirthdayAudio(windowObject) {
  function createAmbientAudioController(config) {
    const state = {
      audioStarted: false,
      audioMuted: true,
      audioContext: null,
      audioTimer: null
    };

    function ensureContext() {
      if (!state.audioStarted) {
        state.audioContext = new (windowObject.AudioContext || windowObject.webkitAudioContext)();
        state.audioStarted = true;
      }

      if (state.audioContext && state.audioContext.state === "suspended") {
        state.audioContext.resume();
      }
    }

    function playBellTone(frequency, startTime, duration, volume, oscillatorType) {
      const oscillator = state.audioContext.createOscillator();
      const gainNode = state.audioContext.createGain();
      const filterNode = state.audioContext.createBiquadFilter();

      oscillator.type = oscillatorType;
      oscillator.frequency.setValueAtTime(frequency, startTime);

      filterNode.type = "lowpass";
      filterNode.frequency.setValueAtTime(1800, startTime);

      gainNode.gain.setValueAtTime(0.0001, startTime);
      gainNode.gain.exponentialRampToValueAtTime(volume, startTime + 0.08);
      gainNode.gain.exponentialRampToValueAtTime(0.0001, startTime + duration);

      oscillator.connect(filterNode);
      filterNode.connect(gainNode);
      gainNode.connect(state.audioContext.destination);

      oscillator.start(startTime);
      oscillator.stop(startTime + duration);
    }

    function playAmbientChord() {
      if (!state.audioContext || state.audioMuted) {
        return;
      }

      const now = state.audioContext.currentTime;
      const baseFrequency = 196;
      const ratioA = config.pentatonicRatios[Math.floor(Math.random() * config.pentatonicRatios.length)];
      const ratioB = config.pentatonicRatios[Math.floor(Math.random() * config.pentatonicRatios.length)];

      playBellTone(baseFrequency * ratioA, now, 1.9, 0.06, "triangle");
      playBellTone(baseFrequency * ratioB * 2, now + 0.16, 1.3, 0.03, "sine");
      playBellTone(baseFrequency / 2, now, 2.4, 0.02, "sine");
    }

    function startLoop() {
      if (state.audioTimer) {
        return;
      }

      playAmbientChord();
      state.audioTimer = windowObject.setInterval(playAmbientChord, 2600);
    }

    function stopLoop() {
      if (!state.audioTimer) {
        return;
      }

      windowObject.clearInterval(state.audioTimer);
      state.audioTimer = null;
    }

    function setEnabled(shouldPlay) {
      ensureContext();

      if (shouldPlay) {
        state.audioMuted = false;
        startLoop();
      } else {
        state.audioMuted = true;
        stopLoop();
      }
    }

    function isPlaying() {
      return state.audioStarted && !state.audioMuted;
    }

    return {
      setEnabled,
      isPlaying
    };
  }

  windowObject.BirthdayAudio = {
    createAmbientAudioController
  };
}(window));
