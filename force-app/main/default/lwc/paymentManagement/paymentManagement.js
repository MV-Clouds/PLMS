import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getPayments from '@salesforce/apex/PaymentManagementController.getPayments';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

const columns = [
    { label: 'Payment Number', fieldName: 'paymentNameUrl', type: 'url',typeAttributes: {
        label: { fieldName: 'Name' }, 
        target: '_blank'
      }, sortable: "true" },
    { label: 'Amount', fieldName: 'Amount__c', type: 'currency', sortable: "true" },
    { label: 'Invoice', fieldName: 'InvoiceLink', type: 'url', 
        typeAttributes: { label: { fieldName: 'invoiceName' }, target: '_blank' }, sortable: "true" },
    { label: 'Payment Date', fieldName: 'Payment_Date__c', type: 'date', sortable: "true" },
    { label: 'Method', fieldName: 'Payment_Method__c', type: 'text', sortable: "true" },
    { label: 'Transaction Id', fieldName: 'Transaction_Id__c', type: 'text', sortable: "true" },
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Edit', name: 'edit' }] },
    },
];

export default class PaymentManagement extends NavigationMixin(LightningElement) {
    @track payments = [];
    searchTerm = '';
    columns = columns;
    isLoading = false;
    pageNumber = 1;
    pageSize = 10;
    totalRecords = 0;
    subscription = {};
    channelName = '/data/Payment__ChangeEvent';
    searchTimeout;
    @track allPayments = []; // Store all payments for search, sort, and pagination
    connectedCallback() {
        this.handleSubscribe();
        onError(error => {
            console.error('Server-side error occurred: ', JSON.stringify(error));
        });
        this.fetchPayments();
    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    handleSubscribe() {
        const messageCallback = (response) => {
            console.log('New message received: ', JSON.stringify(response));
            this.fetchPayments();
        };

        subscribe(this.channelName, -1, messageCallback).then(response => {
            console.log('Subscription request sent to: ', JSON.stringify(response.channel));
            this.subscription = response;
        });
    }

    handleUnsubscribe() {
        unsubscribe(this.subscription, response => {
            console.log('unsubscribe() response: ', JSON.stringify(response));
        });
    }

    sortBy = 'Name';
    sortDirection = 'asc';

    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.applySearchSortAndPagination();
    }

    fetchPayments() {
        this.isLoading = true;
        getPayments()
            .then(result => {
                console.log();
                this.allPayments = result.payments.map(payment => ({
                    ...payment,
                    paymentNameUrl : `/lightning/r/${payment.Id}/view`,
                    invoiceName : payment.Invoice__c ? payment.Invoice__r.Name : 'N/A',
                    InvoiceLink: payment.Invoice__c ? `/lightning/r/${payment.Invoice__c}/view` : null,
                }));
                this.totalRecords = result.totalRecords; // Update totalRecords based on allPayments length
                console.log(this.allPayments);
                console.log('Total Records:', this.totalRecords);
                this.applySearchSortAndPagination();
            })
            .catch(error => {
                console.log(error);
                console.error('Error fetching payments:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    applySearchSortAndPagination() {
        try {
            
        
        let filteredData = [...this.allPayments];

        // Apply search
        if (this.searchTerm) {
            const lowerCaseSearchTerm = this.searchTerm.toLowerCase();
            filteredData = filteredData.filter(payment =>
                (payment.Name && payment.Name.toLowerCase().includes(lowerCaseSearchTerm)) ||
                (payment.Invoice__r && payment.Invoice__r.Name && payment.Invoice__r.Name.toLowerCase().includes(lowerCaseSearchTerm)) ||
                (payment.Payment_Method__c && payment.Payment_Method__c.toLowerCase().includes(lowerCaseSearchTerm)) ||
                (payment.Transaction_Id__c && payment.Transaction_Id__c.toLowerCase().includes(lowerCaseSearchTerm))
            );
        }

        // Apply sorting
        if (this.sortBy) {
            const reverse = this.sortDirection === 'desc' ? -1 : 1;
            filteredData.sort((a, b) => {
                const aValue = a[this.sortBy] ? (typeof a[this.sortBy] === 'string' ? a[this.sortBy].toLowerCase() : a[this.sortBy]) : '';
                const bValue = b[this.sortBy] ? (typeof b[this.sortBy] === 'string' ? b[this.sortBy].toLowerCase() : b[this.sortBy]) : '';
                return reverse * ((aValue > bValue) - (bValue > aValue));
            });
        }

        this.totalRecords = filteredData.length;

        // Apply pagination
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = this.pageSize * this.pageNumber;
        this.payments = filteredData.slice(start, end);
        } catch (error) {
            console.error('Error in applySearchSortAndPagination:', error);   
        }
        
    }

    get isRecords() {
        return !(this.payments && this.payments.length > 0);
    }

    get totalPages() {
        return Math.ceil(this.totalRecords / this.pageSize);
    }

    get isFirstPage() {
        return this.pageNumber === 1;
    }

    get isLastPage() {
        return this.pageNumber * this.pageSize >= this.totalRecords;
    }

    get isSearchbarDisabled(){
        return !this.allPayments || this.allPayments.length === 0;
    }

    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
        this.pageNumber = 1; // Reset to first page on new search
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.applySearchSortAndPagination();
        }, 300);
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.applySearchSortAndPagination();
        }
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.applySearchSortAndPagination();
        }
    }

    async handleNewPayment() {
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Payment__c',
                    actionName: 'new'
                },
                state: {
                    count: '1',
                    nooverride: '1',
                    navigationLocation: 'RELATED_LIST',
                }
            });
        } catch (error) {
            console.error('Error navigating to new payment page:', error);
        }
    }

    handleRowAction(event) {
        try{
            const actionName = event.detail.action.name;
            const recordId = event.detail.row.Id;
            console.log('Row action:', actionName, 'for record ID:', recordId);
            if (actionName === 'edit') {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: recordId,
                        objectApiName: 'Payment__c',
                        actionName: 'edit'
                    }
                });
            }
        }catch(error){
            console.error('Error in handleRowAction:', error);
        }
    }
}