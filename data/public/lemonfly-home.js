(function () {
  const root = document.documentElement;
  const themeToggle = document.getElementById("themeToggle");
  const themeIconMoon = document.getElementById("themeIconMoon");
  const themeIconSun = document.getElementById("themeIconSun");
  const langToggle = document.getElementById("langToggle");
  const langFlag = document.getElementById("langFlag");
  const langCode = document.getElementById("langCode");
  const authBtn = document.getElementById("authBtn");

  function applyTheme(theme) {
    root.dataset.theme = theme;
    localStorage.setItem("lemonfly-theme", theme);

    if (!themeToggle || !themeIconMoon || !themeIconSun) return;

    if (theme === "dark") {
      themeIconMoon.classList.add("hidden");
      themeIconSun.classList.remove("hidden");
      themeToggle.title = "切换到浅色模式";
    } else {
      themeIconMoon.classList.remove("hidden");
      themeIconSun.classList.add("hidden");
      themeToggle.title = "切换到深色模式";
    }
  }

  function applyLang(lang) {
    root.dataset.lang = lang;
    localStorage.setItem("lemonfly-lang", lang);

    if (langFlag && langCode && langToggle) {
      if (lang === "en") {
        langFlag.textContent = "🇺🇸";
        langCode.textContent = "EN";
        langToggle.title = "English";
      } else {
        langFlag.textContent = "🇨🇳";
        langCode.textContent = "ZH";
        langToggle.title = "中文";
      }
    }

    refreshAuthButton();
  }


  function refreshAuthButton() {
    if (!authBtn) return;

    authBtn.setAttribute("target", "_top");

    const loggedIn = authBtn.dataset.loggedIn === "true";
    const lang = root.dataset.lang || "zh";

    if (loggedIn) {
      authBtn.textContent = lang === "en" ? "Console" : "控制台";
      authBtn.href = "/dashboard";
    } else {
      authBtn.textContent = lang === "en" ? "Login" : "登录";
      authBtn.href = "/login";
    }
  }

  function getAuthToken() {
    const token = localStorage.getItem("auth_token") || sessionStorage.getItem("auth_token");

    if (!token) return "";

    return token.startsWith("Bearer ") ? token : `Bearer ${token}`;
  }

  async function detectLogin() {
    if (!authBtn) return;

    try {
      const timezone = encodeURIComponent(
        Intl.DateTimeFormat().resolvedOptions().timeZone || "Asia/Shanghai"
      );

      const authToken = getAuthToken();

      const headers = {
        "Accept": "application/json"
      };

      if (authToken) {
        headers["Authorization"] = authToken;
      }

      const res = await fetch(`/api/v1/auth/me?timezone=${timezone}`, {
        method: "GET",
        credentials: "include",
        headers
      });

      authBtn.dataset.loggedIn = res.ok ? "true" : "false";
    } catch (e) {
      authBtn.dataset.loggedIn = "false";
    }

    refreshAuthButton();
  }

  if (themeToggle) {
    themeToggle.addEventListener("click", function () {
      const current = root.dataset.theme || "light";
      applyTheme(current === "dark" ? "light" : "dark");
    });
  }

  if (langToggle) {
    langToggle.addEventListener("click", function () {
      const current = root.dataset.lang || "zh";
      applyLang(current === "zh" ? "en" : "zh");
    });
  }

  document.querySelectorAll("a[href^=\"/\"]").forEach(function (link) {
    link.setAttribute("target", "_top");
  });

  applyTheme(localStorage.getItem("lemonfly-theme") || "light");
  applyLang(localStorage.getItem("lemonfly-lang") || "zh");
  detectLogin();
})();
