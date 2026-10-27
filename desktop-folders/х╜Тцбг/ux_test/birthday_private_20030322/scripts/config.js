(function initializeBirthdayConfig(windowObject) {
  windowObject.BIRTHDAY_APP_CONFIG = {
    reduceMotion: window.matchMedia("(prefers-reduced-motion: reduce)").matches,
    introVariants: ["veil", "eclipse", "embers", "oracle"],
    confettiColors: ["#f0dfb7", "#d9ac57", "#d85a35", "#7f141d", "#f5ead2"],
    wishTemplates: [
      "今夜记下：{wish}。愿这句话不是一瞬间的热，而是一段时间里的光。",
      "已替你封存心愿：{wish}。从这一岁起，愿你把热烈活成可持续的力量。",
      "火已点亮，愿也落定：{wish}。愿你此后的每一次选择，都更接近真正想成为的人。"
    ],
    pentatonicRatios: [1, 1.125, 1.25, 1.5, 1.6875]
  };
}(window));
