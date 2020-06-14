import RestModel from "discourse/models/rest";
import Category from "discourse/models/category";
import {
  default as computed,
  observes
} from "discourse-common/utils/decorators";

export default RestModel.extend({
  available_filters: [
    {
      id: "watch",
      name: I18n.t("chat_integration.filter.watch"),
      icon: "exclamation-circle"
    },
    {
      id: "follow",
      name: I18n.t("chat_integration.filter.follow"),
      icon: "circle"
    },
    {
      id: "mute",
      name: I18n.t("chat_integration.filter.mute"),
      icon: "times-circle"
    }
  ],

  available_types: [
    { id: "normal", name: I18n.t("chat_integration.type.normal") },
    {
      id: "group_message",
      name: I18n.t("chat_integration.type.group_message")
    },
    { id: "group_mention", name: I18n.t("chat_integration.type.group_mention") }
  ],

  available_styles: [
    { id: "long", name: I18n.t("chat_integration.style.long") },
    { id: "medium", name: I18n.t("chat_integration.style.medium") },
    { id: "short", name: I18n.t("chat_integration.style.short") }
  ],

  category_id: null,
  tags: null,
  channel_id: null,
  filter: "watch",
  type: "normal",
  style: "medium",
  error_key: null,

  @observes("type")
  removeUnneededInfo() {
    const type = this.get("type");

    if (type === "normal") {
      this.set("group_id", null);
    } else {
      this.set("category_id", null);
    }
  },

  @computed("category_id")
  category(categoryId) {
    if (categoryId) {
      return Category.findById(categoryId);
    } else {
      return false;
    }
  },

  @computed("filter")
  filterName(filter) {
    return I18n.t(`chat_integration.filter.${filter}`);
  },

  @computed("style")
  styleName(style) {
    return I18n.t(`chat_integration.style.${style}`);
  },

  updateProperties() {
    return this.getProperties([
      "type",
      "category_id",
      "group_id",
      "tags",
      "filter",
      "style"
    ]);
  },

  createProperties() {
    return this.getProperties([
      "type",
      "channel_id",
      "category_id",
      "group_id",
      "tags",
      "filter",
      "style"
    ]);
  }
});
