import { LightningElement, api } from 'lwc';

export default class UserChooser extends LightningElement {
  @api users = [];
  @api email = "";
  @api phoneNumber = "";
  @api login;

  loading = false;
  step = "discovery";
  error;

  get canShowAccountChooser() { return this.step === "account_chooser"; }
  get canShowDiscovery() { return this.step === "discovery";}
  get _users() {
    return this.users.map((u) => {
      return Object.assign({
        isTwitter : u.login_type === 'Twitter',
        isFacebook : u.login_type === 'Facebook',
        isLinkedIn : u.login_type === 'LinkedIn',
        isGoogle : u.login_type === 'Google',
        isPhone : u.login_type === 'phone',
        isEmail: u.login_type === 'email',
        handleClick: () => this.handleUserSelected( u ),
      }, u);
    });
  }
  connectedCallback() {
    if (this.users && this.users.length > 0) this.step = 'account_chooser';
  }
  chooseAnotherUser() {
    this.step = "discovery";
    this.email = "";
    this.phoneNumber = "";
  }
  backToChooser() {
    this.step = "account_chooser";
  }
  handleEmailChange(e) {
    this.phoneNumber = "";
    this.email = e.target.value;
  }
  handlePhoneChange(e) {
    this.email = "";
    this.phoneNumber = e.detail.number;
  }
  handleDiscover(e) {
    if (e) e.preventDefault();
    this.handleUserSelected( { login_hint: this.email || this.phoneNumber, login_type: this.email ? 'email' : 'phone' } );
  }
  handleUserSelected({ login_hint, login_type }) {
    this.dispatchEvent(new CustomEvent('done', { detail : { login_hint, login_type }}));
  }
}