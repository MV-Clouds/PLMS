// newQuoteLineItem.js
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getQuoteDetails from '@salesforce/apex/AddProductsCustomLwcController.getQuoteDetails';
import getProductPlans from '@salesforce/apex/AddProductsCustomLwcController.getProductPlans';
import createQuoteLineItem from '@salesforce/apex/AddProductsCustomLwcController.createQuoteLineItem';

export default class AddProductsCustomLwc extends NavigationMixin(LightningElement) {
    @api recordId;
    @track quote;
    @track productName;
    @track productPlans = [];
    @track productPlanOptions = [];
    @track selectedPlanId;
    @track listPrice = 0;
    @track discount = 0;
    @track description = '';
    @track isLoading = false;

    connectedCallback() {
        this.loadQuoteData();
    }

    async loadQuoteData() {
        this.isLoading = true;
        try {
            console.log('Record Id: ' + this.recordId);
            
            const quoteResult = await getQuoteDetails({ quoteId: this.recordId });
            console.log('Quote:', quoteResult);
            
            this.quote = quoteResult;
            this.productName = quoteResult.ProductName;
            
            console.log('Product Name: ' + quoteResult.ProductName);
            
            const productId = quoteResult.MV_Product_Id;
            console.log('Product Id: ' + productId);
            
            if (productId) {
                const planResult = await getProductPlans({ productId });
                this.productPlans = planResult;
                this.productPlanOptions = planResult.map(p => ({ 
                    label: p.label, 
                    value: p.value 
                }));
                console.log('Product Plans:', JSON.stringify(this.productPlans));
            }
        } catch (error) {
            console.error('Error loading data', error);
            this.showToast('Error', 'Failed to load quote details', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handlePlanChange(event) {
        this.selectedPlanId = event.target.value;
        const selected = this.productPlans.find(p => p.value === this.selectedPlanId);
        this.listPrice = selected ? parseFloat(selected.price) : 0;
        
        // Reset discount when plan changes
        this.discount = 0;
        
        // Clear discount field
        const discountField = this.template.querySelector('lightning-input[data-field="discount"]');
        if (discountField) {
            discountField.value = '';
        }
    }

    handleDiscountChange(event) {
        const discountValue = event.target.value;
        this.discount = discountValue ? parseFloat(discountValue) : 0;
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }

    // Computed property for calculated price
    get calculatedPrice() {
        if (!this.listPrice) return null;
        const finalPrice = this.listPrice - (this.discount || 0);
        return finalPrice.toFixed(2);
    }

    // Check if save button should be disabled
    get isDisabled() {
        return !this.selectedPlanId || this.isLoading;
    }

    async handleSave() {
        // Validate required fields
        if (!this.selectedPlanId) {
            this.showToast('Validation Error', 'Please select a Product Plan', 'error');
            return;
        }

        // Additional validation - ensure discount doesn't exceed list price
        if (this.discount && this.discount > this.listPrice) {
            this.showToast('Validation Error', 'Discount cannot exceed the list price', 'error');
            return;
        }

        this.isLoading = true;
        
        try {
            const qliId = await createQuoteLineItem({
                quoteId: this.recordId,
                productPlanId: this.selectedPlanId,
                discountValue: this.discount,
                description: this.description
            });
            
            this.showToast('Success', 'Quote Line Item created successfully', 'success');
            
            // Navigate to the created record
            window.location.href = '/' + qliId;
            
        } catch (error) {
            console.error('Error creating QLI', error);
            this.showToast('Error', 'Failed to create Quote Line Item. Please try again.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        // Navigate back to the quote record
        window.location.href = '/' + this.recordId;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant,
            mode: variant === 'error' ? 'sticky' : 'dismissible'
        });
        this.dispatchEvent(event);
    }
}