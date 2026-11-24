const reportUser = getUser();
if (!requireAuth()) {
  throw new Error("Требуется авторизация");
}
if (!["Director", "DatabaseAdmin", "Accountant"].includes(reportUser?.role)) {
  location.href = "admin.html";
  throw new Error("Недостаточно прав");
}

const reportState = {
  dashboard: null,
  statuses: [],
  charts: {}
};

const reportTitles = {
  revenue: "Выручка",
  "popular-dishes": "Популярные блюда",
  waiters: "Официанты",
  "table-load": "Загрузка столиков",
  hourly: "Нагрузка по часам"
};

document.getElementById("userBadge").textContent =
  `${reportUser?.employeeName || reportUser?.login || "Сотрудник"} · ${reportUser.role}`;

document.getElementById("logoutBtn").addEventListener("click", () => {
  clearSession();
  location.href = "login.html";
});

document.getElementById("refreshBtn").addEventListener("click", loadDashboard);
document.getElementById("applyBtn").addEventListener("click", loadDashboard);

document.querySelectorAll("[data-days]").forEach((button) => {
  button.addEventListener("click", () => {
    const days = Number(button.dataset.days) || 30;
    const end = new Date();
    const start = new Date();
    start.setDate(start.getDate() - (days - 1));
    document.getElementById("dateFrom").value = formatDateInput(start);
    document.getElementById("dateTo").value = formatDateInput(end);
    loadDashboard();
  });
});

document.querySelectorAll("[data-export]").forEach((button) => {
  button.addEventListener("click", () => exportReport(button.dataset.export));
});

document.getElementById("themeToggle")?.addEventListener("click", () => {
  window.setTimeout(renderCharts, 0);
});

function initReportDates() {
  const end = new Date();
  const start = new Date();
  start.setDate(start.getDate() - 29);
  document.getElementById("dateFrom").value = formatDateInput(start);
  document.getElementById("dateTo").value = formatDateInput(end);
}

function validateDates() {
  const from = document.getElementById("dateFrom").value;
  const to = document.getElementById("dateTo").value;
  if (from && to && from > to) {
    setReportError("Дата начала не может быть позже даты окончания.");
    toast("Проверьте период отчёта.", "warning");
    return false;
  }
  setReportError("");
  return true;
}

function buildReportQuery() {
  const params = new URLSearchParams();
  const from = document.getElementById("dateFrom").value;
  const to = document.getElementById("dateTo").value;
  if (from) params.set("from", from);
  if (to) params.set("to", to);
  const query = params.toString();
  return query ? `?${query}` : "";
}

function setReportError(message) {
  document.getElementById("reportsError").textContent = message;
}

function setReportsLoading(loading) {
  document.getElementById("refreshBtn").disabled = loading;
  document.getElementById("applyBtn").disabled = loading;
  document.querySelectorAll("[data-export]").forEach((button) => {
    button.disabled = loading;
  });
}

async function loadDashboard() {
  if (!validateDates()) return;
  setReportsLoading(true);
  setReportError("");
  try {
    const query = buildReportQuery();
    const [dashboard, statuses] = await Promise.all([
      api(`/api/reports/dashboard${query}`),
      api(`/api/reports/order-status${query}`)
    ]);
    reportState.dashboard = dashboard || {};
    reportState.statuses = Array.isArray(statuses) ? statuses : [];
    renderKpis();
    renderReportTables();
    renderCharts();
  } catch (error) {
    if (error.status === 403) {
      location.href = "admin.html";
      return;
    }
    setReportError(error.message);
    toast(error.message, "error");
  } finally {
    setReportsLoading(false);
  }
}

function renderKpis() {
  const summary = reportState.dashboard?.summary || {};
  document.getElementById("kpiRevenue").textContent = money(field(summary, "Revenue"));
  document.getElementById("kpiOrders").textContent = number(field(summary, "OrdersCount"));
  document.getElementById("kpiAvgCheck").textContent = money(field(summary, "AvgCheck"));
  document.getElementById("kpiReservations").textContent = number(field(summary, "ReservationsCount"));
  document.getElementById("kpiActive").textContent = number(field(summary, "ActiveOrders"));
}

