import { LightningElement, api } from "lwc";

export default class UserProfile extends LightningElement {
  @api attributes;
  @api fields;
  @api picklists;
  @api cta;

  connectedCallback() {
    const attr = {};
    Object.keys(this.fields).forEach((key) => {
      if (key === "address")
        return (attr["address"] = {
          street: this.attributes.address?.street || "",
          city: this.attributes.address?.city || "",
          state: this.attributes.address?.state || "",
          zipcode: this.attributes.address?.zipcode || "",
          country: this.attributes.address?.country || "",
        });
      return (attr[key] = this.attributes[key] || "");
    });
    this.attributes = Object.assign({}, this.attributes, attr);
  }

  _picture;
  get picture() {
    return this._picture || this.attributes.picture;
  }

  get zoneinfos() {
    const defaultTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    return this.picklists.zoneinfo.map((zone) => {
      return Object.assign({}, zone, {
        defaultValue:
          zone.value === (this.attributes.zoneinfo || defaultTimeZone),
      });
    });
  }

  get locales() {
    const defaultLocale = (navigator.languages ? navigator.languages[0] : navigator.language).replace("-", "_");
    return this.picklists.locale.map((locale) => {
      return Object.assign({}, locale, {
        defaultValue:
          locale.value === (this.attributes.locale || defaultLocale),
      });
    });
  }

  async handleSubmit(e) {
    e.preventDefault();
    const user = { address: {} };
    for (let entry of new FormData(this.template.querySelector("form")).entries()) {
      const [key, value] = entry;
      if (key === "picture") {
        if (value.size != 0) {
          user["picture"] = {
            // Use a regex to remove data url part
            blob: (await this.readFile(value)).replace("data:", "").replace(/^.+,/, ""),
            contentType: value.type,
            filename: value.name,
          };
        }
      } else if (key.indexOf("address.") === 0) {
        user.address[key.split("address.")[1]] = value;
      } else {
        user[key] = value;
      }
    }
    this.dispatchEvent(new CustomEvent("save", { detail: user }));
  }

  readFile(file) {
    return new Promise((resolve) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(reader.result);
      reader.readAsDataURL(file);
    });
  }
}
