// A publishable key is intentionally public. Never put a DB password or service_role key here.
(() => {
  const enabled = window.GRAND_BACKEND === "supabase" ||
    location.hostname === "bebrchka.github.io";
  if (!enabled) return; // Local ASP.NET + SQL Server remains the default.

  const base = "https://dyaktqmorlybwtotstuj.supabase.co";
  const publishableKey = "sb_publishable_9UB2DrE8cGVnxowuZkh4fA_Qdla56qj";
  const prefix = "grand_dyaktqmorlybwtotstuj_";
  const keys = Object.freeze({
    token: `${prefix}token`,
    user: `${prefix}user`,
    refresh: `${prefix}refresh`,
    expires: `${prefix}expires`
  });
  let refreshing = null;

  function failure(message, code, status = 0) {
    return Object.assign(new Error(message), { code, status });
  }

  function clearSession() {
    Object.values(keys).forEach((key) => localStorage.removeItem(key));
  }

  async function send(route, options = {}, token = null, retryRead = false) {
    let response;
    const attempts = retryRead ? 3 : 1;
    for (let attempt = 0; attempt < attempts; attempt++) {
      try {
        response = await fetch(`${base}${route}`, {
          ...options,
          signal: typeof AbortSignal !== "undefined" && AbortSignal.timeout
            ? AbortSignal.timeout(10000)
            : undefined,
          headers: {
            apikey: publishableKey,
            "Content-Type": "application/json",
            ...(token ? { Authorization: `Bearer ${token}` } : {})
          }
        });
        if (!retryRead || ![502, 503, 504].includes(response.status) || attempt === attempts - 1) break;
      } catch {
        if (attempt === attempts - 1) {
          throw failure("Не удалось связаться с Supabase. Попробуйте обновить страницу через несколько секунд.", "NETWORK_ERROR");
        }
      }
      await new Promise((resolve) => setTimeout(resolve, 350 * (attempt + 1)));
    }
    const data = response.status === 204 ? null : await response.json().catch(() => null);
    if (!response.ok) {
      if (data?.code === "PGRST202" || data?.code === "42883") {
        throw failure("Облачная база ещё не настроена: необходимо применить миграцию ресторана.", "MIGRATION_REQUIRED", 503);
      }
      const safeCodes = ["P0001", "42501", "0A000", "PT429"];
      const message = safeCodes.includes(data?.code)
        ? data.message
        : response.status === 401 || data?.error_code === "invalid_credentials"
          ? "Неверный email или пароль сотрудника."
          : response.status === 403
            ? "Недостаточно прав для этой операции."
            : "Не удалось выполнить запрос к облачной базе.";
      throw failure(message, data?.code || data?.error_code || "SUPABASE_ERROR", response.status);
    }
    return data;
  }

  function saveCredentials(session) {
    if (!session?.access_token || !session.refresh_token) {
      throw failure("Сервер не вернул действительную сессию.", "INVALID_SESSION", 401);
    }
    localStorage.setItem(keys.token, session.access_token);
    localStorage.setItem(keys.refresh, session.refresh_token);
    localStorage.setItem(keys.expires, String(session.expires_at || (Date.now() / 1000 + session.expires_in)));
  }

  async function token() {
    const access = localStorage.getItem(keys.token);
    const refresh = localStorage.getItem(keys.refresh);
    const expires = Number(localStorage.getItem(keys.expires) || 0);
    if (!access || !refresh || expires > Date.now() / 1000 + 60) return access;
    if (!refreshing) {
      refreshing = send("/auth/v1/token?grant_type=refresh_token", {
        method: "POST", body: JSON.stringify({ refresh_token: refresh })
      }).then((session) => {
        saveCredentials(session);
        return session.access_token;
      }).catch((error) => {
        if (error.status === 400 || error.status === 401) clearSession();
        throw error;
      }).finally(() => { refreshing = null; });
    }
    return refreshing;
  }

  async function rpc(method, path, payload = {}, query = {}) {
    return send("/rest/v1/rpc/grand_api", {
      method: "POST", body: JSON.stringify({ method, path, query, payload })
    }, await token(), method === "GET");
  }

  async function login(body) {
    const email = String(body.login || "").trim();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      throw failure("В облачной версии используйте email сотрудника Supabase Auth, а не локальный демонстрационный логин.", "EMAIL_REQUIRED", 400);
    }
    const session = await send("/auth/v1/token?grant_type=password", {
      method: "POST", body: JSON.stringify({ email, password: body.password })
    });
    saveCredentials(session);
    try {
      const user = await rpc("GET", "/api/auth/me");
      return { token: session.access_token, user, expiresAt: new Date(Number(localStorage.getItem(keys.expires)) * 1000).toISOString() };
    } catch (error) {
      clearSession();
      throw error;
    }
  }

  window.grandCloudApi = Object.freeze({
    storageKeys: keys,
    clearSession,
    async request(path, options = {}) {
      const url = new URL(path, location.origin);
      if (url.origin !== location.origin || !url.pathname.startsWith("/api/")) {
        throw failure("Неподдерживаемый адрес API.", "INVALID_API_PATH", 400);
      }
      if (options.body instanceof FormData) {
        throw failure("Импорт файлов пока доступен в локальной версии ASP.NET.", "LOCAL_ONLY", 501);
      }
      const method = (options.method || "GET").toUpperCase();
      const payload = options.body ? JSON.parse(options.body) : {};
      if (url.pathname === "/api/auth/login" && method === "POST") return login(payload);
      return rpc(method, url.pathname.replace(/\/$/, ""), payload, Object.fromEntries(url.searchParams));
    }
  });
})();
