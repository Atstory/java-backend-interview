(function initializeBirthdayEffects(windowObject) {
  function pickIntroVariant(introVariants) {
    return introVariants[Math.floor(Math.random() * introVariants.length)];
  }

  function createStarfield(canvas, options) {
    const context = canvas.getContext("2d");
    const particles = [];
    const ratio = Math.min(windowObject.devicePixelRatio || 1, 2);
    const count = options.reduceMotion ? 28 : 84;
    const variantSpeedMap = {
      veil: 0.26,
      eclipse: 0.34,
      embers: 0.42,
      oracle: 0.2
    };
    const speedBoost = variantSpeedMap[options.variant] || 0.3;

    function resizeCanvas() {
      canvas.width = Math.floor(windowObject.innerWidth * ratio);
      canvas.height = Math.floor(windowObject.innerHeight * ratio);
      canvas.style.width = windowObject.innerWidth + "px";
      canvas.style.height = windowObject.innerHeight + "px";
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
    }

    function resetParticles() {
      particles.length = 0;
      for (let index = 0; index < count; index += 1) {
        particles.push({
          x: Math.random() * windowObject.innerWidth,
          y: Math.random() * windowObject.innerHeight,
          radius: 0.6 + Math.random() * 2.1,
          speed: 0.06 + Math.random() * speedBoost,
          drift: (Math.random() - 0.5) * 0.18,
          alpha: 0.12 + Math.random() * 0.52
        });
      }
    }

    function drawFrame() {
      context.clearRect(0, 0, windowObject.innerWidth, windowObject.innerHeight);

      for (const particle of particles) {
        particle.y += particle.speed;
        particle.x += particle.drift;

        if (particle.y > windowObject.innerHeight + 16) {
          particle.y = -10;
          particle.x = Math.random() * windowObject.innerWidth;
        }

        if (particle.x < -12) {
          particle.x = windowObject.innerWidth + 12;
        }

        if (particle.x > windowObject.innerWidth + 12) {
          particle.x = -12;
        }

        context.beginPath();
        context.fillStyle = "rgba(240,223,183," + particle.alpha + ")";
        context.arc(particle.x, particle.y, particle.radius, 0, Math.PI * 2);
        context.fill();

        context.beginPath();
        context.strokeStyle = "rgba(217,172,87," + (particle.alpha * 0.13) + ")";
        context.moveTo(particle.x, particle.y - particle.speed * 14);
        context.lineTo(particle.x, particle.y + particle.speed * 10);
        context.stroke();
      }

      if (!options.reduceMotion) {
        windowObject.requestAnimationFrame(drawFrame);
      }
    }

    resizeCanvas();
    resetParticles();
    drawFrame();

    windowObject.addEventListener("resize", () => {
      resizeCanvas();
      resetParticles();
      if (options.reduceMotion) {
        drawFrame();
      }
    });
  }

  function setupRevealAnimations(reduceMotion) {
    const nodes = Array.from(document.querySelectorAll(".reveal"));

    if (windowObject.gsap && windowObject.ScrollTrigger && !reduceMotion) {
      nodes.forEach((node) => {
        windowObject.gsap.fromTo(node, { autoAlpha: 0, y: 36 }, {
          autoAlpha: 1,
          y: 0,
          duration: 0.9,
          ease: "power3.out",
          scrollTrigger: {
            trigger: node,
            start: "top 84%"
          }
        });
      });
      return;
    }

    const observer = new IntersectionObserver((entries, currentObserver) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) {
          return;
        }

        entry.target.classList.add("is-visible");
        currentObserver.unobserve(entry.target);
      });
    }, { threshold: 0.12 });

    nodes.forEach((node) => observer.observe(node));
  }

  function setupScrollScene(reduceMotion) {
    if (!(windowObject.gsap && windowObject.ScrollTrigger) || reduceMotion) {
      return;
    }

    windowObject.gsap.registerPlugin(windowObject.ScrollTrigger);

    windowObject.gsap.to(".panel--hero", {
      y: -28,
      ease: "none",
      scrollTrigger: {
        trigger: ".section--hero",
        start: "top top",
        end: "bottom top",
        scrub: true
      }
    });

    windowObject.gsap.to(".ritual-wheel", {
      rotate: 16,
      scrollTrigger: {
        trigger: ".section--hero",
        start: "top top",
        end: "bottom top",
        scrub: true
      }
    });
  }

  function playHeroEntrance(variant, reduceMotion) {
    const heroPanel = document.querySelector(".panel--hero");
    const ritualPanel = document.querySelector(".panel--ritual");
    const header = document.querySelector(".site-header");

    if (!heroPanel || !ritualPanel || reduceMotion || !windowObject.gsap) {
      return;
    }

    const variants = {
      veil: [
        { target: header, from: { autoAlpha: 0, y: -28 }, to: { autoAlpha: 1, y: 0 } },
        { target: heroPanel, from: { autoAlpha: 0, y: 72 }, to: { autoAlpha: 1, y: 0 } },
        { target: ritualPanel, from: { autoAlpha: 0, y: 96 }, to: { autoAlpha: 1, y: 0 } }
      ],
      eclipse: [
        { target: header, from: { autoAlpha: 0, scale: 0.96 }, to: { autoAlpha: 1, scale: 1 } },
        { target: heroPanel, from: { autoAlpha: 0, x: -88 }, to: { autoAlpha: 1, x: 0 } },
        { target: ritualPanel, from: { autoAlpha: 0, x: 88 }, to: { autoAlpha: 1, x: 0 } }
      ],
      embers: [
        { target: header, from: { autoAlpha: 0, y: -18 }, to: { autoAlpha: 1, y: 0 } },
        { target: heroPanel, from: { autoAlpha: 0, scale: 0.92, rotate: -2 }, to: { autoAlpha: 1, scale: 1, rotate: 0 } },
        { target: ritualPanel, from: { autoAlpha: 0, scale: 0.9, rotate: 2 }, to: { autoAlpha: 1, scale: 1, rotate: 0 } }
      ],
      oracle: [
        { target: header, from: { autoAlpha: 0, y: -24 }, to: { autoAlpha: 1, y: 0 } },
        { target: heroPanel, from: { autoAlpha: 0, x: -44, y: 34 }, to: { autoAlpha: 1, x: 0, y: 0 } },
        { target: ritualPanel, from: { autoAlpha: 0, x: 44, y: 34 }, to: { autoAlpha: 1, x: 0, y: 0 } }
      ]
    };

    const selectedSequence = variants[variant] || variants.veil;
    const timeline = windowObject.gsap.timeline({ defaults: { duration: 0.9, ease: "power3.out" } });

    selectedSequence.forEach((item, index) => {
      timeline.fromTo(item.target, item.from, item.to, index === 0 ? 0 : "-=0.55");
    });
  }

  function celebrate(colors) {
    if (!windowObject.confetti) {
      return;
    }

    const defaults = {
      particleCount: 55,
      spread: 78,
      startVelocity: 28,
      scalar: 0.9,
      colors,
      origin: { y: 0.62 }
    };

    windowObject.confetti({ ...defaults, angle: 65, origin: { x: 0.25, y: 0.62 } });
    windowObject.confetti({ ...defaults, angle: 115, origin: { x: 0.75, y: 0.62 } });
  }

  windowObject.BirthdayEffects = {
    pickIntroVariant,
    createStarfield,
    setupRevealAnimations,
    setupScrollScene,
    playHeroEntrance,
    celebrate
  };
}(window));
