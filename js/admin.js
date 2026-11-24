const user = getUser();
if (!requireAuth()) {
  throw new Error("Требуется авторизация");
}

const role = user?.role || "";
const hasFullAccess = role === "Director";
const canManage = hasFullAccess || role === "DatabaseAdmin";
const canCreateOrders = hasFullAccess || role === "Waiter";
const canPay = hasFullAccess || role === "Accountant";
const canKitchen = hasFullAccess || role === "Chef";
const canCancel = hasFullAccess || role === "Waiter";

const state = {
  tab: "orders",
  orders: [],
  reservations: [],
  tables: [],
  dishes: [],
  categories: [],
  customers: [],
  employees: [],
  audit: [],
  settings: null
};

const panels = {
  orders: { load: loadOrders },
  reservations: { load: loadReservations },
  tables: { load: loadTables },
  dishes: { load: loadDishes },
  customers: { load: loadCustomers },
  employees: { load: loadEmployees },
  audit: { load: loadAudit },
  settings: { load: loadSettings }
};

const tabAccess = {
  orders: ["Director", "Waiter", "Chef", "Accountant"].includes(role),
  reservations: ["Director", "Waiter"].includes(role),
  tables: ["Director", "Waiter", "DatabaseAdmin"].includes(role),
  dishes: ["Director", "DatabaseAdmin", "Chef", "Waiter"].includes(role),
  customers: ["Director", "DatabaseAdmin", "Waiter", "Accountant"].includes(role),
  employees: canManage,
  audit: canManage,
  settings: true
};

document.getElementById("userBadge").textContent = `${user?.employeeName || user?.login || "Сотрудник"} · ${role}`;
document.getElementById("welcomeText").textContent =
  `Вы вошли как ${role}. Доступные разделы: ${Object.entries(tabAccess).filter(([, value]) => value).map(([key]) => key).join(", ")}.`;

if (!canCreateOrders) document.getElementById("newOrderBtn").hidden = true;

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

document.getElementById("refreshBtn").addEventListener("click", () => loadCurrentTab());
document.getElementById("newOrderBtn").addEventListener("click", openNewOrder);

document.querySelectorAll("[data-close]").forEach((button) => {
  button.addEventListener("click", () => closeModal(button.dataset.close));
});

document.querySelectorAll(".modal-backdrop").forEach((backdrop) => {
  backdrop.addEventListener("click", (event) => {
    if (event.target === backdrop) backdrop.classList.remove("open");
  });
});

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
    await panels[state.tab].load();
  } catch (error) {
    toast(error.message, "error");
  }
}

function closeModal(id) {
  document.getElementById(id)?.classList.remove("open");
}

function statusBadge(status) {
  const map = {
    "Оформлен": "info",
    "Готовится": "warning",
    "Готов": "success",
    "Оплачен": "success",
    "Отменён": "danger",
    "Активна": "info",
    "Выполнена": "success",
    "Отменена": "danger",
    "Свободен": "success",
    "Занят": "warning",
    "Забронирован": "info",
    "Неактивен": "danger"
  };
  return `<span class="badge ${map[status] || ""}">${escapeHtml(status)}</span>`;
}

/* ---------------- Orders ---------------- */
async function loadOrders() {
  const params = new URLSearchParams();
  const from = document.getElementById("ordersFrom").value;
  const to = document.getElementById("ordersTo").value;
  const status = document.getElementById("ordersStatus").value;
  if (from) params.set("from", from);
  if (to) params.set("to", to);
  if (status) params.set("status", status);

  state.orders = await api(`/api/orders?${params.toString()}`);
  renderOrders();
}

function renderOrders() {
  const query = document.getElementById("ordersSearch").value.trim().toLowerCase();
  const rows = state.orders.filter((order) => !query ||
    String(order.orderId).includes(query) ||
    (order.customerFullName || "").toLowerCase().includes(query) ||
    (order.tableNumber || "").toLowerCase().includes(query));

  const body = document.getElementById("ordersBody");
  if (rows.length === 0) {
    body.innerHTML = `<tr><td colspan="9" class="muted">Заказов не найдено.</td></tr>`;
    return;
  }

  body.innerHTML = rows.map((order) => {
    const actions = [`<button class="btn secondary" data-details="${order.orderId}">Детали</button>`];
    if (canKitchen && order.orderStatus === "Оформлен")
      actions.push(`<button class="btn secondary" data-status="${order.orderId}" data-next="Готовится">На кухню</button>`);
    if (canKitchen && order.orderStatus === "Готовится")
      actions.push(`<button class="btn secondary" data-status="${order.orderId}" data-next="Готов">Готов</button>`);
    if (canPay && !["Оплачен", "Отменён"].includes(order.orderStatus))
      actions.push(`<button class="btn" data-pay="${order.orderId}">Оплатить</button>`);
    if (canCancel && !["Оплачен", "Отменён"].includes(order.orderStatus))
      actions.push(`<button class="btn danger" data-cancel="${order.orderId}">Отмена</button>`);

    return `<tr>
      <td>${order.orderId}</td>
      <td>${formatDate(order.orderDate)}</td>
      <td>${escapeHtml(order.orderType)}</td>
      <td>${escapeHtml(order.tableNumber || "—")}</td>
      <td>${escapeHtml(order.customerFullName || "—")}</td>
      <td>${escapeHtml(order.employeeFullName || "—")}</td>
      <td>${money(order.totalAmount)}</td>
      <td>${statusBadge(order.orderStatus)}</td>
      <td class="actions">${actions.join(" ")}</td>
    </tr>`;
  }).join("");

  body.querySelectorAll("[data-details]").forEach((button) =>
    button.addEventListener("click", () => showOrderDetails(Number(button.dataset.details))));
  body.querySelectorAll("[data-status]").forEach((button) =>
    button.addEventListener("click", () => changeOrderStatus(Number(button.dataset.status), button.dataset.next)));
  body.querySelectorAll("[data-pay]").forEach((button) =>
    button.addEventListener("click", () => payOrder(Number(button.dataset.pay))));
  body.querySelectorAll("[data-cancel]").forEach((button) =>
    button.addEventListener("click", () => cancelOrder(Number(button.dataset.cancel))));
}

