import KanbanDragDrop from "./kanban_drag_drop";
import CommandPalette from "./command_palette";
import CategorySearch from "./category_search";

const Hooks = {
  TimezoneInput: {
    mounted() {
      this.el.value = Intl.DateTimeFormat().resolvedOptions().timeZone;
    },
  },
  KanbanDragDrop,
  CommandPalette,
  CategorySearch,
};

export default Hooks;
