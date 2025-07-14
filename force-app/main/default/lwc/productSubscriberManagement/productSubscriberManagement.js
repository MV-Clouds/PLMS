import { LightningElement, track } from 'lwc';
import getProducts from '@salesforce/apex/ProductSubscriberManagementController.getProducts';
import getProductSubscribers from '@salesforce/apex/ProductSubscriberManagementController.getProductSubscribers';
import updateProductSubscriber from '@salesforce/apex/ProductSubscriberManagementController.updateProductSubscriber';
import getProductPlans from '@salesforce/apex/ProductSubscriberManagementController.getProductPlans';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Price from '@salesforce/schema/Asset.Price';

const columns = [
    { label: 'Name', fieldName: 'subNameUrl', typeAttributes: {
        label: { fieldName: 'Name' }, 
        target: '_blank'
      }, type: 'url', sortable: true },
    { label: 'Organization/Company Name' , fieldName: 'Org_Name__c', type: 'text', sortable: true },
    { label: 'Install Date' , fieldName: 'Install_Date__c', type: 'date',
         sortable: true },
    { label: 'Product Plan', fieldName: 'productPlanUrl', typeAttributes: {
        label: { fieldName: 'productPlanName' }, 
        target: '_blank'
      }, type: 'url', sortable: true },
    { label: 'Product Version', fieldName: 'productVersionNameUrl', typeAttributes: {
        label: { fieldName: 'productVersionName' }, 
        target: '_blank'
      }, type: 'url', sortable: true },
    { label: 'Expiration DateTime', fieldName: 'Expiration_DateTime__c', type: 'date', sortable: true, typeAttributes: {
        day: 'numeric',
        month: 'numeric',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: true
    }},
    { label: 'Is Trial', fieldName: 'Is_Trial__c', type: 'boolean', sortable: true },
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Edit', name: 'edit' }] },
    },
];

export default class ProductSubscriberManagement extends LightningElement {
    productId = '';
    @track productOptions = [];
    @track planOptions = [];
    @track allSubscribers = [];
    @track subscribers = [];
    columns = columns;
    pageNumber = 1;
    pageSize = 10;
    totalRecords = 0;
    totalPages = 0;
    searchKey = '';
    sortBy = 'Name';
    sortDirection = 'asc';
    isLoading = false;
    isEditModalOpen = false;
    isPreviewModalOpen = false;
    selectedSubscriber = {};
    originalIsTrial = false;
    isTrial = false;
    showPlanDetails = false;
    productPlanId = '';
    productPlanPrice = 'NA';
    discount = 0;
    duration = null;
    newExpirationDateTime = null;
    searchTimeout

    @track previewSubscriber = {};

    
    connectedCallback() {
        this.loadProducts();
        this.loadProductPlans();
    }

    loadProducts() {
        getProducts()
            .then(data => {
                this.productOptions = data.map(product => {
                    return { label: product.Name, value: product.Id };
                });
                if (this.productOptions.length > 0) {
                    this.productId = this.productOptions[0].value;
                    this.loadProductSubscribers();
                }
            })
            .catch(error => {
                console.error('Error loading products', error);
            });
    }

    loadProductSubscribers() {
        getProductSubscribers({ productId: this.productId })
            .then(data => {
                this.allSubscribers = data;
                this.processRecords();
            })
            .catch(error => {
                console.error('Error loading product subscribers', error);
            });
    }

    loadProductPlans() {
        this.isLoading = true;
        getProductPlans()
            .then(data => {
                this.planOptions = data.map(plan => {
                    return { label: plan.Name, value: plan.Id ,price: plan.Price__c};
                });
            })
            .catch(error => {
                console.error('Error loading product plans', error);
            }).finally(()=>{
                this.isLoading = false;
            });
    }

    processRecords() {
        try {
            this.isLoading = true;
            let records = [...this.allSubscribers];
            records = records.map(record => ({
                ...record,
                subNameUrl: `/lightning/r/${record.Id}/view`,
                productPlanName: record.Product_Plan__r ? record.Product_Plan__r.Name : '',
                productPlanUrl: record.Product_Plan__c ? `/lightning/r/${record.Product_Plan__c}/view` : '',
                productVersionName: record.Product_Version__r ? record.Product_Version__r.Name : '',
                productVersionNameUrl: record.Product_Version__c ? `/lightning/r/${record.Product_Version__c}/view` : ''
            }));
            if (this.searchKey) {
                const searchLower = this.searchKey.toLowerCase();
                records = records.filter(record => {
                const nameMatch = record.Name && record.Name.toLowerCase().includes(searchLower);
                const dateMatch = record.Expiration_DateTime__c && record.Expiration_DateTime__c.toLowerCase().includes(searchLower);
                return nameMatch || dateMatch;
                });
            }


            records.sort((a, b) => {
                let aValue = a[this.sortBy];
                let bValue = b[this.sortBy];
                let reverse = this.sortDirection === 'asc' ? 1 : -1;

                if (aValue < bValue) {
                    return -1 * reverse;
                }
                if (aValue > bValue) {
                    return 1 * reverse;
                }
                return 0;
            });

            this.totalRecords = records.length;
            this.totalPages = Math.ceil(this.totalRecords / this.pageSize);
            this.subscribers = records.slice(
                (this.pageNumber - 1) * this.pageSize,
                this.pageNumber * this.pageSize
            );
            this.subscribers = [...this.subscribers];
            this.isLoading = false;
        } catch (error) {
            console.error('Error processing records:', error);
            this.isLoading = false;
        }
    }