async function showOrderDetails(orderId) {
  const modal = document.getElementById("orderDetailsModal");
  const body = document.getElementById("orderDetailsBody");
  document.getElementById("orderDetailsTitle").textContent = `Заказ №${orderId}`;
  body.innerHTML = `<div class="skeleton"></div>`;
  modal.classList.add("open");
  try {
    const order = await api(`/api/orders/${orderId}`);
    const header = order.header;
    const modifiersByItem = {};
    await Promise.all(order.items.map(async (item) => {
      try {
        modifiersByItem[item.orderItemId] = await api(`/api/orders/${orderId}/items/${item.orderItemId}/modifiers`);
      } catch {
        modifiersByItem[item.orderItemId] = [];
      }
    }));
    const renderItem = (item) => {
      const mods = modifiersByItem[item.orderItemId] || [];
      const modLine = mods.length
        ? `<div class="small muted">Модификаторы: ${mods.map((m) => `${escapeHtml(m.modifierName)} (+${money(m.priceDelta)})`).join(", ")}</div>`
        : `<div class="small muted">Без модификаторов</div>`;
      return `<tr>
        <td>${escapeHtml(item.dishName)}${modLine}
          ${canCreateOrders ? `<button class="btn small secondary" data-add-mod="${item.orderItemId}">+ Модификатор</button>` : ""}</td>
        <td>${item.quantity}</td>
        <td>${money(item.priceAtOrder)}</td>
        <td>${money(item.lineTotal)}</td>
      </tr>`;
    };
    body.innerHTML = `
      <div class="grid cols-2">
        <div class="notice"><strong>Статус:</strong> ${statusBadge(header.orderStatus)}<br>
          <strong>Тип:</strong> ${escapeHtml(header.orderType)}<br>
          <strong>Столик:</strong> ${escapeHtml(header.tableNumber || "—")}<br>
          <strong>Клиент:</strong> ${escapeHtml(header.customerFullName || "—")} ${escapeHtml(header.customerPhone || "")}</div>
        <div class="notice"><strong>Сотрудник:</strong> ${escapeHtml(header.employeeFullName || "—")}<br>
          <strong>Дата:</strong> ${formatDate(header.orderDate)}<br>
          <strong>Скидка:</strong> ${header.discountPercent}%<br>
          <strong>Сумма:</strong> ${money(header.totalAmount)}</div>
      </div>
      <div class="table-wrap">
        <table><thead><tr><th>Блюдо</th><th>Кол-во</th><th>Цена</th><th>Сумма</th></tr></thead>
          <tbody>${order.items.map(renderItem).join("")}</tbody>
        </table>
      </div>
      <p class="hint">${escapeHtml(header.notes || "Без комментария")}</p>`;

    body.querySelectorAll("[data-add-mod]").forEach((button) =>
      button.addEventListener("click", () => addModifierToItem(orderId, Number(button.dataset.addMod))));
  } catch (error) {
    body.innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
  }
}

async function addModifierToItem(orderId, orderItemId) {
  try {
    const all = (await api("/api/modifiers")).filter((m) => m.isActive);
    if (all.length === 0) {
      toast("Нет доступных модификаторов", "warning");
      return;
    }
    const list = all.map((m, i) => `${i + 1}. ${m.modifierName} (+${money(m.priceDelta)})${m.dishName ? ` — ${m.dishName}` : ""}`).join("\n");
    const answer = window.prompt(`Выберите номера модификаторов через запятую:\n\n${list}`, "");
    if (answer === null) return;
    const ids = answer.split(",").map((part) => all[Number(part.trim()) - 1]?.modifierId).filter(Boolean);
    if (ids.length === 0) {
      toast("Ничего не выбрано", "warning");
      return;
    }
    const result = await api(`/api/orders/${orderId}/items/${orderItemId}/modifiers`, {
      method: "POST",
      body: JSON.stringify({ modifierIds: ids })
    });
    toast(`Модификаторы добавлены, сумма заказа: ${money(result.totalAmount)}`, "success");
    await showOrderDetails(orderId);
  } catch (error) {
    toast(error.message, "error");
  }
}

