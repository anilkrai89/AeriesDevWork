import { LightningElement, api, wire } from "lwc";
import getState from "@salesforce/apex/AccountSubscriptionController.getState";
import subscribe from "@salesforce/apex/AccountSubscriptionController.subscribe";
import unsubscribe from "@salesforce/apex/AccountSubscriptionController.unsubscribe";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { CloseActionScreenEvent } from "lightning/actions";

export default class AccountSubscriptionAction extends LightningElement {
  @api recordId; // Account Id coming from the record page / quick action

  loading = true;
  state;
  wiredResult;

  // Wire Apex state (cacheable)
  @wire(getState, { accountId: "$recordId" })
  wiredState(result) {
    this.wiredResult = result;
    const { data, error } = result;

    // When recordId is not available yet, wire can fire with undefined
    if (!this.recordId) {
      this.loading = false;
      return;
    }

    if (data) {
      this.state = data;
      this.loading = false;
    } else if (error) {
      this.loading = false;
      this.toast("Error", this.reduceError(error), "error");
    }
  }

  get isSubscribed() {
    return !!(this.state?.exists && this.state?.active);
  }

  get buttonLabel() {
  return this.isSubscribed ? "Stop notifying me on new cases" : "Notify me on new cases";
}

get statusText() {
  if (!this.recordId) return "No Account context found.";
  if (this.loading) return "Loading notification setting...";
  return this.isSubscribed
    ? "To unsubscribe from new Support case notification, click the button below."
    : "In order to be notified when a new Support case is submitted, click the button below.";
}


  get disableButton() {
    return this.loading || !this.recordId;
  }

  async handleClick() {
    if (!this.recordId) {
      this.toast("Error", "Account Id not found.", "error");
      return;
    }

    this.loading = true;
    try {
      if (this.isSubscribed) {
        await unsubscribe({ accountId: this.recordId });
        this.toast("Success", "Unsubscribed.", "success");
      } else {
        await subscribe({ accountId: this.recordId });
        this.toast("Success", "Subscribed.", "success");
      }

      // Refresh wired state so UI flips Subscribe <-> Unsubscribe
      await refreshApex(this.wiredResult);

      // If you are using this as a Quick Action (modal), close after action
      this.dispatchEvent(new CloseActionScreenEvent());
    } catch (e) {
      this.toast("Error", this.reduceError(e), "error");
    } finally {
      this.loading = false;
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  reduceError(err) {
    // Handles typical Apex & UI API error shapes
    if (!err) return "Unknown error";

    const body = err.body;
    if (Array.isArray(body)) {
      return body.map((e) => e.message).join(", ");
    }
    if (body?.message) {
      return body.message;
    }
    return err.message || "Unknown error";
  }
}