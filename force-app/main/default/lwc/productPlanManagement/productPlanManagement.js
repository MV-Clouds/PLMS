import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { refreshApex } from '@salesforce/apex';
import getProducts from '@salesforce/apex/ProductPlanManagementController.getProducts';
import getProductPlans from '@salesforce/apex/ProductPlanManagementController.getProductPlans';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

const columns = [
    { label: 'Plan Name', fieldName: 'planNameUrl',typeAttributes: {
        label: { fieldName: 'Name' }, 
        target: '_blank'
      }, type: 'url' ,sortable: "true"},
    { label: 'Price', fieldName: 'Price__c', type: 'currency' ,sortable: "true"},
    { label: 'Description', fieldName: 'Description__c', type: 'text' },
    {
        type: 'action', 
        typeAttributes: { rowActions: [{ label: 'Edit', name: 'edit' }] },
    },
];

export default class ProductPlanManagement extends NavigationMixin(LightningElement) {
    @track products = [];
    selectedProductId = '';
    searchTerm = '';
    @track productPlans = [];
    columns = columns;
    isLoading = false;
    pageNumber = 1;
    pageSize = 10;
    totalRecords = 0;
    subscription = {};
    channelName = '/data/Product_Plan__ChangeEvent';
    searchTimeout;


    connectedCallback() {
        this.handleSubscribe();
        onError(error => {
            console.error('Server-side error occurred: ', JSON.stringify(error));
        });
    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    handleSubscribe() {
        const messageCallback = (response) => {
            console.log('New message received: ', JSON.stringify(response));
            this.fetchProductPlans();
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

    @wire(getProducts)
    getProducts({ error, data }) {
        if (data) {
            this.products = data.map(product => ({
                label: product.Name,
                value: product.Id
            }));
            if (this.products.length > 0 && !this.selectedProductId) {
                this.selectedProductId = this.products[0].value;
                this.fetchProductPlans();
            }
        } else if (error) {
            console.error('Error fetching products:', error);
        }
    }
    

    sortBy = 'Name';
    sortDirection = 'asc';

    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.fetchProductPlans();
    }

    @track allProductPlans = [];

    fetchProductPlans() {
        this.isLoading = true;
        getProductPlans({ productId: this.selectedProductId })
            .then(result => {
                this.allProductPlans = result.plans.map(plan => ({
                    ...plan,
                    planNameUrl: `/lightning/r/${plan.Id}/view`,
                }));
                this.totalRecords = this.allProductPlans.length;
                this.applySearchSortAndPagination();
            })
            .catch(error => {
                console.error('Error fetching product plans:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    applySearchSortAndPagination() {
        let filteredData = [...this.allProductPlans];

        // Apply search
        if (this.searchTerm) {
            const lowerCaseSearchTerm = this.searchTerm.toLowerCase();
            filteredData = filteredData.filter(plan =>
                (plan.Name && plan.Name.toLowerCase().includes(lowerCaseSearchTerm)) ||
                (plan.Description__c && plan.Description__c.toLowerCase().includes(lowerCaseSearchTerm))
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
        this.productPlans = filteredData.slice(start, end);
    }

    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.applySearchSortAndPagination();
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

    get newButtonDisabled() {
        return !this.selectedProductId;
    }

    get isRecords() {
        return !(this.productPlans && this.productPlans.length > 0);
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

    get isSearchbarDisabled() {
        return !this.allProductPlans || this.allProductPlans.length === 0;
    }

    handleProductChange(event) {
        this.selectedProductId = event.detail.value;
        this.pageNumber = 1;
        this.fetchProductPlans();
    }

    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
        this.pageNumber = 1;
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.applySearchSortAndPagination();
        }, 300);
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.fetchProductPlans();
        }
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.fetchProductPlans();
        }
    }

    async handleNewPlan() {
        try {
            const defaultValues = encodeDefaultFieldValues({
                Product__c: this.selectedProductId,
            });
            
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Product_Plan__c',
                    actionName: 'new'
                },
                state: {
                    count: '1',
                    nooverride: '1',
                    defaultFieldValues: defaultValues,
                    navigationLocation: 'RELATED_LIST',
                }
            });
        } catch (error) {
            
        }
    }

    

    handleRowAction(event) {
        try{
            const actionName = event.detail.action.name;
            const recordId = event.detail.row.Id;
            if (actionName === 'edit') {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: recordId,
                        objectApiName: 'Product_Plan__c',
                        actionName: 'edit'
                    }
                });
            }
        }catch(error){
            console.error('Error in handleRowAction:', error);
        }
    }
}