async function changeOrderStatus(orderId, next) {
  try {
    await api(`/api/orders/${orderId}/status`, {
      method: "POST",
      body: JSON.stringify({ status: next, comment: null })
    });
    toast(`Заказ №${orderId}: ${next}`, "success");
    await loadOrders();
  } catch (error) {
    toast(error.message, "error");
  }
}

async function payOrder(orderId) {
  const method = window.prompt("Способ оплаты: Наличные, Карта или Онлайн", "Карта");
  if (!method) return;
  if (!["Наличные", "Карта", "Онлайн"].includes(method.trim())) {
    toast("Допустимые способы: Наличные, Карта, Онлайн", "warning");
    return;
  }
  try {
    const result = await api(`/api/orders/${orderId}/pay`, {
      method: "POST",
      body: JSON.stringify({ paymentMethod: method.trim() })
    });
    toast(`Заказ №${orderId} оплачен на ${money(result.amount)}`, "success");
    await loadOrders();
  } catch (error) {
    toast(error.message, "error");
  }
}

async function cancelOrder(orderId) {
  const reason = window.prompt("Причина отмены", "Отказ гостя");
  if (reason === null) return;
  try {
    await api(`/api/orders/${orderId}/cancel`, {
      method: "POST",
      body: JSON.stringify({ status: "Отменён", comment: reason || null })
    });
    toast(`Заказ №${orderId} отменён`, "success");
    await loadOrders();
  } catch (error) {
    toast(error.message, "error");
  }
}

/* ---------------- New order ---------------- */
async function openNewOrder() {
  if (!canCreateOrders) return;
  document.getElementById("newOrderForm").reset();
  document.getElementById("newOrderError").textContent = "";
  document.getElementById("newOrderModal").classList.add("open");

  if (state.tables.length === 0) await loadTablesData();
  if (canManage && state.customers.length === 0) await loadCustomersData();
  if (state.dishes.length === 0) await loadDishesData();

  document.getElementById("newOrderTable").innerHTML =
    `<option value="">Выберите столик</option>` +
    state.tables.map((table) => `<option value="${table.tableId}">${escapeHtml(table.tableNumber)} · ${escapeHtml(table.hall)} · ${table.seats} мест</option>`).join("");
  document.getElementById("newOrderCustomer").innerHTML =
    `<option value="">Без клиента</option>` +
    state.customers.map((customer) => `<option value="${customer.customerId}">${escapeHtml(customer.lastName)} ${escapeHtml(customer.firstName)} · ${escapeHtml(customer.phone || "")}</option>`).join("");
  renderNewOrderDishes();
}

function renderNewOrderDishes() {
  const query = document.getElementById("newOrderDishSearch").value.trim().toLowerCase();
  const container = document.getElementById("newOrderDishes");
  const dishes = state.dishes.filter((dish) => !query ||
    dish.dishName.toLowerCase().includes(query) ||
    dish.categoryName.toLowerCase().includes(query));
  container.innerHTML = `<div class="pick-list">${dishes.map((dish) => `
    <div class="pick-row">
      <div><strong>${escapeHtml(dish.dishName)}</strong><div class="small muted">${escapeHtml(dish.categoryName)} · ${money(dish.price)}</div></div>
      <div class="qty"><input type="number" min="0" max="99" value="0" data-order-dish="${dish.dishId}" aria-label="Количество ${escapeHtml(dish.dishName)}"></div>
    </div>`).join("")}</div>`;
}

document.getElementById("newOrderDishSearch").addEventListener("input", renderNewOrderDishes);

document.getElementById("newOrderForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const errorBox = document.getElementById("newOrderError");
  errorBox.textContent = "";
  const orderType = form.orderType.value;
  const tableId = form.tableId.value ? Number(form.tableId.value) : null;
  const customerId = form.customerId.value ? Number(form.customerId.value) : null;

  if (orderType === "В зале" && !tableId) {
    errorBox.textContent = "Для заказа в зале выберите столик.";
    return;
  }
  if (orderType === "Доставка" && !customerId) {
    errorBox.textContent = "Для доставки выберите клиента.";
    return;
  }

  const items = [...document.querySelectorAll("[data-order-dish]")]
    .map((input) => ({ dishId: Number(input.dataset.orderDish), quantity: Number(input.value) }))
    .filter((item) => item.quantity > 0);
  if (items.length === 0) {
    errorBox.textContent = "Добавьте хотя бы одно блюдо.";
    return;
  }

  const button = form.querySelector("button[type=submit]");
  button.disabled = true;
  try {
    const result = await api("/api/orders", {
      method: "POST",
      body: JSON.stringify({
        tableId,
        customerId,
        orderType,
        notes: form.notes.value.trim() || null,
        items
      })
    });
    closeModal("newOrderModal");
    toast(`Заказ №${result.orderId} создан на ${money(result.total)}`, "success");
    await loadOrders();
  } catch (error) {
    errorBox.textContent = error.message;
  } finally {
    button.disabled = false;
  }
});

