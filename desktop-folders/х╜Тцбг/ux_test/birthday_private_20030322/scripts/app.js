(function initializeBirthdayApp(windowObject) {
  const config = windowObject.BIRTHDAY_APP_CONFIG;

  document.addEventListener("DOMContentLoaded", bootstrapBirthdaySite);

  function bootstrapBirthdaySite() {
    const dom = collectDomNodes();
    if (!dom.root) {
      return;
    }

    const introVariant = windowObject.BirthdayEffects.pickIntroVariant(config.introVariants);
    const audioController = windowObject.BirthdayAudio.createAmbientAudioController(config);

    dom.root.dataset.introVariant = introVariant;
    dom.root.dataset.ready = "1";

    windowObject.BirthdayEffects.createStarfield(dom.starCanvas, {
      reduceMotion: config.reduceMotion,
      variant: introVariant
    });

    windowObject.BirthdayEffects.setupRevealAnimations(config.reduceMotion);
    windowObject.BirthdayEffects.setupScrollScene(config.reduceMotion);

    bindIntroEvents(dom, introVariant, audioController);
    bindCandleEvents(dom, audioController);
    bindWishEvents(dom);
    bindPanelEvents(dom);
    syncOpenPanels(dom.hiddenPanels);

    windowObject.addEventListener("resize", () => syncOpenPanels(dom.hiddenPanels));
  }

  function collectDomNodes() {
    return {
      root: document.body,
      starCanvas: document.getElementById("starCanvas"),
      introOverlay: document.getElementById("introOverlay"),
      musicToggleButton: document.getElementById("musicToggleButton"),
      enterRiteButton: document.getElementById("enterRiteButton"),
      skipMusicButton: document.getElementById("skipMusicButton"),
      igniteHeroButton: document.getElementById("igniteHeroButton"),
      ritualIgniteButton: document.getElementById("ritualIgniteButton"),
      revealHeroButton: document.getElementById("revealHeroButton"),
      ritualWishButton: document.getElementById("ritualWishButton"),
      toggleDestinyButton: document.getElementById("toggleDestinyButton"),
      heroCandle: document.getElementById("heroCandle"),
      destinyPanel: document.getElementById("destinyPanel"),
      wishForm: document.getElementById("wishForm"),
      wishInput: document.getElementById("wishInput"),
      wishOutput: document.getElementById("wishOutput"),
      statusText: document.getElementById("statusText"),
      hiddenPanels: Array.from(document.querySelectorAll(".hidden-panel"))
    };
  }

  function bindIntroEvents(dom, introVariant, audioController) {
    dom.enterRiteButton.addEventListener("click", () => {
      audioController.setEnabled(true);
      updateMusicButton(dom.musicToggleButton, audioController);
      hideIntroOverlay(dom.introOverlay, introVariant);
      windowObject.BirthdayEffects.playHeroEntrance(introVariant, config.reduceMotion);
    });

    dom.skipMusicButton.addEventListener("click", () => {
      audioController.setEnabled(false);
      updateMusicButton(dom.musicToggleButton, audioController);
      hideIntroOverlay(dom.introOverlay, introVariant);
      windowObject.BirthdayEffects.playHeroEntrance(introVariant, config.reduceMotion);
    });

    dom.musicToggleButton.addEventListener("click", () => {
      audioController.setEnabled(!audioController.isPlaying());
      updateMusicButton(dom.musicToggleButton, audioController);
    });
  }

  function bindCandleEvents(dom, audioController) {
    const igniteButtons = [dom.igniteHeroButton, dom.ritualIgniteButton];
    const revealButtons = [dom.revealHeroButton, dom.toggleDestinyButton];

    igniteButtons.forEach((button) => {
      button.addEventListener("click", () => {
        igniteCandle(dom.heroCandle, dom.statusText, true);
        audioController.setEnabled(true);
        updateMusicButton(dom.musicToggleButton, audioController);
      });
    });

    revealButtons.forEach((button) => {
      button.addEventListener("click", () => {
        togglePanel(dom.destinyPanel, true);
        document.getElementById("destiny").scrollIntoView({
          behavior: config.reduceMotion ? "auto" : "smooth"
        });
      });
    });

    dom.ritualWishButton.addEventListener("click", () => {
      document.getElementById("wish").scrollIntoView({
        behavior: config.reduceMotion ? "auto" : "smooth"
      });
    });
  }

  function bindWishEvents(dom) {
    dom.wishForm.addEventListener("submit", (event) => {
      event.preventDefault();

      const wish = dom.wishInput.value.trim();
      const isCandleLit = dom.heroCandle.classList.contains("is-lit");

      if (!isCandleLit) {
        dom.statusText.textContent = "先点亮长烛，再把愿望交给今晚。";
        igniteCandle(dom.heroCandle, dom.statusText, false);
        return;
      }

      if (!wish) {
        dom.statusText.textContent = "愿望还没写下。可以短，但要真。";
        dom.wishInput.focus();
        return;
      }

      const template = config.wishTemplates[Math.floor(Math.random() * config.wishTemplates.length)];
      const renderedWish = template.replace("{wish}", wish);

      dom.wishOutput.innerHTML = "<strong>心愿已封存。</strong><br>" + renderedWish + "<br><br>生日快乐。愿你这一岁，既有光，也有稳。";
      dom.statusText.textContent = "今夜的火已经记住这句话了。";

      if (!config.reduceMotion) {
        windowObject.BirthdayEffects.celebrate(config.confettiColors);
      }
    });
  }

  function bindPanelEvents(dom) {
    document.querySelectorAll("[data-target]").forEach((button) => {
      button.addEventListener("click", () => {
        const panel = document.getElementById(button.getAttribute("data-target"));
        const shouldOpen = !panel.classList.contains("is-open");
        togglePanel(panel, shouldOpen);
        button.textContent = shouldOpen ? "收起此卷" : "开启此卷";
      });
    });
  }

  function hideIntroOverlay(introOverlay, introVariant) {
    introOverlay.dataset.exitVariant = introVariant;
    introOverlay.classList.add("is-hidden");
    introOverlay.setAttribute("aria-hidden", "true");
  }

  function updateMusicButton(musicToggleButton, audioController) {
    const isPlaying = audioController.isPlaying();
    musicToggleButton.setAttribute("aria-pressed", String(isPlaying));
    musicToggleButton.textContent = isPlaying ? "东方器乐感 · 已开启" : "东方器乐感 · 已静音";
  }

  function igniteCandle(heroCandle, statusText, shouldCelebrate) {
    if (!heroCandle.classList.contains("is-lit")) {
      heroCandle.classList.add("is-lit");
      statusText.textContent = "长烛已点亮。今晚更适合把愿望说给自己听。";
    }

    if (shouldCelebrate && !config.reduceMotion) {
      windowObject.BirthdayEffects.celebrate(config.confettiColors);
    }
  }

  // 面板展开改为按内容真实高度计算，避免长文本被固定高度截断。
  function togglePanel(panel, shouldOpen) {
    panel.classList.toggle("is-open", shouldOpen);
    panel.style.maxHeight = shouldOpen ? panel.scrollHeight + "px" : "0px";
  }

  function syncOpenPanels(hiddenPanels) {
    hiddenPanels.forEach((panel) => {
      if (!panel.classList.contains("is-open")) {
        panel.style.maxHeight = "0px";
        return;
      }

      panel.style.maxHeight = panel.scrollHeight + "px";
    });
  }
}(window));
