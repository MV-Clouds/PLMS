import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getProducts from '@salesforce/apex/ProductVersionManagementController.getProducts';
import getProductVersions from '@salesforce/apex/ProductVersionManagementController.getProductVersions';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

const columns = [
    { label: 'Name', fieldName: 'productVersionNameUrl', type: 'url',typeAttributes: {
        label: { fieldName: 'Name' }, 
        target: '_blank'
      } ,sortable: "true"},
    { label: 'Version Number', fieldName: 'Version_Number__c', type: 'text' ,sortable: "true"},
    { label: 'Type', fieldName: 'Type__c', type: 'text' ,sortable: "true"},
    { label: 'Release Notes', fieldName: 'Release_Notes__c', type: 'text' },
    { label: 'Version URL', fieldName: 'Version_URL__c', type: 'url' },
    { label: 'Password', fieldName: 'Password__c', type: 'text' },
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Edit', name: 'edit' }] },
    },
];

export default class ProductVersionManagement extends NavigationMixin(LightningElement) {
    @track products = [];
    selectedProductId = '';
    searchTerm = '';
    @track productVersions = [];
    columns = columns;
    isLoading = false;
    pageNumber = 1;
    pageSize = 10;
    totalRecords = 0;
    subscription = {};
    channelName = '/data/Product_Version__ChangeEvent';
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
            this.fetchProductVersions();
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
                this.fetchProductVersions();
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
        this.fetchProductVersions();
    }

    @track allProductVersions = [];

    fetchProductVersions() {
        console.log('fetchProductVersions called with selectedProductId:');
        this.isLoading = true;
        getProductVersions({ productId: this.selectedProductId })
            .then(result => {
                this.allProductVersions = result.versions.map(version => ({
                    ...version,
                    productVersionNameUrl: `/lightning/r/${version.Id}/view`,
                }));
                this.totalRecords = this.allProductVersions.length;
                this.applySearchSortAndPagination();
            })
            .catch(error => {
                console.error('Error fetching product versions:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    applySearchSortAndPagination() {
        let filteredData = [...this.allProductVersions];

        // Apply search
        if (this.searchTerm) {
            const lowerCaseSearchTerm = this.searchTerm.toLowerCase();
            filteredData = filteredData.filter(version =>
                (version.Name && version.Name.toLowerCase().includes(lowerCaseSearchTerm)) ||
                (version.Version_Number__c && version.Version_Number__c.toLowerCase().includes(lowerCaseSearchTerm)) ||
                (version.Type__c && version.Type__c.toLowerCase().includes(lowerCaseSearchTerm)) ||
                (version.Release_Notes__c && version.Release_Notes__c.toLowerCase().includes(lowerCaseSearchTerm))
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
        this.productVersions = filteredData.slice(start, end);
    }

    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.applySearchSortAndPagination();
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

    get newButtonDisabled() {
        return !this.selectedProductId;
    }

    get isRecords() {
        return !(this.productVersions && this.productVersions.length > 0);
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
        return !this.allProductVersions || this.allProductVersions.length === 0;
    }

    handleProductChange(event) {
        this.selectedProductId = event.detail.value;
        this.pageNumber = 1;
        this.fetchProductVersions();
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.fetchProductVersions();
        }
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.fetchProductVersions();
        }
    }

    async handleNewVersion() {
        try {
            const defaultValues = encodeDefaultFieldValues({
                Product__c: this.selectedProductId,
            });
            
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Product_Version__c',
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
                        objectApiName: 'Product_Version__c',
                        actionName: 'edit'
                    }
                });
            }
        }catch(error){
            console.error('Error in handleRowAction:', error);
        }
    }
}