/* ---------------- Reservations ---------------- */
async function loadReservations() {
  const params = new URLSearchParams();
  const from = document.getElementById("reservationsFrom").value;
  const to = document.getElementById("reservationsTo").value;
  if (from) params.set("from", from);
  if (to) params.set("to", to);
  state.reservations = await api(`/api/reservations?${params.toString()}`);
  renderReservations();
}

function renderReservations() {
  const body = document.getElementById("reservationsBody");
  if (state.reservations.length === 0) {
    body.innerHTML = `<tr><td colspan="9" class="muted">Бронирований не найдено.</td></tr>`;
    return;
  }
  body.innerHTML = state.reservations.map((reservation) => `<tr>
    <td>${reservation.reservationId}</td>
    <td>${formatDate(reservation.reservationDate)}</td>
    <td>${reservation.guestsCount}</td>
    <td>${escapeHtml(reservation.tableNumber)} · ${escapeHtml(reservation.hall)}</td>
    <td>${escapeHtml(reservation.customer)}</td>
    <td>${escapeHtml(reservation.phone)}</td>
    <td>${escapeHtml(reservation.manager)}</td>
    <td>${statusBadge(reservation.reservationStatus)}</td>
    <td class="actions">
      ${reservation.reservationStatus === "Активна" && canCreateOrders
        ? `<button class="btn secondary" data-res-status="${reservation.reservationId}" data-next="Выполнена">Выполнена</button>` : ""}
      ${reservation.reservationStatus === "Активна" && canCreateOrders
        ? `<button class="btn danger" data-res-cancel="${reservation.reservationId}">Отмена</button>` : ""}
    </td></tr>`).join("");

  body.querySelectorAll("[data-res-status]").forEach((button) =>
    button.addEventListener("click", () => changeReservationStatus(Number(button.dataset.resStatus), button.dataset.next)));
  body.querySelectorAll("[data-res-cancel]").forEach((button) =>
    button.addEventListener("click", () => cancelReservation(Number(button.dataset.resCancel))));
}

async function changeReservationStatus(id, status) {
  try {
    await api(`/api/reservations/${id}/status`, {
      method: "POST",
      body: JSON.stringify({ status, comment: null })
    });
    toast("Статус брони обновлён", "success");
    await loadReservations();
  } catch (error) {
    toast(error.message, "error");
  }
}

async function cancelReservation(id) {
  if (!window.confirm("Отменить бронирование?")) return;
  try {
    await api(`/api/reservations/${id}/cancel`, { method: "POST" });
    toast("Бронирование отменено", "success");
    await loadReservations();
  } catch (error) {
    toast(error.message, "error");
  }
}

document.getElementById("newReservationBtn").hidden = !canCreateOrders;
document.getElementById("newReservationBtn").addEventListener("click", async () => {
  if (state.tables.length === 0) await loadTablesData();
  const date = new Date();
  date.setDate(date.getDate() + 1);
  document.getElementById("nrDate").value = formatDateInput(date);
  document.getElementById("nrDate").min = formatDateInput(new Date());
  document.getElementById("nrTable").innerHTML = state.tables.map((table) =>
    `<option value="${table.tableId}">${escapeHtml(table.tableNumber)} · ${escapeHtml(table.hall)} · ${table.seats} мест</option>`).join("");
  document.getElementById("newReservationError").textContent = "";
  document.getElementById("newReservationForm").reset();
  document.getElementById("nrDate").value = formatDateInput(date);
  document.getElementById("nrTime").value = "19:00";
  document.getElementById("nrGuests").value = "2";
  document.getElementById("newReservationModal").classList.add("open");
});

document.getElementById("newReservationForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const errorBox = document.getElementById("newReservationError");
  errorBox.textContent = "";
  const date = form.date.value;
  const time = form.time.value;
  if (!validateCustomerForm(form, errorBox)) return;

  const button = form.querySelector("button[type=submit]");
  button.disabled = true;
  try {
    const result = await api("/api/reservations", {
      method: "POST",
      body: JSON.stringify({
        customerId: null,
        tableId: Number(form.tableId.value),
        reservationDate: `${date}T${time}:00`,
        guestsCount: Number(form.guests.value),
        notes: form.notes.value.trim() || null,
        customer: {
          lastName: form.lastName.value.trim(),
          firstName: form.firstName.value.trim(),
          middleName: null,
          phone: form.phone.value.trim(),
          email: null
        }
      })
    });
    closeModal("newReservationModal");
    toast(`Бронь №${result.reservationId} создана`, "success");
    await loadReservations();
  } catch (error) {
    errorBox.textContent = error.message;
  } finally {
    button.disabled = false;
  }
});

/* ---------------- Tables ---------------- */
async function loadTablesData() {
  state.tables = await api("/api/tables");
  return state.tables;
}

