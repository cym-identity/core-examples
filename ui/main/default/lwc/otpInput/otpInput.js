import { LightningElement, api } from "lwc";

export default class OtpInput extends LightningElement {
  @api length = 6;

  callbacks = [];
  fields = [];
  otp = [];

  connectedCallback() {
    for (let i = 0; i < this.length; i++) {
      this.callbacks.push({
        oninput: function (e) {
          this.otp[i] = e.data;
          if (e.data) {
            if (i < this.length - 1) {
              this.fields[i + 1].focus();
            } else {
              this.fields[i].blur();
            }
          }
          this.otp.filter((el) => !!el).length === this.length
            ? this.dispatchEvent(
                new CustomEvent("otpchange", { detail: this.otp.join("") })
              )
            : this.dispatchEvent(
                new CustomEvent("otpchange", { detail: undefined })
              );
        },
        onpaste: function (event) {
          console.log(
            "paste",
            (event.clipboardData || window.clipboardData).getData("text")
          );
        },
        onfocus: function(e) {
          if (e.target.value) e.target.select();
        }
      });
    }
  }
  renderedCallback() {
    this.fields = this.template.querySelectorAll(".slds-input.otp-input");
  }
}
