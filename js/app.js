const CART_KEY = "restaurant_cart";

const state = {
  menu: [],
  categories: [],
  tables: [],
  categoryId: null,
  search: "",
  cart: loadCart()
};

let reservationMinimum = null;

function loadCart() {
  try {
    const parsed = JSON.parse(localStorage.getItem(CART_KEY) || "[]");
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function saveCart() {
  localStorage.setItem(CART_KEY, JSON.stringify(state.cart));
}

async function loadMenu() {
  try {
    const [menu, categories, tables] = await Promise.all([
      api("/api/menu"),
      api("/api/categories"),
      api("/api/tables").catch(() => [])
    ]);
    state.menu = menu;
    state.categories = categories;
    state.tables = tables;
    renderCategories();
    renderMenu();
    fillReservationDefaults();
  } catch (error) {
    document.getElementById("menuGrid").innerHTML =
      `<div class="empty"><strong>Не удалось загрузить меню</strong>${escapeHtml(error.message)}</div>`;
  }
}

function renderCategories() {
  const container = document.getElementById("categoryChips");
  const items = [{ CategoryId: null, CategoryName: "Всё меню" }, ...state.categories];
  container.innerHTML = items.map((category) => `
    <button class="chip ${state.categoryId === category.CategoryId ? "active" : ""}"
            type="button" data-category="${category.CategoryId ?? ""}">
      ${escapeHtml(category.CategoryName)}
    </button>`).join("");

  container.querySelectorAll("[data-category]").forEach((button) => {
    button.addEventListener("click", () => {
      state.categoryId = button.dataset.category ? Number(button.dataset.category) : null;
      renderCategories();
      renderMenu();
    });
  });
}

function renderMenu() {
  const grid = document.getElementById("menuGrid");
  const query = state.search.trim().toLowerCase();
  const filtered = state.menu.filter((dish) => {
    const categoryMatch = state.categoryId === null || dish.categoryId === state.categoryId;
    const searchMatch = !query ||
      dish.dishName.toLowerCase().includes(query) ||
      (dish.description || "").toLowerCase().includes(query);
    return categoryMatch && searchMatch;
  });

  if (filtered.length === 0) {
    grid.innerHTML = `<div class="empty"><strong>Ничего не найдено</strong>Попробуйте другой запрос или категорию.</div>`;
    return;
  }

  grid.innerHTML = filtered.map((dish) => `
    <article class="dish-card">
      <div class="spread">
        <span class="badge info">${escapeHtml(dish.categoryName)}</span>
        <span class="meta">${dish.weightGr ? `${dish.weightGr} г` : ""}</span>
      </div>
      <div>
        <h3>${escapeHtml(dish.dishName)}</h3>
        <p class="desc">${escapeHtml(dish.description || "Авторское блюдо от шеф-повара.")}</p>
      </div>
      <div class="spread">
        <span class="price">${money(dish.price)}</span>
        <button class="btn small" type="button" data-add="${dish.dishId}">В заказ</button>
      </div>
    </article>`).join("");

  grid.querySelectorAll("[data-add]").forEach((button) => {
    button.addEventListener("click", () => addToCart(Number(button.dataset.add)));
  });
}

function addToCart(dishId) {
  const dish = state.menu.find((item) => item.dishId === dishId);
  if (!dish) return;
  const existing = state.cart.find((item) => item.dishId === dishId);
  if (existing) existing.quantity += 1;
  else state.cart.push({ dishId, name: dish.dishName, price: dish.price, quantity: 1 });
  saveCart();
  renderCart();
  toast(`«${dish.dishName}» добавлено в заказ`, "success");
}

function changeQuantity(dishId, delta) {
  const item = state.cart.find((entry) => entry.dishId === dishId);
  if (!item) return;
  item.quantity += delta;
  if (item.quantity <= 0) state.cart = state.cart.filter((entry) => entry.dishId !== dishId);
  saveCart();
  renderCart();
}

function renderCart() {
  const container = document.getElementById("cartItems");
  const count = state.cart.reduce((sum, item) => sum + item.quantity, 0);
  const total = state.cart.reduce((sum, item) => sum + item.price * item.quantity, 0);

  document.getElementById("cartCount").textContent = `${count} ${plural(count, ["позиция", "позиции", "позиций"])}`;
  document.getElementById("cartTotal").textContent = money(total);
  document.getElementById("checkoutBtn").disabled = state.cart.length === 0;

  if (state.cart.length === 0) {
    container.innerHTML = `<p class="muted small mb-0">Корзина пуста. Добавьте блюда из меню.</p>`;
    return;
  }

  container.innerHTML = state.cart.map((item) => `
    <div class="cart-item">
      <div>
        <strong>${escapeHtml(item.name)}</strong>
        <div class="small muted">${money(item.price)} × ${item.quantity} = ${money(item.price * item.quantity)}</div>
      </div>
      <div class="qty">
        <button type="button" data-minus="${item.dishId}" aria-label="Уменьшить">−</button>
        <span>${item.quantity}</span>
        <button type="button" data-plus="${item.dishId}" aria-label="Увеличить">+</button>
      </div>
    </div>`).join("");

  container.querySelectorAll("[data-minus]").forEach((button) =>
    button.addEventListener("click", () => changeQuantity(Number(button.dataset.minus), -1)));
  container.querySelectorAll("[data-plus]").forEach((button) =>
    button.addEventListener("click", () => changeQuantity(Number(button.dataset.plus), 1)));
}

function openOrderModal() {
  if (state.cart.length === 0) return;
  const tableSelect = document.getElementById("orderTable");
  if (tableSelect && tableSelect.options.length <= 1) {
    tableSelect.innerHTML = `<option value="">Выберите столик</option>` +
      (state.tables || []).filter((t) => t.tableStatus !== "Неактивен").map((t) =>
        `<option value="${t.tableId}">${escapeHtml(t.tableNumber)} · ${escapeHtml(t.hall)} · ${t.seats} мест</option>`).join("");
  }
  const total = state.cart.reduce((sum, item) => sum + item.price * item.quantity, 0);
  document.getElementById("orderSummary").innerHTML =
    `<strong>${state.cart.reduce((sum, item) => sum + item.quantity, 0)} поз.</strong> на сумму ${money(total)}. ` +
    `После подтверждения заказ поступит на кухню.`;
  document.getElementById("orderError").textContent = "";
  document.getElementById("orderModal").classList.add("open");
  document.getElementById("orderLastName").focus();
}

function closeOrderModal() {
  document.getElementById("orderModal").classList.remove("open");
}

async function submitOrder(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const errorBox = document.getElementById("orderError");
  errorBox.textContent = "";

  const lastName = form.lastName.value.trim();
  const firstName = form.firstName.value.trim();
  const phone = form.phone.value.trim();
  const email = form.email.value.trim();
  if (!form.checkValidity()) {
    errorBox.textContent = "Проверьте фамилию, имя и телефон: используйте буквы и телефон формата +7 (999) 123-45-67.";
    return;
  }

  const button = form.querySelector("button[type=submit]");
  button.disabled = true;
  try {
    const result = await api("/api/public/orders", {
      method: "POST",
      body: JSON.stringify({
        customer: { lastName, firstName, middleName: null, phone, email: email || null },
        orderType: form.type.value,
        tableId: Number(form.tableId.value),
        notes: form.notes.value.trim() || null,
        items: state.cart.map((item) => ({ dishId: item.dishId, quantity: item.quantity, comment: null }))
      })
    });
    state.cart = [];
    saveCart();
    renderCart();
    closeOrderModal();
    form.reset();
    toast(`Заказ №${result.orderId} принят. Сумма: ${money(result.total)}`, "success", 7000);
  } catch (error) {
    errorBox.textContent = error.message;
  } finally {
    button.disabled = false;
  }
}

async function loadAvailableTables() {
  const date = document.getElementById("resDate").value;
  const time = document.getElementById("resTime").value || "19:00";
  const guests = Number(document.getElementById("resGuests").value || 1);
  const select = document.getElementById("resTable");
  if (!date) return;

  try {
    const timestamp = `${date}T${time}:00`;
    const tables = await api(`/api/tables/available?date=${encodeURIComponent(timestamp)}&guests=${guests}`);
    select.innerHTML = `<option value="">Подберём автоматически</option>` +
      tables.map((table) => `<option value="${table.tableId}">${escapeHtml(table.tableNumber)} · ${escapeHtml(table.hall)} · ${table.seats} мест</option>`).join("");
  } catch {
    select.innerHTML = `<option value="">Подберём автоматически</option>`;
  }
}

function formatTimeInput(date) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function applyReservationTimeConstraint() {
  const dateInput = document.getElementById("resDate");
  const timeInput = document.getElementById("resTime");
  if (!reservationMinimum) return;

  const minimumDate = formatDateInput(reservationMinimum);
  if (dateInput.value === minimumDate) {
    const minimumTime = formatTimeInput(reservationMinimum);
    timeInput.min = minimumTime;
    if (!timeInput.value || timeInput.value < minimumTime) timeInput.value = minimumTime;
  } else {
    timeInput.min = "";
  }
}

async function fillReservationDefaults() {
  const dateInput = document.getElementById("resDate");
  const timeInput = document.getElementById("resTime");
  let minimum = new Date(Date.now() + 35 * 60 * 1000);

  try {
    const clock = await api("/api/time");
    const serverMinimum = new Date(clock.minimumReservationTime);
    if (!Number.isNaN(serverMinimum.getTime())) minimum = serverMinimum;
  } catch {
    // Keep the form usable when the clock endpoint is temporarily unavailable.
  }

  const remainder = minimum.getMinutes() % 5;
  const roundUpMinutes = remainder === 0 && minimum.getSeconds() === 0 && minimum.getMilliseconds() === 0
    ? 0
    : 5 - remainder;
  minimum.setMinutes(minimum.getMinutes() + roundUpMinutes, 0, 0);
  reservationMinimum = minimum;
  dateInput.min = formatDateInput(minimum);
  dateInput.value = formatDateInput(minimum);
  timeInput.value = formatTimeInput(minimum);
  applyReservationTimeConstraint();
  await loadAvailableTables();
}

async function submitReservation(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const errorBox = document.getElementById("resError");
  errorBox.textContent = "";

  const lastName = form.lastName.value.trim();
  const firstName = form.firstName.value.trim();
  const phone = form.phone.value.trim();
  const date = form.date.value;
  const time = form.time.value;
  const guests = Number(form.guests.value);
  if (!form.checkValidity()) {
    errorBox.textContent = "Проверьте фамилию, имя и телефон: используйте буквы и телефон формата +7 (999) 123-45-67.";
    return;
  }

  const button = form.querySelector("button[type=submit]");
  button.disabled = true;
  try {
    const result = await api("/api/public/reservations", {
      method: "POST",
      body: JSON.stringify({
        customer: { lastName, firstName, middleName: null, phone, email: null },
        guestsCount: guests,
        reservationDate: `${date}T${time}:00`,
        tableId: form.table.value ? Number(form.table.value) : null,
        notes: form.notes.value.trim() || null
      })
    });
    toast(`Столик забронирован. Номер брони: ${result.reservationId}`, "success", 7000);
    form.reset();
    fillReservationDefaults();
  } catch (error) {
    errorBox.textContent = error.message;
  } finally {
    button.disabled = false;
  }
}

function plural(number, forms) {
  const abs = Math.abs(number) % 100;
  const last = abs % 10;
  if (abs > 10 && abs < 20) return forms[2];
  if (last > 1 && last < 5) return forms[1];
  if (last === 1) return forms[0];
  return forms[2];
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

document.getElementById("menuSearch").addEventListener("input", (event) => {
  state.search = event.target.value;
  renderMenu();
});

document.getElementById("checkoutBtn").addEventListener("click", openOrderModal);
document.getElementById("orderForm").addEventListener("submit", submitOrder);
document.getElementById("reservationForm").addEventListener("submit", submitReservation);

document.querySelectorAll("[data-close-modal]").forEach((button) =>
  button.addEventListener("click", closeOrderModal));
document.getElementById("orderModal").addEventListener("click", (event) => {
  if (event.target.id === "orderModal") closeOrderModal();
});

document.getElementById("resDate").addEventListener("change", () => {
  applyReservationTimeConstraint();
  loadAvailableTables();
});
document.getElementById("resTime").addEventListener("change", loadAvailableTables);
document.getElementById("resGuests").addEventListener("change", loadAvailableTables);

document.addEventListener("keydown", (event) => {
  const tag = document.activeElement?.tagName;
  const typing = tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT";

  if (event.key === "/" && !typing) {
    event.preventDefault();
    document.getElementById("menuSearch").focus();
  }
  if (event.key === "Escape") closeOrderModal();
  if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
    if (document.getElementById("orderModal").classList.contains("open")) {
      event.preventDefault();
      document.getElementById("orderForm").requestSubmit();
    } else if (document.activeElement?.closest("#reservationForm")) {
      event.preventDefault();
      document.getElementById("reservationForm").requestSubmit();
    }
  }
});

renderCart();
loadMenu();