async function loadTables() {
  await loadTablesData();
  const grid = document.getElementById("tablesGrid");
  const free = state.tables.filter((table) => table.tableStatus === "Свободен").length;
  document.getElementById("tablesSummary").textContent = `Свободно: ${free} из ${state.tables.length}`;
  grid.innerHTML = state.tables.map((table) => `
    <article class="card table-card">
      <div class="spread"><span class="table-no">${escapeHtml(table.tableNumber)}</span>${statusBadge(table.tableStatus)}</div>
      <div class="small muted">${escapeHtml(table.hall)} · ${table.seats} мест</div>
      <div class="row" ${canCreateOrders ? "" : "hidden"}>
        <button class="btn small secondary" data-table="${table.tableId}" data-state="Свободен">Свободен</button>
        <button class="btn small secondary" data-table="${table.tableId}" data-state="Занят">Занят</button>
        <button class="btn small secondary" data-table="${table.tableId}" data-state="Забронирован">Бронь</button>
        <button class="btn small secondary" data-table="${table.tableId}" data-state="Неактивен">Стоп</button>
      </div>
    </article>`).join("");

  grid.querySelectorAll("[data-table]").forEach((button) =>
    button.addEventListener("click", async () => {
      try {
        await api(`/api/tables/${button.dataset.table}/status`, {
          method: "PUT",
          body: JSON.stringify({ status: button.dataset.state })
        });
        toast("Статус столика обновлён", "success");
        await loadTables();
      } catch (error) {
        toast(error.message, "error");
      }
    }));
}

/* ---------------- Dishes ---------------- */
async function loadDishesData() {
  [state.dishes, state.categories] = await Promise.all([
    api("/api/dishes"),
    api("/api/categories")
  ]);
}

async function loadDishes() {
  await loadDishesData();
  const body = document.getElementById("dishesBody");
  body.innerHTML = state.dishes.map((dish) => `<tr>
    <td>${dish.dishId}</td>
    <td>${escapeHtml(dish.categoryName)}</td>
    <td>${escapeHtml(dish.dishName)}</td>
    <td>${money(dish.price)}</td>
    <td>${dish.weightGr ? `${dish.weightGr} г` : "—"}</td>
    <td>${dish.isAvailable ? `<span class="badge success">Да</span>` : `<span class="badge danger">Нет</span>`}</td>
    <td class="actions">
      ${canManage ? `<button class="btn secondary" data-dish-edit="${dish.dishId}">Изменить</button>
      <button class="btn danger" data-dish-delete="${dish.dishId}">Скрыть</button>
      <button class="btn small secondary" data-dish-stop="${dish.dishId}">В стоп-лист</button>` : "—"}
    </td></tr>`).join("");

  body.querySelectorAll("[data-dish-edit]").forEach((button) =>
    button.addEventListener("click", () => openDishModal(Number(button.dataset.dishEdit))));
  body.querySelectorAll("[data-dish-delete]").forEach((button) =>
    button.addEventListener("click", () => deleteDish(Number(button.dataset.dishDelete))));
  body.querySelectorAll("[data-dish-stop]").forEach((button) =>
    button.addEventListener("click", () => addDishToStopList(Number(button.dataset.dishStop))));

  const canSeeStoplist = ["Director", "DatabaseAdmin", "Waiter", "Chef"].includes(role);
  const stoplistCard = document.getElementById("stoplistBody")?.closest(".card");
  if (stoplistCard) stoplistCard.hidden = !canSeeStoplist;
  if (canSeeStoplist) await loadStopList();
  await loadRecipes();
}

document.getElementById("newDishBtn").hidden = !canManage;
document.getElementById("newDishBtn").addEventListener("click", () => openDishModal(null));

function openDishModal(dishId) {
  if (!canManage) return;
  const form = document.getElementById("dishForm");
  form.reset();
  document.getElementById("dishError").textContent = "";
  document.getElementById("dishCategory").innerHTML = state.categories
    .map((category) => `<option value="${category.categoryId}">${escapeHtml(category.categoryName)}</option>`).join("");
  const dish = state.dishes.find((item) => item.dishId === dishId);
  form.dishId.value = dish?.dishId || "";
  form.dishName.value = dish?.dishName || "";
  form.categoryId.value = String(dish?.categoryId || state.categories[0]?.categoryId || "");
  form.price.value = dish?.price ?? "";
  form.weightGr.value = dish?.weightGr ?? "";
  form.description.value = dish?.description || "";
  form.isAvailable.checked = dish ? dish.isAvailable : true;
  document.getElementById("dishModalTitle").textContent = dish ? "Редактирование блюда" : "Новое блюдо";
  document.getElementById("dishModal").classList.add("open");
}

document.getElementById("dishForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const errorBox = document.getElementById("dishError");
  errorBox.textContent = "";
  const id = form.dishId.value ? Number(form.dishId.value) : null;
  const payload = {
    categoryId: Number(form.categoryId.value),
    dishName: form.dishName.value.trim(),
    price: Number(form.price.value),
    weightGr: form.weightGr.value ? Number(form.weightGr.value) : null,
    description: form.description.value.trim() || null,
    isAvailable: form.isAvailable.checked
  };
  if (!payload.dishName || !payload.categoryId || !(payload.price > 0)) {
    errorBox.textContent = "Заполните название, категорию и цену.";
    return;
  }

  try {
    if (id) {
      await api(`/api/dishes/${id}`, { method: "PUT", body: JSON.stringify(payload) });
      toast("Блюдо обновлено", "success");
    } else {
      await api("/api/dishes", { method: "POST", body: JSON.stringify(payload) });
      toast("Блюдо добавлено", "success");
    }
    closeModal("dishModal");
    await loadDishes();
  } catch (error) {
    errorBox.textContent = error.message;
  }
});

