import { LightningElement, api, track } from 'lwc';
import getQuoteDetails from '@salesforce/apex/AddProductsCustomLwcController.getQuoteDetails';
import getProductPlans from '@salesforce/apex/AddProductsCustomLwcController.getProductPlans';
import createQuoteLineItem from '@salesforce/apex/AddProductsCustomLwcController.createQuoteLineItem';

export default class AddProductsCustomLwc extends LightningElement {
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
    @track message;
    @track messageType;

    // Computed property for formatted list price
    get formattedListPrice() {
        if (!this.listPrice) return 'Select a product plan to view price';
        return `${this.listPrice.toFixed(2)}`;
    }

    // Computed property for formatted final price
    get formattedFinalPrice() {
        if (!this.calculatedPrice) return 'Select a product plan to view price';
        return `${this.calculatedPrice}`;
    }

    // Computed property for calculated price
    get calculatedPrice() {
        if (!this.listPrice) return null;
        const discountPercent = this.discount || 0;
        const discountAmount = (this.listPrice * discountPercent) / 100;
        const finalPrice = this.listPrice - discountAmount;
        return finalPrice.toFixed(2);
    }

    // Check if save button should be disabled
    get isDisabled() {
        return !this.selectedPlanId || this.isLoading;
    }

    // Get CSS classes for message styling
    get messageClasses() {
        if (!this.messageType) return '';
        const baseClasses = 'slds-scoped-notification slds-media slds-media_center';
        switch(this.messageType) {
            case 'success':
                return `${baseClasses} slds-scoped-notification_light slds-theme_success`;
            case 'error':
                return `${baseClasses} slds-scoped-notification_light slds-theme_error`;
            case 'warning':
                return `${baseClasses} slds-scoped-notification_light slds-theme_warning`;
            default:
                return baseClasses;
        }
    }

    // Get icon name based on message type
    get messageIcon() {
        switch(this.messageType) {
            case 'success':
                return 'utility:success';
            case 'error':
                return 'utility:error';
            case 'warning':
                return 'utility:warning';
            default:
                return 'utility:info';
        }
    }

    connectedCallback() {
        this.loadQuoteData();
    }

    async loadQuoteData() {
        this.isLoading = true;
        try {
            const quoteResult = await getQuoteDetails({ quoteId: this.recordId });
            
            this.quote = quoteResult;
            this.productName = quoteResult.ProductName;
            console.log('>> quote: ' + JSON.stringify(quoteResult));
            
            
            const productId = quoteResult.MV_Product_Id;
            
            if (productId) {
                const planResult = await getProductPlans({ productId });
                console.log('>> planResult: ' + JSON.stringify(planResult));
                this.productPlans = planResult;
                this.productPlanOptions = planResult.map(p => ({ 
                    label: p.label, 
                    value: p.value 
                }));
            }
        } catch (error) {
            console.error('Error loading data', error);
            this.showMessage('Failed to load quote details', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handlePlanChange(event) {
        this.selectedPlanId = event.target.value;
        console.log('>> selectedPlanId: ' + this.selectedPlanId);
        
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
        this.clearMessage();
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }

    async handleSave() {
        // Additional validation - ensure discount doesn't exceed 100%
        if (this.discount && this.discount > 100) {
            console.log('Invalid discount value: ' + this.discount);
            
            this.showMessage('Validation Error - Discount cannot exceed 100%', 'error');
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
            
            this.showMessage('Quote Line Item created successfully', 'success');
            
            // Navigate to the created record
            window.location.href = '/' + qliId;
            
        } catch (error) {
            console.error('Error creating QLI', error);
            this.showMessage('Failed to create Quote Line Item. Please try again.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        // Navigate back to the quote record
        window.location.href = '/' + this.recordId;
    }

    showMessage(message, type) {
        if (!message || !type) return;
        console.log('>> message: ' + message + ', type: ' + type);
        
        this.message = message;
        this.messageType = type;
    }

    clearMessage() {
        this.message = '';
        this.messageType = '';
    }
}