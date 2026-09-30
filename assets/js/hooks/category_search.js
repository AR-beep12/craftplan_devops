const CategorySearch = {
  mounted() {
    this.openEvent = this.el.dataset.openEvent || "open_dropdown";
    this.closeEvent = this.el.dataset.closeEvent || "close_dropdown";
    this.handleFocusIn = this.handleFocusIn.bind(this);
    this.handleFocusOut = this.handleFocusOut.bind(this);
    this.el.addEventListener("focusin", this.handleFocusIn);
    this.el.addEventListener("focusout", this.handleFocusOut);
  },

  destroyed() {
    this.el.removeEventListener("focusin", this.handleFocusIn);
    this.el.removeEventListener("focusout", this.handleFocusOut);
    clearTimeout(this.closeTimer);
  },

  push(event, payload = {}) {
    this.pushEventTo(`#${this.el.id}`, event, payload);
  },

  handleFocusIn() {
    clearTimeout(this.closeTimer);
    this.push(this.openEvent);
  },

  handleFocusOut() {
    clearTimeout(this.closeTimer);
    this.closeTimer = setTimeout(() => {
      if (this.el.contains(document.activeElement)) return;
      this.push(this.closeEvent);
    }, 150);
  },
};

export default CategorySearch;