    handleProductChange(event) {
        this.productId = event.detail.value;
        this.pageNumber = 1;
        this.loadProductSubscribers();
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        this.pageNumber = 1;
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            console.log('search called' + this.searchKey);
            this.processRecords();
        }, 300);
        
        
    }

    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.processRecords();
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber = this.pageNumber - 1;
            this.processRecords();
        }
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber = this.pageNumber + 1;
            this.processRecords();
        }
    }

    get getOriginalIsTrial(){
        return !this.originalIsTrial;
    }
    
    get isRecords() {
        return !(this.subscribers && this.subscribers.length > 0);
    }

    get isFirstPage() {
        return this.pageNumber === 1;
    }

    get isLastPage() {
        return this.pageNumber * this.pageSize >= this.totalRecords;
    }

    get isSearchbarDisabled() {
        return !this.allSubscribers || this.allSubscribers.length === 0;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'edit') {
            // Dynamically get the org domain from window.location.origin
            const orgDomain = window.location.origin;
            this.selectedSubscriber = {
                id: row.Id,
                productName: row.Product__r && row.Product__r.Name ? row.Product__r.Name : 'NA',
                name: row.Name ? row.Name : 'NA',
                expirationDate: row.Expiration_DateTime__c ? row.Expiration_DateTime__c : 'NA',
                productVersionName: row.Product_Version__r && row.Product_Version__r.Name ? row.Product_Version__r.Name : '',
                productVersionUrl: row.Product_Version__c ? `${orgDomain}/lightning/r/${row.Product_Version__c}/view` : '',
                isproductVersionUrl : row.Product_Version__c ? true : false,
                orgName: row.Org_Name__c ? row.Org_Name__c : 'NA',
                installDate: row.Install_Date__c ? row.Install_Date__c : 'NA',
            };
            this.isTrial = row.Is_Trial__c;
            this.originalIsTrial = row.Is_Trial__c;
            this.showPlanDetails = !row.Is_Trial__c;
            this.productPlanId = row.Product_Plan__c;
            this.productPlanPrice = this.planOptions.find(plan => plan.value === this.productPlanId)?.price || 0;
            this.discount = row.Discount__c || 0;
            this.duration = row.Duration__c;
            this.newExpirationDateTime = row.Expiration_DateTime__c; // Initialize with current value
            this.isEditModalOpen = true;
        }
    }

    closeEditModal() {
        this.isEditModalOpen = false;
    }

    handleIsTrialChange(event) {
        this.isTrial = event.target.checked;
        this.showPlanDetails = !this.isTrial;
        if (!(this.isTrial)) {
            this.calculateExpirationDate();
        }
    }

    handlePlanChange(event) {
        this.productPlanId = event.detail.value;
        this.productPlanPrice = this.planOptions.find(plan => plan.value === this.productPlanId)?.price || 0;
    }

    handleDiscountChange(event) {
        let discountValue = event.target.value;
        // Allow only numbers between 1 and 100, with up to 3 decimal places
        const regex = /^(100(\.0{0,3})?|([1-9][0-9]?|100)(\.\d{0,3})?)$/;
        if (!regex.test(discountValue)) {
            if (discountValue < 0) {
                event.target.setCustomValidity("Discount can't be negative.");
            } else {
                event.target.setCustomValidity('Discount must be a valid number.');
            }
        } else {
            event.target.setCustomValidity('');
            this.discount = discountValue;
        }
        event.target.reportValidity();
    }

    handleDurationChange(event) {
        let durationValue = event.target.value;
        if (durationValue < 0) {
            event.target.setCustomValidity('Duration cannot be negative.');
        } else {
            event.target.setCustomValidity('');
            this.duration = parseInt(durationValue, 10);
            this.calculateExpirationDate();
        }
        event.target.reportValidity();
    }

    calculateExpirationDate() {
        if (this.duration !== null && this.duration >= 0) {
            const today = new Date();
            const expirationDate = new Date(today.setMonth(today.getMonth() + this.duration));
            expirationDate.setHours(5, 30, 0, 0); // Set time to 5:30 AM
            this.newExpirationDateTime = expirationDate.toISOString();
        } else {
            this.newExpirationDateTime = null;
        }
    }

    handlePreview() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (allValid) {
            this.previewSubscriber = {
                id: this.selectedSubscriber.id,
                productName: this.selectedSubscriber.productName,
                name: this.selectedSubscriber.name,
                isTrial: this.isTrial,
                productPlanId: this.productPlanId,
                productPlanName: this.planOptions.find(plan => plan.value === this.productPlanId)?.label,
                productVersionName : this.selectedSubscriber.productVersionName,
                productVersionUrl: this.selectedSubscriber.productVersionUrl,
                orgName: this.selectedSubscriber.orgName,
                installDate: this.selectedSubscriber.installDate,
                discount: this.discount,
                duration: this.duration,
                originalExpirationDate: this.selectedSubscriber.expirationDate,
                newExpirationDateTime: this.newExpirationDateTime,
                price: this.productPlanPrice,
                discountprice : (this.productPlanPrice - (this.productPlanPrice * (this.discount / 100))).toFixed(2)
            };
            this.isEditModalOpen = false;
            this.isPreviewModalOpen = true;
        }
    }

    closePreviewModal() {
        this.isPreviewModalOpen = false;
    }

    editFromPreview() {
        this.closePreviewModal();
        this.isEditModalOpen = true;
    }

    handleConfirmSave() {

        this.isLoading = true;

        updateProductSubscriber({
            subscriberId: this.selectedSubscriber.id,
            isTrial: this.isTrial,
            productPlanId: this.productPlanId,
            discount: this.discount,
            duration: this.duration,
            expirationDateTime: this.newExpirationDateTime,
        })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Product subscriber updated successfully',
                        variant: 'success',
                    })
                );
                this.closePreviewModal();
                this.loadProductSubscribers(); // Refresh data after update
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error updating record',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
            }).finally(()=>{
                this.isLoading = false;
            });
    }
}