function renderReportTables() {
  const waiters = Array.isArray(reportState.dashboard?.waiters) ? reportState.dashboard.waiters : [];
  const waitersBody = document.getElementById("waitersBody");
  waitersBody.innerHTML = waiters.length
    ? waiters.map((row) => {
        const orders = Number(field(row, "OrdersCount") || 0);
        const revenue = Number(field(row, "Revenue") || 0);
        return `<tr>
          <td>${escapeHtml(field(row, "EmployeeName") || "—")}</td>
          <td>${number(orders)}</td>
          <td>${money(revenue)}</td>
          <td>${money(orders ? revenue / orders : 0)}</td>
        </tr>`;
      }).join("")
    : `<tr><td colspan="4" class="muted">Нет данных за выбранный период.</td></tr>`;

  const tables = Array.isArray(reportState.dashboard?.tableLoad) ? reportState.dashboard.tableLoad : [];
  const tablesBody = document.getElementById("tablesBody");
  tablesBody.innerHTML = tables.length
    ? tables.map((row) => `<tr>
        <td>${escapeHtml(field(row, "TableNumber") || "—")}</td>
        <td>${escapeHtml(field(row, "Hall") || "—")}</td>
        <td>${number(field(row, "OrdersCount"))}</td>
        <td>${money(field(row, "Revenue"))}</td>
      </tr>`).join("")
    : `<tr><td colspan="4" class="muted">Нет данных за выбранный период.</td></tr>`;
}

function renderCharts() {
  const canvasHost = document.getElementById("revenueChart");
  if (!canvasHost) return;
  if (!window.Chart) {
    setReportError("Библиотека Chart.js не загрузилась.");
    return;
  }
  if (!reportState.dashboard) return;

  Object.values(reportState.charts).forEach((chart) => chart.destroy());
  reportState.charts = {};

  const dashboard = reportState.dashboard;
  const revenue = Array.isArray(dashboard.revenue) ? dashboard.revenue : [];
  const dishes = Array.isArray(dashboard.popularDishes) ? dashboard.popularDishes : [];
  const hourly = Array.isArray(dashboard.hourly) ? dashboard.hourly : [];
  const statuses = reportState.statuses;

  const styles = getComputedStyle(document.documentElement);
  const primary = styles.getPropertyValue("--primary").trim();
  const accent = styles.getPropertyValue("--accent").trim();
  const success = styles.getPropertyValue("--success").trim();
  const warning = styles.getPropertyValue("--warning").trim();
  const danger = styles.getPropertyValue("--danger").trim();
  const info = styles.getPropertyValue("--info").trim();
  const text = styles.getPropertyValue("--text").trim();
  const muted = styles.getPropertyValue("--muted").trim();
  const border = styles.getPropertyValue("--border").trim();
  const font = styles.getPropertyValue("--font-body").trim() || "Segoe UI, Arial, sans-serif";

  Chart.defaults.color = muted;
  Chart.defaults.borderColor = border;
  Chart.defaults.font.family = font;

  const compact = new Intl.NumberFormat("ru-RU", { notation: "compact", maximumFractionDigits: 1 });
  const baseOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: {
        backgroundColor: text,
        titleColor: styles.getPropertyValue("--surface").trim(),
        bodyColor: styles.getPropertyValue("--surface").trim(),
        padding: 10,
        cornerRadius: 8
      }
    }
  };

  reportState.charts.revenue = new Chart(document.getElementById("revenueChart"), {
    type: "line",
    data: {
      labels: revenue.map((row) => shortDate(field(row, "RevenueDate"))),
      datasets: [{
        label: "Выручка",
        data: revenue.map((row) => Number(field(row, "Revenue") || 0)),
        borderColor: primary,
        backgroundColor: withAlpha(primary, 0.16),
        borderWidth: 2,
        pointRadius: 2,
        pointHoverRadius: 4,
        fill: true,
        tension: 0.35
      }]
    },
    options: {
      ...baseOptions,
      interaction: { mode: "index", intersect: false },
      plugins: {
        ...baseOptions.plugins,
        tooltip: {
          ...baseOptions.plugins.tooltip,
          callbacks: { label: (context) => `Выручка: ${money(context.parsed.y)}` }
        }
      },
      scales: {
        x: { grid: { display: false }, ticks: { maxRotation: 0, autoSkip: true, maxTicksLimit: 10 } },
        y: { beginAtZero: true, ticks: { callback: (value) => compact.format(value) }, grid: { color: withAlpha(border, 0.7) } }
      }
    }
  });

  reportState.charts.dishes = new Chart(document.getElementById("dishesChart"), {
    type: "bar",
    data: {
      labels: dishes.map((row) => field(row, "DishName") || "—"),
      datasets: [{
        label: "Порций",
        data: dishes.map((row) => Number(field(row, "TotalQuantity") || 0)),
        backgroundColor: withAlpha(accent, 0.75),
        borderColor: accent,
        borderWidth: 1,
        borderRadius: 5,
        maxBarThickness: 24
      }]
    },
    options: {
      ...baseOptions,
      indexAxis: "y",
      plugins: {
        ...baseOptions.plugins,
        tooltip: {
          ...baseOptions.plugins.tooltip,
          callbacks: {
            label: (context) => `Порций: ${number(context.parsed.x)}`,
            afterLabel: (context) => `Выручка: ${money(field(dishes[context.dataIndex], "Revenue"))}`
          }
        }
      },
      scales: {
        x: { beginAtZero: true, ticks: { precision: 0 }, grid: { color: withAlpha(border, 0.7) } },
        y: { grid: { display: false } }
      }
    }
  });

  reportState.charts.hourly = new Chart(document.getElementById("hourlyChart"), {
    type: "bar",
    data: {
      labels: hourly.map((row) => `${String(Number(field(row, "OrderHour") || 0)).padStart(2, "0")}:00`),
      datasets: [{
        label: "Заказы",
        data: hourly.map((row) => Number(field(row, "OrdersCount") || 0)),
        backgroundColor: withAlpha(info, 0.68),
        borderColor: info,
        borderWidth: 1,
        borderRadius: 5
      }]
    },
    options: {
      ...baseOptions,
      plugins: {
        ...baseOptions.plugins,
        tooltip: {
          ...baseOptions.plugins.tooltip,
          callbacks: { label: (context) => `Заказов: ${number(context.parsed.y)}` }
        }
      },
      scales: {
        x: { grid: { display: false } },
        y: { beginAtZero: true, ticks: { precision: 0 }, grid: { color: withAlpha(border, 0.7) } }
      }
    }
  });

  const statusColors = {
    "Оформлен": info,
    "Готовится": warning,
    "Готов": success,
    "Оплачен": success,
    "Отменён": danger
  };

  reportState.charts.statuses = new Chart(document.getElementById("statusChart"), {
    type: "doughnut",
    data: {
      labels: statuses.map((row) => field(row, "OrderStatus") || "—"),
      datasets: [{
        data: statuses.map((row) => Number(field(row, "OrdersCount") || 0)),
        backgroundColor: statuses.map((row) => withAlpha(statusColors[field(row, "OrderStatus")] || muted, 0.7)),
        borderColor: styles.getPropertyValue("--surface").trim(),
        borderWidth: 2,
        hoverOffset: 4
      }]
    },
    options: {
      ...baseOptions,
      cutout: "62%",
      plugins: {
        ...baseOptions.plugins,
        legend: { display: true, position: "bottom", labels: { boxWidth: 10, usePointStyle: true, padding: 14 } },
        tooltip: {
          ...baseOptions.plugins.tooltip,
          callbacks: {
            label: (context) => `${context.label}: ${number(context.parsed)}`,
            afterLabel: (context) => `Сумма: ${money(field(statuses[context.dataIndex], "TotalAmount"))}`
          }
        }
      }
    }
  });
}

