const TOKEN_KEY = "restaurant_token";
const USER_KEY = "restaurant_user";
const THEME_KEY = "restaurant_theme";

function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

function getUser() {
  try {
    return JSON.parse(localStorage.getItem(USER_KEY) || "null");
  } catch {
    return null;
  }
}

function setSession(token, user) {
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
}

function clearSession() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
}

function requireAuth() {
  if (!getToken()) {
    location.href = "login.html";
    return false;
  }
  return true;
}

async function api(path, options = {}) {
  const headers = { ...(options.headers || {}) };
  if (!(options.body instanceof FormData) && options.body !== undefined) {
    headers["Content-Type"] = "application/json";
  }
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(path, { ...options, headers });
  if (response.status === 401 && getToken()) {
    clearSession();
    if (!location.pathname.endsWith("login.html")) {
      location.href = "login.html";
      return null;
    }
  }

  if (!response.ok) {
    let message = `Ошибка ${response.status}`;
    let code = "HTTP_ERROR";
    try {
      const data = await response.json();
      message = data.message || data.error || message;
      code = data.error || code;
    } catch {
      try { message = await response.text() || message; } catch { /* ignore */ }
    }
    const error = new Error(message);
    error.code = code;
    error.status = response.status;
    throw error;
  }

  if (response.status === 204) return null;
  const contentType = response.headers.get("content-type") || "";
  return contentType.includes("application/json") ? response.json() : response.text();
}

function money(value) {
  return new Intl.NumberFormat("ru-RU", {
    style: "currency",
    currency: "RUB",
    maximumFractionDigits: 2
  }).format(Number(value || 0));
}

function formatDate(value, withTime = true) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleString("ru-RU", withTime
    ? { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" }
    : { day: "2-digit", month: "2-digit", year: "numeric" });
}

function formatDateInput(date) {
  const d = new Date(date);
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function toast(message, type = "info", timeout = 4200) {
  let stack = document.querySelector(".toast-stack");
  if (!stack) {
    stack = document.createElement("div");
    stack.className = "toast-stack";
    document.body.appendChild(stack);
  }
  const item = document.createElement("div");
  item.className = `toast ${type}`;
  item.textContent = message;
  stack.appendChild(item);
  setTimeout(() => item.remove(), timeout);
}

function applyTheme(theme) {
  const normalized = theme === "system"
    ? (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
    : theme;
  document.documentElement.dataset.theme = normalized === "dark" ? "dark" : "light";
  localStorage.setItem(THEME_KEY, theme);
  const button = document.getElementById("themeToggle");
  if (button) button.textContent = normalized === "dark" ? "☀" : "☾";
}

function initTheme() {
  applyTheme(localStorage.getItem(THEME_KEY) || "light");
  document.getElementById("themeToggle")?.addEventListener("click", () => {
    const current = localStorage.getItem(THEME_KEY) || "light";
    applyTheme(current === "dark" ? "light" : "dark");
  });
}

function showHotkeys() {
  const existing = document.getElementById("hotkeysModal");
  if (existing) { existing.classList.add("open"); return; }
  const backdrop = document.createElement("div");
  backdrop.id = "hotkeysModal";
  backdrop.className = "modal-backdrop open";
  backdrop.innerHTML = `
    <div class="modal" role="dialog" aria-modal="true" aria-labelledby="hotkeysTitle">
      <div class="modal-head">
        <h2 id="hotkeysTitle">Горячие клавиши</h2>
        <button class="icon-btn" data-close-hotkeys aria-label="Закрыть">✕</button>
      </div>
      <div class="hotkeys">
        <div class="hotkey-row"><span>Поиск по меню / таблице</span><kbd>/</kbd></div>
        <div class="hotkey-row"><span>Переключение разделов админ-панели</span><kbd>Alt</kbd> + <kbd>1…8</kbd></div>
        <div class="hotkey-row"><span>Новый заказ</span><kbd>F2</kbd></div>
        <div class="hotkey-row"><span>Обновить данные</span><kbd>F5</kbd></div>
        <div class="hotkey-row"><span>Быстрый поиск</span><kbd>Ctrl</kbd> + <kbd>K</kbd></div>
        <div class="hotkey-row"><span>Сохранить настройки</span><kbd>Ctrl</kbd> + <kbd>S</kbd></div>
        <div class="hotkey-row"><span>Закрыть окно</span><kbd>Esc</kbd></div>
        <div class="hotkey-row"><span>Показать эту справку</span><kbd>F1</kbd></div>
      </div>
    </div>`;
  document.body.appendChild(backdrop);
  const close = () => backdrop.remove();
  backdrop.addEventListener("click", (event) => {
    if (event.target === backdrop || event.target.closest("[data-close-hotkeys]")) close();
  });
  document.addEventListener("keydown", function onEscape(event) {
    if (event.key === "Escape") { close(); document.removeEventListener("keydown", onEscape); }
  });
}

document.addEventListener("keydown", (event) => {
  if (event.key === "F1" && !event.ctrlKey && !event.altKey) {
    event.preventDefault();
    showHotkeys();
  }
});

initTheme();
