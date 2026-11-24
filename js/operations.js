const user = getUser();
if (!requireAuth()) {
  throw new Error("Требуется авторизация");
}

const role = user?.role || "";
const hasFullAccess = role === "Director" || role === "DatabaseAdmin";
const isDirector = hasFullAccess;
const canManage = hasFullAccess;
const canPurchase = hasFullAccess || role === "Purchaser";
const canDelivery = hasFullAccess || role === "Waiter";
const canFinance = hasFullAccess || role === "Accountant";
const canHr = hasFullAccess;

const tabAccess = {
  stock: true,
  purchases: canPurchase,
  deliveries: canDelivery,
  finance: canFinance,
  hr: canHr
};

const state = {
  tab: "stock",
  stock: [],
  movements: [],
  purchases: [],
  claims: [],
  deliveries: [],
  statements: [],
  lines: [],
  payments: [],
  schedule: [],
  timesheet: [],
  attestations: []
};

const panels = {
  stock: loadStock,
  purchases: loadPurchases,
  deliveries: loadDeliveries,
  finance: loadFinance,
  hr: loadHr
};

document.getElementById("userBadge").textContent =
  `${user?.employeeName || user?.login || "Сотрудник"} · ${role}`;
document.getElementById("welcomeText").textContent =
  `Вы вошли как ${role}. Доступные разделы: ${Object.entries(tabAccess)
    .filter(([, value]) => value).map(([key]) => key).join(", ")}.`;

document.querySelectorAll(".tab").forEach((button) => {
  if (!tabAccess[button.dataset.tab]) {
    button.hidden = true;
    document.getElementById(`panel-${button.dataset.tab}`).hidden = true;
    return;
  }
  button.addEventListener("click", () => switchTab(button.dataset.tab));
});

document.getElementById("logoutBtn").addEventListener("click", () => {
  clearSession();
  location.href = "login.html";
});
document.getElementById("refreshBtn").addEventListener("click", loadCurrentTab);

document.getElementById("receiveBtn").hidden = !canPurchase;
document.getElementById("writeOffBtn").hidden = !canPurchase;
document.getElementById("movementBtn").hidden = !canPurchase;
document.getElementById("newPurchaseBtn").hidden = !canPurchase;
document.getElementById("newClaimBtn").hidden = !canPurchase;
document.getElementById("newDeliveryBtn").hidden = !canDelivery;
document.getElementById("importStatementBtn").hidden = !canFinance;
document.getElementById("newShiftBtn").hidden = !canHr;
document.getElementById("recalcTimesheetBtn").hidden = !canHr;
document.getElementById("newAttestationBtn").hidden = !canHr;

function switchTab(name) {
  if (!tabAccess[name]) return;
  state.tab = name;
  document.querySelectorAll(".tab").forEach((button) => {
    const active = button.dataset.tab === name;
    button.classList.toggle("active", active);
    button.setAttribute("aria-selected", String(active));
  });
  document.querySelectorAll(".tab-panel").forEach((panel) => {
    panel.classList.toggle("active", panel.id === `panel-${name}`);
  });
  loadCurrentTab();
}

