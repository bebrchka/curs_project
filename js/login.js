if (getToken()) {
  location.href = "admin.html";
}

document.getElementById("loginForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const errorBox = document.getElementById("loginError");
  const button = form.querySelector("button[type=submit]");
  errorBox.textContent = "";

  const login = form.login.value.trim();
  const password = form.password.value;
  if (!login || !password) {
    errorBox.textContent = "Введите логин и пароль.";
    return;
  }

  button.disabled = true;
  try {
    const result = await api("/api/auth/login", {
      method: "POST",
      body: JSON.stringify({ login, password })
    });
    setSession(result.token, result.user);
    toast(`Добро пожаловать, ${result.user.employeeName || result.user.login}!`, "success");
    location.href = !window.grandCloudApi && ["Director", "DatabaseAdmin", "Accountant"].includes(result.user.role)
      ? "reports.html"
      : "admin.html";
  } catch (error) {
    errorBox.textContent = error.message;
  } finally {
    button.disabled = false;
  }
});