async function deleteDish(id) {
  if (!window.confirm("Снять блюдо с продажи?")) return;
  try {
    await api(`/api/dishes/${id}`, { method: "DELETE" });
    toast("Блюдо снято с продажи", "success");
    await loadDishes();
  } catch (error) {
    toast(error.message, "error");
  }
}

async function addDishToStopList(dishId) {
  const reason = prompt("Причина добавления в стоп-лист:", "Нет продукта на складе");
  if (!reason?.trim()) return;
  try {
    await api("/api/stoplist", {
      method: "POST",
      body: JSON.stringify({ dishId, reason: reason.trim(), minStockLeft: true, isEmergency: false, emergencyLimit: null })
    });
    toast("Блюдо добавлено в стоп-лист", "success");
    await loadDishes();
  } catch (error) {
    toast(error.message, "error");
  }
}

document.getElementById("importForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const file = form.file.files[0];
  if (!file) return;
  const data = new FormData();
  data.append("file", file);
  try {
    const result = await api("/api/import/dishes", { method: "POST", body: data });
    toast(`Импортировано: ${result.imported}, пропущено: ${result.skipped}`, result.errors?.length ? "warning" : "success", 7000);
    if (result.errors?.length) console.warn(result.errors);
    form.reset();
    await loadDishes();
  } catch (error) {
    toast(error.message, "error");
  }
});

/* ---------------- Стоп-лист и рецепты ---------------- */
async function loadStopList() {
  const body = document.getElementById("stoplistBody");
  if (!body) return;
  try {
    const items = await api("/api/stoplist");
    body.innerHTML = items.map((item) => `<tr>
      <td>${item.stopItemId}</td>
      <td>${escapeHtml(item.dishName)}</td>
      <td class="small">${escapeHtml(item.reason)}</td>
      <td>${item.minStockLeft ? `<span class="badge warning">Да</span>` : "Нет"}</td>
      <td>${item.isEmergency ? `<span class="badge">Лимит ${item.emergencyLimit}</span>` : "—"}</td>
      <td>${formatDate(item.createdAt)}</td>
      <td class="actions">${canKitchen ? `<button class="btn small secondary" data-stop-edit="${item.stopItemId}">Изменить</button>` : ""}
        ${canKitchen ? `<button class="btn small danger" data-stop-remove="${item.stopItemId}">Скрыть</button>` : "—"}</td>
    </tr>`).join("") || `<tr><td colspan="7" class="muted">Стоп-лист пуст.</td></tr>`;
    body.querySelectorAll("[data-stop-edit]").forEach((button) =>
      button.addEventListener("click", async () => {
        const reason = prompt("Причина стоп-листа:", items.find((item) => String(item.stopItemId) === button.dataset.stopEdit)?.reason || "");
        if (!reason?.trim()) return;
        try {
          await api(`/api/stoplist/${button.dataset.stopEdit}`, {
            method: "PUT",
            body: JSON.stringify({ reason: reason.trim() })
          });
          toast("Стоп-лист обновлён", "success");
          await loadStopList();
        } catch (error) { toast(error.message, "error"); }
      }));
    body.querySelectorAll("[data-stop-remove]").forEach((button) =>
      button.addEventListener("click", async () => {
        try {
          await api(`/api/stoplist/${button.dataset.stopRemove}`, { method: "DELETE" });
          toast("Позиция снята со стоп-листа", "success");
          await loadStopList();
        } catch (error) {
          toast(error.message, "error");
        }
      }));
  } catch (error) {
    body.innerHTML = `<tr><td colspan="7" class="muted">${escapeHtml(error.message)}</td></tr>`;
  }
}

document.getElementById("newStopItemBtn").hidden = !canKitchen;
document.getElementById("newStopItemBtn").addEventListener("click", async () => {
  const dishId = Number(prompt("ID блюда для стоп-листа:"));
  if (!dishId) return;
  const reason = prompt("Причина:", "Нет продукта на складе");
  if (!reason) return;
  try {
    await api("/api/stoplist", {
      method: "POST",
      body: JSON.stringify({ dishId, reason, minStockLeft: true, isEmergency: false, emergencyLimit: null })
    });
    toast("Блюдо добавлено в стоп-лист", "success");
    await loadStopList();
  } catch (error) {
    toast(error.message, "error");
  }
});

