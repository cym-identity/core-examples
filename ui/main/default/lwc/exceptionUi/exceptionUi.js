import { LightningElement, api } from 'lwc';

export default class ExceptionUi extends LightningElement {
  @api
  get exception() {
    return { message: this.message, name: this.name, stackTrace: this.stackTrace}
  }

  expanded = false;
  closed = false;

  set exception(e) {
    if (!e) return;
    const {name, message} = e;
    if ( name ) {
      this.name = name + '::' + message;
      this.stackTrace = e.stack;
    } else {
      this.name = e.error;
      this.stackTrace = JSON.stringify(e.error_stack_trace, null, 2);
    }
    this.closed = false;
  }
  name;
  stackTrace;

  expand() {
    this.expanded = !this.expanded;
  }
  close() {
    this.closed = !this.closed;
    if (this.closed) this.expanded = false;
  }
}