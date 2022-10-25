import { LightningElement, api } from 'lwc';
import { remote } from 'c/fetch';

// Import custom labels
import twilio_verify_register_description from '@salesforce/label/c.twilio_verify_register_description';
import twilio_verify_register_phone_label from '@salesforce/label/c.twilio_verify_register_phone_label';
import twilio_verify_register_button from '@salesforce/label/c.twilio_verify_register_button';
import twilio_verify_otp_description from '@salesforce/label/c.twilio_verify_otp_description';
import twilio_verify_otp_otp_label from '@salesforce/label/c.twilio_verify_otp_otp_label';
import twilio_verify_otp_button from '@salesforce/label/c.twilio_verify_otp_button';

export default class TwilioSmsRegister extends LightningElement {
  @api user;
  @api requestId;

  labels = {
    twilio_verify_register_description,
    twilio_verify_register_phone_label,
    twilio_verify_register_button,
    twilio_verify_otp_description,
    twilio_verify_otp_otp_label,
    twilio_verify_otp_button
  }

  loading = false;
  error;

  phoneNumber;
  sid;
  otp = "";

  get canRegisterDisabled() { return !this.phoneNumber; }
  get canVerifyDisabled() { return !this.otp || this.otp.length !== 6; }

  handlePhoneChange(e) {
    this.phoneNumber = e.detail.number;
  }

  handleOtpChange(e) {
    this.otp = e.target.value;
  }

  handleRegisterPhone(e) {
    e.preventDefault();
    if (true) this.sid = 123456
    this.loading = true;
    remote("TwilioVerifySmsController.InitRegistration", {phoneNumber: this.phoneNumber, userId: this.user.id, requestId: this.requestId})
      .then( ({sid}) => {
        this.loading = false;
        this.sid = sid;
      })
      .catch(error => (this.error = error, this.loading = false))
  }

  handleVerify(e) {
    e.preventDefault();
    this.loading = true;
    remote("TwilioVerifySmsController.VerifyRegistration", {phoneNumber: this.phoneNumber, userId: this.user.id, requestId: this.requestId, sid: this.sid, otp: this.otp})
      .then( ({ isValid }) => {
        if (isValid) this.dispatchEvent(new CustomEvent("done"));
      })
      .catch(error => (this.error = error, this.loading = false))
  }

  handleResend(e) {
    e.preventDefault();

  }

}