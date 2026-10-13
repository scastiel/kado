// Previous / next buttons for the screenshot rail. The rail scrolls on its own — by touch,
// trackpad, or keyboard once focused — so without this script the buttons stay hidden and
// nothing is lost; with a mouse wheel and no trackpad they are the only easy way along.
(() => {
  const rail = document.querySelector(".screenshot-rail");
  const controls = document.querySelector(".rail-controls");
  if (!rail || !controls) return;

  const [previous, next] = controls.querySelectorAll("button");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

  const update = () => {
    const overflows = rail.scrollWidth > rail.clientWidth + 1;
    controls.hidden = !overflows;
    previous.disabled = rail.scrollLeft <= 1;
    next.disabled = rail.scrollLeft + rail.clientWidth >= rail.scrollWidth - 1;
  };

  controls.addEventListener("click", (event) => {
    const button = event.target.closest("button[data-rail]");
    if (!button) return;
    rail.scrollBy({
      left: Number(button.dataset.rail) * rail.clientWidth * 0.8,
      behavior: reduceMotion.matches ? "auto" : "smooth",
    });
  });

  rail.addEventListener("scroll", update, { passive: true });
  window.addEventListener("resize", update);
  update();
})();