async function exportReport(report) {
  if (!validateDates()) return;
  const button = document.querySelector(`[data-export="${report}"]`);
  if (button) button.disabled = true;
  try {
    const csv = await api(`/api/reports/export/${report}.csv${buildReportQuery()}`);
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${reportTitles[report] || report}.csv`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
    toast(`Отчёт «${reportTitles[report] || report}» выгружен.`, "success");
  } catch (error) {
    toast(error.message, "error");
  } finally {
    if (button) button.disabled = false;
  }
}

function field(row, name) {
  if (!row || typeof row !== "object") return undefined;
  if (Object.prototype.hasOwnProperty.call(row, name)) return row[name];
  const key = Object.keys(row).find((candidate) => candidate.toLowerCase() === name.toLowerCase());
  return key ? row[key] : undefined;
}

function number(value) {
  return new Intl.NumberFormat("ru-RU").format(Number(value || 0));
}

function shortDate(value) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleDateString("ru-RU", { day: "2-digit", month: "2-digit" });
}

function withAlpha(color, alpha) {
  const hex = String(color || "").trim();
  if (!/^#[0-9a-f]{6}$/i.test(hex)) return hex;
  const value = Math.round(Math.min(Math.max(alpha, 0), 1) * 255).toString(16).padStart(2, "0");
  return `${hex}${value}`;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

initReportDates();
loadDashboard();
