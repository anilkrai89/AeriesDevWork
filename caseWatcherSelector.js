import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import searchContacts from '@salesforce/apex/CaseWatcherController.searchContacts';

export default class CaseWatcherSelector extends LightningElement {

    // 🔒 EXISTING FLOW-BOUND OUTPUTS (must keep)
    @api selectedContactIds = [];
    @api selectedEmails = [];

    // 🔒 CSV OUTPUTS (used to update Case field)
    @api selectedContactIdsCsv = '';
    @api selectedEmailsCsv = '';

    // Internal state
    searchResults = [];
    contactEmailMap = new Map();

    // UI helper
    get selectedEmailsString() {
        return this.selectedEmailsCsv;
    }

    handleSearch(event) {
        const key = event.target.value;

        if (!key || key.length < 2) {
            this.searchResults = [];
            return;
        }

        searchContacts({ searchKey: key })
            .then(results => {
                this.contactEmailMap.clear();
                this.searchResults = results.map(c => {
                    this.contactEmailMap.set(c.Id, c.Email.toLowerCase());
                    return {
                        id: c.Id,
                        label: `${c.Name} (${c.Email})`
                    };
                });
            })
            .catch(error => console.error(error));
    }

    addWatcher(event) {
        const contactId = event.target.dataset.id;
        const email = this.contactEmailMap.get(contactId);

        if (!email) {
            return;
        }

        // ✅ Append contactId (dedup)
        if (!this.selectedContactIds.includes(contactId)) {
            this.selectedContactIds = [...this.selectedContactIds, contactId];
        }

        // ✅ Append email (dedup)
        if (!this.selectedEmails.includes(email)) {
            this.selectedEmails = [...this.selectedEmails, email];
        }

        // ✅ EXPLICITLY recompute CSVs (critical)
        this.selectedContactIdsCsv = this.selectedContactIds.join(',');
        this.selectedEmailsCsv = this.selectedEmails.join(',');

        // 🔔 Notify Flow of ALL changes (critical)
        this.dispatchEvent(new FlowAttributeChangeEvent(
            'selectedContactIds',
            this.selectedContactIds
        ));
        this.dispatchEvent(new FlowAttributeChangeEvent(
            'selectedEmails',
            this.selectedEmails
        ));
        this.dispatchEvent(new FlowAttributeChangeEvent(
            'selectedContactIdsCsv',
            this.selectedContactIdsCsv
        ));
        this.dispatchEvent(new FlowAttributeChangeEvent(
            'selectedEmailsCsv',
            this.selectedEmailsCsv
        ));

        // Reset results list
        this.searchResults = [];
    }
}