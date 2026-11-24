const reviewForm = document.getElementById("reviewForm");
const reviewError = document.getElementById("reviewError");
const publishedReviews = document.getElementById("publishedReviews");

function reviewEscape(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

async function loadPublishedReviews() {
  if (!publishedReviews) return;
  try {
    const reviews = await api("/api/guest/reviews");
    const visible = reviews.slice(0, 10);
    publishedReviews.innerHTML = visible.length
      ? visible.map((review) => `
        <article class="card flat">
          <div class="spread"><strong>${reviewEscape(review.customerName || "Гость")}</strong><span class="badge success">${review.rating}/5</span></div>
          <p>${reviewEscape(review.comment)}</p>
          <div class="small muted">${formatDate(review.reviewDate, false)}</div>
        </article>`).join("")
      : '<p class="muted mb-0">Опубликованных отзывов пока нет.</p>';
  } catch (error) {
    publishedReviews.innerHTML = `<p class="muted mb-0">${reviewEscape(error.message)}</p>`;
  }
}

reviewForm?.addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  reviewError.textContent = "";
  if (!form.checkValidity()) {
    reviewError.textContent = "Проверьте имя, фамилию, телефон, оценку и текст отзыва.";
    return;
  }
  const payload = {
    lastName: form.lastName.value.trim(),
    firstName: form.firstName.value.trim(),
    phone: form.phone.value.trim(),
    rating: Number(form.rating.value),
    comment: form.comment.value.trim()
  };
  const button = form.querySelector("button[type=submit]");
  button.disabled = true;
  try {
    const result = await api("/api/guest/reviews", { method: "POST", body: JSON.stringify(payload) });
    form.reset();
    toast(result.message, "success", 7000);
    await loadPublishedReviews();
  } catch (error) {
    reviewError.textContent = error.message;
  } finally {
    button.disabled = false;
  }
});

loadPublishedReviews();