async function loadRecipes() {
  const body = document.getElementById("recipesBody");
  if (!body) return;
  const filter = document.getElementById("recipeDishFilter");
  const dishId = filter?.value ? Number(filter.value) : null;
  try {
    const [recipes, dishes] = await Promise.all([
      api(`/api/recipes${dishId ? `?dishId=${dishId}` : ""}`),
      state.dishes.length ? Promise.resolve(state.dishes) : api("/api/dishes")
    ]);
    if (filter && filter.options.length <= 1) {
      filter.innerHTML = `<option value="">Все блюда</option>` + dishes
        .map((dish) => `<option value="${dish.dishId}">${escapeHtml(dish.dishName)}</option>`).join("");
      filter.onchange = () => loadRecipes();
    }
    body.innerHTML = recipes.map((row) => `<tr>
      <td>${row.recipeItemId}</td>
      <td>${escapeHtml(row.dishName)}</td>
      <td>${escapeHtml(row.nomenclatureName)}</td>
      <td>${row.quantityNorm}</td>
      <td>${escapeHtml(row.unit)}</td>
      <td>${row.prepTimeMinutes ?? "—"}</td>
      <td class="small">${escapeHtml(row.notes || "—")}</td>
    </tr>`).join("") || `<tr><td colspan="7" class="muted">Рецепты не найдены.</td></tr>`;
  } catch (error) {
    body.innerHTML = `<tr><td colspan="7" class="muted">${escapeHtml(error.message)}</td></tr>`;
  }
}

document.getElementById("newRecipeBtn").hidden = !canManage;
document.getElementById("newRecipeBtn").addEventListener("click", async () => {
  const dishId = Number(prompt("ID блюда:"));
  if (!dishId) return;
  const nomenclatureId = Number(prompt("ID позиции номенклатуры (склад):"));
  if (!nomenclatureId) return;
  const quantityNorm = Number(prompt("Норма закладки (кол-во за порцию):", "0.1"));
  if (!quantityNorm || quantityNorm <= 0) return;
  try {
    await api("/api/recipes", {
      method: "POST",
      body: JSON.stringify({ dishId, nomenclatureId, quantityNorm, prepTimeMinutes: null, notes: null })
    });
    toast("Ингредиент добавлен в техкарту", "success");
    await loadRecipes();
  } catch (error) {
    toast(error.message, "error");
  }
});

/* ---------------- Customers / Employees / Audit ---------------- */
async function loadCustomersData() {
  const search = document.getElementById("customersSearch")?.value.trim() || "";
  const params = new URLSearchParams();
  if (search) params.set("search", search);
  state.customers = await api(`/api/customers?${params.toString()}`);
  return state.customers;
}

async function loadCustomers() {
  await loadCustomersData();
  const body = document.getElementById("customersBody");
  body.innerHTML = state.customers.map((customer) => {
    const actions = canManage ? `
      <button class="btn small secondary" data-bonus-add="${customer.customerId}">+бонусы</button>
      <button class="btn small secondary" data-bonus-spend="${customer.customerId}">−бонусы</button>
      <button class="btn small secondary" data-consent="${customer.customerId}">Согласие</button>` : "—";
    return `<tr>
    <td>${customer.customerId}</td>
    <td>${escapeHtml(customer.lastName)}</td>
    <td>${escapeHtml(customer.firstName)}</td>
    <td>${escapeHtml(customer.phone || "—")}</td>
    <td>${escapeHtml(customer.email || "—")}</td>
    <td>${formatDate(customer.registrationDate, false)}</td>
    <td>${customer.loyaltyPoints}</td>
    <td class="actions">${actions}</td>
  </tr>`;
  }).join("") || `<tr><td colspan="8" class="muted">Клиентов не найдено.</td></tr>`;

  body.querySelectorAll("[data-bonus-add], [data-bonus-spend]").forEach((button) =>
    button.addEventListener("click", () => changeBonus(button)));
  body.querySelectorAll("[data-consent]").forEach((button) =>
    button.addEventListener("click", () => giveConsent(button)));
}

async function changeBonus(button) {
  const customerId = Number(button.dataset.bonusAdd || button.dataset.bonusSpend);
  const accrue = Boolean(button.dataset.bonusAdd);
  const points = Number(prompt(`${accrue ? "Начислить" : "Списать"} бонусы гостю №${customerId}:`, "50"));
  if (!points || Number.isNaN(points)) return;
  try {
    await api("/api/loyalty/bonuses", {
      method: "POST",
      body: JSON.stringify({
        customerId,
        orderId: null,
        points: accrue ? Math.abs(points) : -Math.abs(points),
        opType: accrue ? "Начисление" : "Списание",
        reason: accrue ? "Начисление менеджером" : "Списание при оплате"
      })
    });
    toast(accrue ? "Бонусы начислены" : "Бонусы списаны", "success");
    await loadCustomers();
  } catch (error) {
    toast(error.message, "error");
  }
}

async function giveConsent(button) {
  const customerId = Number(button.dataset.consent);
  const text = prompt("Текст согласия на обработку ПДн:", "Согласие на обработку персональных данных (редакция 2026.1)");
  if (!text) return;
  try {
    await api("/api/consents", {
      method: "POST",
      body: JSON.stringify({
        customerId,
        employeeId: null,
        consentType: "Обработка ПДн",
        consentText: text,
        expiresAt: null,
        basis: "Согласие субъекта"
      })
    });
    toast("Согласие зафиксировано (новая версия)", "success");
  } catch (error) {
    toast(error.message, "error");
  }
}

let customersSearchTimer;
document.getElementById("customersSearch").addEventListener("input", () => {
  clearTimeout(customersSearchTimer);
  customersSearchTimer = setTimeout(() => loadCurrentTab(), 300);
});

