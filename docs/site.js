/* Theme switch, shared by every page.
   The choice lives in localStorage, which is per-origin, so it carries
   across all four pages and survives a reload. No choice yet means follow
   the operating system. The <head> snippet applies it before first paint;
   this file only handles the button and keeps open tabs in step. */
(function () {
  var KEY = "edg-theme";

  function system() {
    return window.matchMedia &&
           window.matchMedia("(prefers-color-scheme: dark)").matches
           ? "dark" : "light";
  }
  function stored() {
    try { return localStorage.getItem(KEY); } catch (e) { return null; }
  }
  function apply(theme) {
    document.documentElement.setAttribute("data-theme", theme);
    var b = document.querySelector(".themetoggle");
    if (b) {
      b.setAttribute("aria-label",
        theme === "dark" ? "Switch to light theme" : "Switch to dark theme");
      b.setAttribute("aria-pressed", theme === "dark" ? "true" : "false");
    }
  }

  apply(stored() || system());

  document.addEventListener("click", function (e) {
    var b = e.target.closest && e.target.closest(".themetoggle");
    if (!b) return;
    var next = document.documentElement.getAttribute("data-theme") === "dark"
             ? "light" : "dark";
    try { localStorage.setItem(KEY, next); } catch (err) {}
    apply(next);
  });

  // another tab switched the theme
  window.addEventListener("storage", function (e) {
    if (e.key === KEY && e.newValue) apply(e.newValue);
  });

  // still following the system: track it live
  if (window.matchMedia) {
    var mq = window.matchMedia("(prefers-color-scheme: dark)");
    var onChange = function () { if (!stored()) apply(system()); };
    if (mq.addEventListener) mq.addEventListener("change", onChange);
    else if (mq.addListener) mq.addListener(onChange);
  }
})();
