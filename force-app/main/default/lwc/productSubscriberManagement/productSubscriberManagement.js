import { LightningElement, track } from 'lwc';
import getProducts from '@salesforce/apex/ProductSubscriberManagementController.getProducts';
import getProductSubscribers from '@salesforce/apex/ProductSubscriberManagementController.getProductSubscribers';
import updateProductSubscriber from '@salesforce/apex/ProductSubscriberManagementController.updateProductSubscriber';
import getProductPlans from '@salesforce/apex/ProductSubscriberManagementController.getProductPlans';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const columns = [
    { 
        label: 'Name', 
        fieldName: 'subNameUrl', 
        typeAttributes: {
            label: { fieldName: 'Name' }, 
            target: '_blank'
        }, 
        type: 'url', 
        sortable: true 
    },
    { 
        label: 'Org Name' , 
        fieldName: 'Org_Name__c', 
        type: 'text', 
        sortable: true 
    },
    { 
        label: 'Org Type' , 
        fieldName: 'Org_Type__c', 
        type: 'text', 
        sortable: true 
    },
    { 
        label: 'Org Id' , 
        fieldName: 'Org_Id__c', 
        type: 'text', 
        sortable: true 
    },
    { 
        label: 'Install Date' , 
        fieldName: 'Install_Date__c', 
        type: 'date',
        sortable: true 
    },
    // { 
    //     label: 'Product Plan', 
    //     fieldName: 'productPlanUrl', 
    //     typeAttributes: {
    //         label: { fieldName: 'productPlanName' }, 
    //         target: '_blank'
    //     }, 
    //     type: 'url', 
    //     sortable: true 
    // },
    { 
        label: 'Expiration DateTime', 
        fieldName: 'Expiration_DateTime__c', 
        type: 'date', sortable: true, 
        typeAttributes: {
            day: 'numeric',
            month: 'numeric',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            hour12: true
        }
    },
    { 
        label: 'Is Trial', 
        fieldName: 'Is_Trial__c', 
        type: 'boolean', 
        sortable: true 
    },
    {
        type: 'action',
        typeAttributes: { 
            rowActions: 
            [
                { 
                    label: 'Edit', 
                    name: 'edit' 
                }
            ] 
        },
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
    pageSize = 20;
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

    connectedCallback() {
        this.loadProducts();
        this.loadProductPlans();
    }

    loadProducts() {
        try {
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
        } catch (error) {
            console.error('Error in loadProducts :: ', error);
            
        }
    }

    loadProductSubscribers() {
        try {
            getProductSubscribers({ productId: this.productId })
                .then(data => {
                    this.allSubscribers = data;
                    this.processRecords();
                })
                .catch(error => {
                    console.error('Error loading product subscribers', error);
                });
        } catch (error) {
            console.error('Error in loadProductSubscribers :: ',error);
        }
    }

    loadProductPlans() {
        try {
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
        } catch (error) {
            this.isLoading = false;
            console.error('Error in loadProductPlans :: ', error);
        }
    }

    processRecords() {
        try {
            this.isLoading = true;
            let records = [...this.allSubscribers];
            records = records.map(record => ({
                ...record,
                subNameUrl: `/lightning/r/${record.Id}/view`,
                productPlanName: record.Product_Plan__r ? record.Product_Plan__r.Name : '',
                // productPlanUrl: record.Product_Plan__c ? `/lightning/r/${record.Product_Plan__c}/view` : '',
            }));
            if (this.searchKey) {
                const searchLower = this.searchKey.toLowerCase();
                records = records.filter(record => {
                    const nameMatch = record.Name && record.Name.toLowerCase().includes(searchLower);
                    const orgNameMatch = record.Org_Name__c && record.Org_Name__c.toLowerCase().includes(searchLower);
                    const exdateMatch = record.Expiration_DateTime__c && record.Expiration_DateTime__c.toLowerCase().includes(searchLower);
                    const indateMatch = record.Install_Date__c && record.Install_Date__c.toLowerCase().includes(searchLower);
                    const orgTypeMatch = record.Org_Type__c && record.Org_Type__c.toLowerCase().includes(searchLower);
                    const orgIdMatch = record.Org_Id__c && record.Org_Id__c.toLowerCase().includes(searchLower);
                    return nameMatch || exdateMatch || orgNameMatch || orgIdMatch || orgTypeMatch || indateMatch;
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
        try {
            this.searchKey = event.target.value;
            this.pageNumber = 1;
            clearTimeout(this.searchTimeout);
            this.searchTimeout = setTimeout(() => {
                console.log('search called' + this.searchKey);
                this.processRecords();
            }, 300);
        } catch (error) {
            console.error('error in handleSearchChange :: ', error);
            
        }
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
                // productVersionName: row.Product_Version__r && row.Product_Version__r.Name ? row.Product_Version__r.Name : '',
                // productVersionUrl: row.Product_Version__c ? `${orgDomain}/lightning/r/${row.Product_Version__c}/view` : '',
                // isproductVersionUrl : row.Product_Version__c ? true : false,
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

    handleConfirmSave() {
        try {
            const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
                .reduce((validSoFar, inputCmp) => {
                    inputCmp.reportValidity();
                    return validSoFar && inputCmp.checkValidity();
                }, true);
        
            this.isLoading = true;
            
            if (allValid) {
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
                        this.loadProductSubscribers(); // Refresh data after update
                    })
                    .catch(error => {
                        console.error('Error updating record ::',JSON.stringify(error));
                        
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Error updating record',
                                message: error,
                                variant: 'error',
                            })
                        );
                    }).finally(()=>{
                        this.isLoading = false;
                        this.isEditModalOpen = false;
                    });
            } else {
                this.isLoading = false;
            }
        } catch (error) {
            console.error('Error in handleConfirmSave ::', error);
        }
    }
}