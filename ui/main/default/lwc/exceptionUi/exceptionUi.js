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
    this.closed = false;
    this.name = e.error;
    this.stackTrace = JSON.stringify(e.error_stack_trace, null, 2);
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