async function loadCurrentTab() {
  try {
    await panels[state.tab]();
  } catch (error) {
    toast(error.message, "error");
  }
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function emptyRow(cols, text) {
  return `<tr><td colspan="${cols}" class="muted">${text}</td></tr>`;
}

function badge(text, type = "") {
  return `<span class="badge ${type}">${escapeHtml(text)}</span>`;
}

function statusType(status) {
  const map = {
    "Поступил": "success", "Доставлена": "success", "Подтверждён": "success",
    "Сопоставлено": "success", "Зачёт": "success",
    "Отправлен": "info", "Назначена": "info", "Принята": "info", "В пути": "info",
    "Черновик": "", "Не сопоставлено": "warning", "Расхождение": "danger",
    "Отменён": "danger", "Отменена": "danger", "Незачёт": "danger"
  };
  return map[status] || "";
}

/* ---------------- Склад ---------------- */
async function loadStock() {
  const search = document.getElementById("stockSearch").value.trim();
  const params = new URLSearchParams();
  if (search) params.set("search", search);
  const [summary, movements] = await Promise.all([
    api(`/api/warehouse/summary?${params.toString()}`),
    api("/api/warehouse/movements")
  ]);
  state.stock = summary;
  state.movements = movements;
  renderStock();
  renderMovements();
}

function renderStock() {
  const body = document.getElementById("stockBody");
  if (state.stock.length === 0) {
    body.innerHTML = emptyRow(8, "Остатков не найдено.");
    return;
  }
  body.innerHTML = state.stock.map((row) => `<tr>
    <td>${escapeHtml(row.article)}</td>
    <td>${escapeHtml(row.nomenclatureName)}</td>
    <td>${escapeHtml(row.groupName)}</td>
    <td>${row.totalQty} ${escapeHtml(row.unit)}</td>
    <td>${row.reservedQty}</td>
    <td>${row.availableQty}</td>
    <td>${row.minStock}</td>
    <td>${row.belowMin ? badge("Ниже минимума", "danger") : badge("Норма", "success")}</td>
  </tr>`).join("");
}

function renderMovements() {
  const body = document.getElementById("movementsBody");
  if (state.movements.length === 0) {
    body.innerHTML = emptyRow(8, "Движений не было.");
    return;
  }
  body.innerHTML = state.movements.slice(0, 50).map((row) => `<tr>
    <td>${row.movementId}</td>
    <td>${formatDate(row.createdAt)}</td>
    <td>${escapeHtml(row.nomenclatureName)}</td>
    <td>${escapeHtml(row.placeName)}</td>
    <td>${badge(row.movementType)}</td>
    <td>${row.quantity}</td>
    <td>${escapeHtml(row.employeeName || "—")}</td>
    <td class="small">${escapeHtml(row.comment || "—")}</td>
  </tr>`).join("");
}

async function openReceive() {
  const nomenclatureId = Number(prompt("ID номенклатуры (из раздела «Номенклатура» API):"));
  if (!nomenclatureId) return;
  const placeId = Number(prompt("ID места хранения:", "1"));
  if (!placeId) return;
  const quantity = Number(prompt("Количество:", "10"));
  if (!(quantity > 0)) { toast("Количество должно быть больше нуля", "warning"); return; }
  const unitCost = Number(prompt("Себестоимость за единицу:", "100"));
  if (!(unitCost >= 0)) { toast("Себестоимость не может быть отрицательной", "warning"); return; }
  try {
    await api("/api/warehouse/receive", {
      method: "POST",
      body: JSON.stringify({ nomenclatureId, placeId, quantity, unitCost })
    });
    toast("Приход проведён", "success");
    await loadStock();
  } catch (error) {
    toast(error.message, "error");
  }
}

async function openWriteOff() {
  const batchId = Number(prompt("ID партии:"));
  if (!batchId) return;
  const quantity = Number(prompt("Количество к списанию:"));
  if (!(quantity > 0)) { toast("Количество должно быть больше нуля", "warning"); return; }
  const reason = prompt("Причина списания (минимум 5 символов):");
  if (!reason || reason.trim().length < 5) { toast("Укажите причину списания", "warning"); return; }
  try {
    await api("/api/warehouse/write-off", {
      method: "POST",
      body: JSON.stringify({ batchId, quantity, reason: reason.trim() })
    });
    toast("Списание проведено", "success");
    await loadStock();
  } catch (error) {
    toast(error.message, "error");
  }
}

async function openMovement() {
  const nomenclatureId = Number(prompt("ID номенклатуры:"));
  if (!nomenclatureId) return;
  const batchId = Number(prompt("ID партии:"));
  if (!batchId) return;
  const movementType = prompt("Тип: Резерв, Выдача или Возврат", "Выдача");
  if (!["Резерв", "Выдача", "Возврат"].includes(movementType)) {
    toast("Допустимые типы: Резерв, Выдача, Возврат", "warning");
    return;
  }
  const quantity = Number(prompt("Количество:", "1"));
  if (!(quantity > 0)) { toast("Количество должно быть больше нуля", "warning"); return; }
  try {
    await api("/api/warehouse/movements", {
      method: "POST",
      body: JSON.stringify({ nomenclatureId, batchId, movementType, quantity })
    });
    toast("Движение проведено", "success");
    await loadStock();
  } catch (error) {
    toast(error.message, "error");
  }
}

document.getElementById("receiveBtn").addEventListener("click", openReceive);
document.getElementById("writeOffBtn").addEventListener("click", openWriteOff);
document.getElementById("movementBtn").addEventListener("click", openMovement);
document.getElementById("stockSearch").addEventListener("input", debounce(loadCurrentTab));

/* ---------------- Закупки ---------------- */
async function loadPurchases() {
  const status = document.getElementById("purchasesStatus").value;
  const params = new URLSearchParams();
  if (status) params.set("status", status);
  const [purchases, claims] = await Promise.all([
    api(`/api/purchases?${params.toString()}`),
    api("/api/purchases/claims")
  ]);
  state.purchases = purchases;
  state.claims = claims;
  renderPurchases();
  renderClaims();
}

function renderPurchases() {
  const body = document.getElementById("purchasesBody");
  if (state.purchases.length === 0) {
    body.innerHTML = emptyRow(8, "Заказов не найдено.");
    return;
  }
  body.innerHTML = state.purchases.map((po) => {
    const actions = [];
    if (canPurchase && po.status === "Черновик")
      actions.push(`<button class="btn secondary" data-po="${po.purchaseOrderId}" data-next="Отправлен">Отправить</button>`);
    if (canPurchase && po.status === "Отправлен")
      actions.push(`<button class="btn secondary" data-po="${po.purchaseOrderId}" data-next="Подтверждён">Подтвердить</button>`);
    if (canPurchase && po.status === "Подтверждён")
      actions.push(`<button class="btn" data-po-receive="${po.purchaseOrderId}">Оприходовать</button>`);
    if (canPurchase && ["Черновик", "Отправлен"].includes(po.status))
      actions.push(`<button class="btn danger" data-po="${po.purchaseOrderId}" data-next="Отменён">Отмена</button>`);
    return `<tr>
      <td>${escapeHtml(po.poNumber)}</td>
      <td>${formatDate(po.orderDate, false)}</td>
      <td>${escapeHtml(po.supplierName)}</td>
      <td>${po.expectedDate ? formatDate(po.expectedDate, false) : "—"}</td>
      <td>${money(po.totalAmount)}</td>
      <td>${po.itemsCount}</td>
      <td>${badge(po.status, statusType(po.status))}</td>
      <td class="actions">${actions.join(" ") || "—"}</td>
    </tr>`;
  }).join("");

  body.querySelectorAll("[data-po]").forEach((button) =>
    button.addEventListener("click", () => setPurchaseStatus(Number(button.dataset.po), button.dataset.next)));
  body.querySelectorAll("[data-po-receive]").forEach((button) =>
    button.addEventListener("click", () => receivePurchase(Number(button.dataset.poReceive))));
}

async function setPurchaseStatus(id, status) {
  try {
    await api(`/api/purchases/${id}/status`, {
      method: "POST",
      body: JSON.stringify({ status })
    });
    toast(`Заказ №${id}: ${status}`, "success");
    await loadPurchases();
  } catch (error) {
    toast(error.message, "error");
  }
}

async function receivePurchase(id) {
  const placeId = Number(prompt("ID места хранения для оприходования:", "1"));
  if (!placeId) return;
  try {
    await api(`/api/purchases/${id}/receive`, {
      method: "POST",
      body: JSON.stringify({ placeId, expiryDays: null })
    });
    toast("Поставка оприходована", "success");
    await loadPurchases();
  } catch (error) {
    toast(error.message, "error");
  }
}

function renderClaims() {
  const body = document.getElementById("claimsBody");
  if (state.claims.length === 0) {
    body.innerHTML = emptyRow(7, "Претензий нет.");
    return;
  }
  body.innerHTML = state.claims.map((claim) => `<tr>
    <td>${claim.claimId}</td>
    <td>${escapeHtml(claim.poNumber)}</td>
    <td>${escapeHtml(claim.supplierName)}</td>
    <td>${badge(claim.claimType)}</td>
    <td>${formatDate(claim.claimDate, false)}</td>
    <td>${badge(claim.status, statusType(claim.status))}</td>
    <td class="small">${escapeHtml(claim.description)}</td>
  </tr>`).join("");
}

async function openNewPurchase() {
  const supplierId = Number(prompt("ID поставщика:"));
  if (!supplierId) return;
  const nomenclatureId = Number(prompt("ID номенклатуры первой позиции:"));
  if (!nomenclatureId) return;
  const quantity = Number(prompt("Количество:", "10"));
  if (!(quantity > 0)) { toast("Количество должно быть больше нуля", "warning"); return; }
  const unitPrice = Number(prompt("Цена за единицу:", "100"));
  if (!(unitPrice >= 0)) { toast("Цена не может быть отрицательной", "warning"); return; }
  try {
    await api("/api/purchases", {
      method: "POST",
      body: JSON.stringify({
        supplierId,
        expectedDate: null,
        notes: null,
        items: [{ nomenclatureId, quantity, unitPrice }]
      })
    });
    toast("Заказ поставщику создан", "success");
    await loadPurchases();
  } catch (error) {
    toast(error.message, "error");
  }
}

async function openNewClaim() {
  const purchaseOrderId = Number(prompt("ID заказа поставщику:"));
  if (!purchaseOrderId) return;
  const claimType = prompt("Тип: Просрочка, Брак, Пересорт или Недостача", "Брак");
  if (!["Просрочка", "Брак", "Пересорт", "Недостача"].includes(claimType)) {
    toast("Недопустимый тип претензии", "warning");
    return;
  }
  const description = prompt("Описание (минимум 5 символов):");
  if (!description || description.trim().length < 5) { toast("Опишите претензию", "warning"); return; }
  try {
    await api("/api/purchases/claims", {
      method: "POST",
      body: JSON.stringify({ purchaseOrderId, batchId: null, claimType, description: description.trim() })
    });
    toast("Претензия создана", "success");
    await loadPurchases();
  } catch (error) {
    toast(error.message, "error");
  }
}

document.getElementById("purchasesFilterBtn").addEventListener("click", loadCurrentTab);
document.getElementById("newPurchaseBtn").addEventListener("click", openNewPurchase);
document.getElementById("newClaimBtn").addEventListener("click", openNewClaim);

/* ---------------- Доставка ---------------- */
async function loadDeliveries() {
  const status = document.getElementById("deliveriesStatus").value;
  const params = new URLSearchParams();
  if (status) params.set("status", status);
  state.deliveries = await api(`/api/deliveries?${params.toString()}`);
  renderDeliveries();
}

function renderDeliveries() {
  const body = document.getElementById("deliveriesBody");
  if (state.deliveries.length === 0) {
    body.innerHTML = emptyRow(9, "Доставок не найдено.");
    return;
  }
  body.innerHTML = state.deliveries.map((row) => {
    const actions = [];
    const next = { "Назначена": "Принята", "Принята": "В пути", "В пути": "Доставлена" }[row.status];
    if (canDelivery && next)
      actions.push(`<button class="btn secondary" data-del="${row.deliveryId}" data-next="${next}">${next}</button>`);
    if (canDelivery && ["Назначена", "Принята"].includes(row.status))
      actions.push(`<button class="btn danger" data-del="${row.deliveryId}" data-next="Отменена">Отмена</button>`);
    return `<tr>
      <td>${row.deliveryId}</td>
      <td>${row.orderId}</td>
      <td>${escapeHtml(row.address)}</td>
      <td>${escapeHtml(row.contactPhone)}</td>
      <td>${row.plannedAt ? formatDate(row.plannedAt) : "—"}</td>
      <td>${escapeHtml(row.courierName || "—")}</td>
      <td>${escapeHtml(row.aggregatorName || "—")}</td>
      <td>${badge(row.status, statusType(row.status))}</td>
      <td class="actions">${actions.join(" ") || "—"}</td>
    </tr>`;
  }).join("");

  body.querySelectorAll("[data-del]").forEach((button) =>
    button.addEventListener("click", async () => {
      try {
        await api(`/api/deliveries/${button.dataset.del}/status`, {
          method: "POST",
          body: JSON.stringify({ status: button.dataset.next, comment: null })
        });
        toast(`Доставка №${button.dataset.del}: ${button.dataset.next}`, "success");
        await loadDeliveries();
      } catch (error) {
        toast(error.message, "error");
      }
    }));
}

async function openNewDelivery() {
  const orderId = Number(prompt("ID заказа:"));
  if (!orderId) return;
  const address = prompt("Адрес доставки:");
  if (!address || !address.trim()) { toast("Укажите адрес", "warning"); return; }
  const contactPhone = prompt("Телефон контакта:", "+7 (999) 123-45-67");
  if (!contactPhone) return;
  try {
    await api("/api/deliveries", {
      method: "POST",
      body: JSON.stringify({
        orderId,
        aggregatorId: null,
        courierEmployeeId: null,
        address: address.trim(),
        contactPhone: contactPhone.trim(),
        plannedAt: null,
        externalNumber: null,
        comment: null
      })
    });
    toast("Доставка создана", "success");
    await loadDeliveries();
  } catch (error) {
    toast(error.message, "error");
  }
}

document.getElementById("deliveriesFilterBtn").addEventListener("click", loadCurrentTab);
document.getElementById("newDeliveryBtn").addEventListener("click", openNewDelivery);

/* ---------------- Финансы ---------------- */
async function loadFinance() {
  const matchStatus = document.getElementById("linesMatchStatus").value;
  const lineParams = new URLSearchParams();
  if (matchStatus) lineParams.set("matchStatus", matchStatus);
  const [statements, lines, payments] = await Promise.all([
    api("/api/finance/statements"),
    api(`/api/finance/statements/lines?${lineParams.toString()}`),
    api("/api/finance/payments")
  ]);
  state.statements = statements;
  state.lines = lines;
  state.payments = payments;
  renderStatements();
  renderLines();
  renderPayments();
}

function renderStatements() {
  const body = document.getElementById("statementsBody");
  if (state.statements.length === 0) {
    body.innerHTML = emptyRow(7, "Выписок нет.");
    return;
  }
  body.innerHTML = state.statements.map((row) => `<tr>
    <td>${row.statementId}</td>
    <td>${formatDate(row.statementDate, false)}</td>
    <td>${escapeHtml(row.fileName)}</td>
    <td>${formatDate(row.uploadedAt)}</td>
    <td>${row.lineCount}</td>
    <td>${money(row.totalAmount)}</td>
    <td class="actions">${canFinance
      ? `<button class="btn secondary" data-automatch="${row.statementId}">Автоматический матчинг</button>`
      : "—"}</td>
  </tr>`).join("");

  body.querySelectorAll("[data-automatch]").forEach((button) =>
    button.addEventListener("click", async () => {
      try {
        await api(`/api/finance/statements/${button.dataset.automatch}/automatch`, { method: "POST" });
        toast("Автоматический матчинг выполнен", "success");
        await loadFinance();
      } catch (error) {
        toast(error.message, "error");
      }
    }));
}

function renderLines() {
  const body = document.getElementById("linesBody");
  if (state.lines.length === 0) {
    body.innerHTML = emptyRow(8, "Строк выписки нет.");
    return;
  }
  body.innerHTML = state.lines.slice(0, 50).map((row) => `<tr>
    <td>${row.lineNo}</td>
    <td>${formatDate(row.operationDate, false)}</td>
    <td>${escapeHtml(row.counterparty)}</td>
    <td class="small">${escapeHtml(row.paymentPurpose || "—")}</td>
    <td>${money(row.amount)}</td>
    <td>${badge(row.matchStatus, statusType(row.matchStatus))}</td>
    <td>${row.matchedPaymentId ?? "—"}</td>
    <td class="actions">${canFinance && row.matchStatus !== "Сопоставлено"
      ? `<button class="btn secondary" data-match="${row.lineId}">Сопоставить</button>`
      : "—"}</td>
  </tr>`).join("");

  body.querySelectorAll("[data-match]").forEach((button) =>
    button.addEventListener("click", async () => {
      const paymentId = Number(prompt("ID платежа для сопоставления:"));
      if (!paymentId) return;
      try {
        await api(`/api/finance/lines/${button.dataset.match}/match`, {
          method: "POST",
          body: JSON.stringify({ paymentId })
        });
        toast("Строка сопоставлена с платежом", "success");
        await loadFinance();
      } catch (error) {
        toast(error.message, "error");
      }
    }));
}

function renderPayments() {
  const body = document.getElementById("paymentsBody");
  document.getElementById("paymentsSummary").textContent = `Всего: ${state.payments.length}`;
  if (state.payments.length === 0) {
    body.innerHTML = emptyRow(6, "Платежей нет.");
    return;
  }
  body.innerHTML = state.payments.slice(0, 50).map((row) => `<tr>
    <td>${row.paymentId}</td>
    <td>${row.orderId}</td>
    <td>${formatDate(row.paymentDate)}</td>
    <td>${money(row.amount)}</td>
    <td>${escapeHtml(row.paymentMethod)}</td>
    <td>${badge(row.paymentStatus)}</td>
  </tr>`).join("");
}

async function openImportStatement() {
  const fileName = prompt("Имя файла выписки:", "statement.csv");
  if (!fileName) return;
  const raw = prompt(
    "Строки выписки в формате: номер;дата(ГГГГ-ММ-ДД);контрагент;сумма — по одной на строку:",
    "1;2026-11-01;ООО «Поставка»;15000"
  );
  if (!raw) return;
  const lines = [];
  for (const row of raw.split("\n")) {
    const parts = row.split(";").map((part) => part.trim());
    if (parts.length < 4) continue;
    lines.push({
      lineNo: Number(parts[0]),
      operationDate: `${parts[1]}T10:00:00`,
      counterparty: parts[2],
      purpose: null,
      amount: Number(parts[3])
    });
  }
  if (lines.length === 0) { toast("Не удалось разобрать строки", "warning"); return; }
  try {
    await api("/api/finance/statements/import", {
      method: "POST",
      body: JSON.stringify({
        statementDate: `${new Date().toISOString().slice(0, 10)}T10:00:00`,
        fileName: fileName.trim(),
        lines
      })
    });
    toast(`Выписка импортирована: ${lines.length} строк`, "success");
    await loadFinance();
  } catch (error) {
    toast(error.message, "error");
  }
}

document.getElementById("linesFilterBtn").addEventListener("click", loadCurrentTab);
document.getElementById("importStatementBtn").addEventListener("click", openImportStatement);

/* ---------------- Персонал ---------------- */
async function loadHr() {
  const [schedule, timesheet, attestations] = await Promise.all([
    api("/api/hr/schedule"),
    api("/api/hr/timesheet/summary"),
    api("/api/hr/attestations")
  ]);
  state.schedule = schedule;
  state.timesheet = timesheet;
  state.attestations = attestations;
  renderSchedule();
  renderTimesheet();
  renderAttestations();
}

function renderSchedule() {
  const body = document.getElementById("scheduleBody");
  if (state.schedule.length === 0) {
    body.innerHTML = emptyRow(9, "Смен не назначено.");
    return;
  }
  body.innerHTML = state.schedule.slice(0, 50).map((row) => `<tr>
    <td>${row.scheduleId}</td>
    <td>${escapeHtml(row.employeeName)}</td>
    <td>${escapeHtml(row.post)}</td>
    <td>${formatDate(row.shiftDate, false)}</td>
    <td>${escapeHtml(row.timeStart)}</td>
    <td>${escapeHtml(row.timeEnd)}</td>
    <td>${row.plannedHours}</td>
    <td>v${row.versionNo}${row.isActive ? "" : " (архив)"}</td>
    <td class="small">${escapeHtml(row.note || "—")}</td>
  </tr>`).join("");
}

function renderTimesheet() {
  const body = document.getElementById("timesheetBody");
  if (state.timesheet.length === 0) {
    body.innerHTML = emptyRow(5, "Данных табеля нет.");
    return;
  }
  body.innerHTML = state.timesheet.map((row) => `<tr>
    <td>${escapeHtml(row.employeeName)}</td>
    <td>${escapeHtml(row.post)}</td>
    <td>${row.daysCount}</td>
    <td>${row.totalHours}</td>
    <td>${row.approvedDays}</td>
  </tr>`).join("");
}

function renderAttestations() {
  const body = document.getElementById("attestationsBody");
  if (state.attestations.length === 0) {
    body.innerHTML = emptyRow(7, "Аттестаций нет.");
    return;
  }
  body.innerHTML = state.attestations.map((row) => `<tr>
    <td>${row.attestationId}</td>
    <td>${escapeHtml(row.employeeName)}</td>
    <td>${formatDate(row.attestationDate, false)}</td>
    <td>${escapeHtml(row.topic)}</td>
    <td>${badge(row.result, row.result === "Зачёт" ? "success" : "danger")}</td>
    <td>${row.score ?? "—"}</td>
    <td>${escapeHtml(row.trainer || "—")}</td>
  </tr>`).join("");
}

async function openNewShift() {
  const employeeId = Number(prompt("ID сотрудника:"));
  if (!employeeId) return;
  const shiftDate = prompt("Дата смены (ГГГГ-ММ-ДД):", new Date().toISOString().slice(0, 10));
  if (!shiftDate) return;
  const timeStart = prompt("Начало (ЧЧ:ММ):", "09:00");
  const timeEnd = prompt("Конец (ЧЧ:ММ):", "18:00");
  if (!timeStart || !timeEnd) return;
  try {
    await api("/api/hr/schedule", {
      method: "POST",
      body: JSON.stringify({
        employeeId,
        shiftDate: `${shiftDate}T00:00:00`,
        timeStart,
        timeEnd,
        note: null,
        reason: null
      })
    });
    toast("Смена назначена", "success");
    await loadHr();
  } catch (error) {
    toast(error.message, "error");
  }
}

async function recalcTimesheet() {
  const from = prompt("Период с (ГГГГ-ММ-ДД):", `${new Date().getFullYear()}-11-01`);
  if (!from) return;
  const to = prompt("Период по (ГГГГ-ММ-ДД):", new Date().toISOString().slice(0, 10));
  if (!to) return;
  try {
    await api("/api/hr/timesheet/recalc", {
      method: "POST",
      body: JSON.stringify({ from, to })
    });
    toast("Табель пересчитан", "success");
    await loadHr();
  } catch (error) {
    toast(error.message, "error");
  }
}

async function openNewAttestation() {
  const employeeId = Number(prompt("ID сотрудника:"));
  if (!employeeId) return;
  const topic = prompt("Тема аттестации:");
  if (!topic || !topic.trim()) { toast("Укажите тему", "warning"); return; }
  const result = prompt("Результат: Зачёт или Незачёт", "Зачёт");
  if (!["Зачёт", "Незачёт"].includes(result)) { toast("Недопустимый результат", "warning"); return; }
  const scoreRaw = prompt("Балл от 0 до 100 (можно пусто):");
  const score = scoreRaw ? Number(scoreRaw) : null;
  if (score !== null && (score < 0 || score > 100)) { toast("Балл должен быть от 0 до 100", "warning"); return; }
  try {
    await api("/api/hr/attestations", {
      method: "POST",
      body: JSON.stringify({
        employeeId,
        attestationDate: `${new Date().toISOString().slice(0, 10)}T00:00:00`,
        topic: topic.trim(),
        result,
        score,
        trainer: null,
        notes: null
      })
    });
    toast("Аттестация создана", "success");
    await loadHr();
  } catch (error) {
    toast(error.message, "error");
  }
}

document.getElementById("newShiftBtn").addEventListener("click", openNewShift);
document.getElementById("recalcTimesheetBtn").addEventListener("click", recalcTimesheet);
document.getElementById("newAttestationBtn").addEventListener("click", openNewAttestation);

/* ---------------- Общее ---------------- */
function debounce(fn, delay = 300) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}

document.addEventListener("keydown", (event) => {
  if (event.key === "F5") {
    event.preventDefault();
    loadCurrentTab();
  }
  if (event.key === "Escape") {
    document.querySelectorAll(".modal-backdrop.open").forEach((modal) => modal.classList.remove("open"));
  }
});

loadCurrentTab();