async function loadEmployees() {
  state.employees = await api("/api/employees");
  document.getElementById("employeesSummary").textContent = `Всего: ${state.employees.length}`;
  document.getElementById("employeesBody").innerHTML = state.employees.map((employee) => `<tr>
    <td>${employee.employeeId}</td>
    <td>${escapeHtml(employee.lastName)} ${escapeHtml(employee.firstName)} ${escapeHtml(employee.middleName || "")}</td>
    <td>${escapeHtml(employee.post)}</td>
    <td>${escapeHtml(employee.roleName)}</td>
    <td>${escapeHtml(employee.phone || "—")}</td>
    <td>${formatDate(employee.hireDate, false)}</td>
    <td>${employee.isActive ? `<span class="badge success">Да</span>` : `<span class="badge danger">Нет</span>`}</td>
  </tr>`).join("");
}

async function loadAudit() {
  const params = new URLSearchParams();
  const from = document.getElementById("auditFrom").value;
  const to = document.getElementById("auditTo").value;
  const login = document.getElementById("auditLogin").value.trim();
  if (from) params.set("from", from);
  if (to) params.set("to", to);
  if (login) params.set("login", login);
  state.audit = await api(`/api/audit?${params.toString()}`);
  document.getElementById("auditBody").innerHTML = state.audit.map((entry) => `<tr>
    <td>${formatDate(entry.actionTime)}</td>
    <td>${escapeHtml(entry.loginName || "—")}</td>
    <td><span class="badge">${escapeHtml(entry.actionType)}</span></td>
    <td>${escapeHtml(entry.objectName)} ${escapeHtml(entry.objectId || "")}</td>
    <td class="small">${escapeHtml(entry.oldValue || "—")}</td>
    <td class="small">${escapeHtml(entry.newValue || "—")}</td>
    <td class="small">${escapeHtml(entry.details || "")}</td>
  </tr>`).join("") || `<tr><td colspan="7" class="muted">Записей нет.</td></tr>`;
}

/* ---------------- Settings ---------------- */
async function loadSettings() {
  state.settings = await api("/api/settings");
  const form = document.getElementById("settingsForm");
  form.theme.value = state.settings.theme;
  form.dateFormat.value = state.settings.dateFormat;
  form.numberFormat.value = state.settings.numberFormat;
  form.pageSize.value = state.settings.pageSize;
  form.savedFilters.value = state.settings.savedFilters || "";
  applyTheme(state.settings.theme);
}

document.getElementById("settingsForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const payload = {
    theme: form.theme.value,
    dateFormat: form.dateFormat.value,
    numberFormat: form.numberFormat.value,
    pageSize: Number(form.pageSize.value),
    savedFilters: form.savedFilters.value.trim() || null
  };
  try {
    await api("/api/settings", { method: "PUT", body: JSON.stringify(payload) });
    localStorage.setItem("restaurant_theme", payload.theme);
    applyTheme(payload.theme);
    toast("Настройки сохранены", "success");
  } catch (error) {
    toast(error.message, "error");
  }
});

document.getElementById("ordersFilterBtn").addEventListener("click", loadOrders);
document.getElementById("exportMenuBtn")?.addEventListener("click", async (event) => {
  const button = event.currentTarget;
  button.disabled = true;
  try {
    const csv = await api("/api/export/menu.csv");
    const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = "menu.csv";
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
  } catch (error) {
    toast(error.message, "error");
  } finally {
    button.disabled = false;
  }
});
document.getElementById("reservationsFilterBtn").addEventListener("click", loadReservations);
document.getElementById("auditFilterBtn").addEventListener("click", loadAudit);
document.getElementById("ordersSearch").addEventListener("input", renderOrders);

/* ---------------- Hotkeys ---------------- */
document.addEventListener("keydown", (event) => {
  const tag = document.activeElement?.tagName;
  const typing = tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT";

  if (event.altKey && /^[1-8]$/.test(event.key)) {
    event.preventDefault();
    const name = Object.keys(tabAccess)[Number(event.key) - 1];
    if (name) switchTab(name);
  }
  if (event.key === "F2") {
    event.preventDefault();
    openNewOrder();
  }
  if (event.key === "F5") {
    event.preventDefault();
    loadCurrentTab();
  }
  if (event.key.toLowerCase() === "k" && (event.ctrlKey || event.metaKey)) {
    event.preventDefault();
    if (state.tab === "orders") document.getElementById("ordersSearch").focus();
    else if (state.tab === "customers") document.getElementById("customersSearch").focus();
    else if (state.tab === "dishes") document.getElementById("newOrderDishSearch")?.focus();
  }
  if (event.key.toLowerCase() === "s" && (event.ctrlKey || event.metaKey) && state.tab === "settings") {
    event.preventDefault();
    document.getElementById("settingsForm").requestSubmit();
  }
  if (event.key === "Escape") {
    document.querySelectorAll(".modal-backdrop.open").forEach((modal) => modal.classList.remove("open"));
  }
  if (event.key === "/" && !typing) {
    event.preventDefault();
    document.querySelector(".tab-panel.active input[type=search]")?.focus();
  }
});

/* ---------------- Helpers ---------------- */
function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

switchTab(Object.keys(tabAccess).find((name) => tabAccess[name]) || "settings");
