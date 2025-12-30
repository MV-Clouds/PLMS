import { LightningElement, api, track } from 'lwc';
import getQuoteDetails from '@salesforce/apex/AddProductsCustomLwcController.getQuoteDetails';
import getProductPlans from '@salesforce/apex/AddProductsCustomLwcController.getProductPlans';
import createQuoteLineItem from '@salesforce/apex/AddProductsCustomLwcController.createQuoteLineItem';
import createServiceQuoteLineItems from '@salesforce/apex/AddProductsCustomLwcController.createServiceQuoteLineItems';
import sendEmail from '@salesforce/apex/AddProductsCustomLwcController.sendEmail';

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
    @track showProductLayout = true; // true for product layout, false for service layout
    @track serviceRows = []; // Array of service line items

    connectedCallback() {
        this.loadQuoteData();
    }

    // Computed properties for product layout
    get formattedListPrice() {
        if (!this.listPrice) return 'Select a product plan to view price';
        return `${this.listPrice.toFixed(2)}`;
    }

    get formattedFinalPrice() {
        if (!this.calculatedPrice) return 'Select a product plan to view price';
        return `${this.calculatedPrice}`;
    }

    get calculatedPrice() {
        if (!this.listPrice) return null;
        const discountPercent = this.discount || 0;
        const discountAmount = (this.listPrice * discountPercent) / 100;
        const finalPrice = this.listPrice - discountAmount;
        return finalPrice.toFixed(2);
    }

    // Check if save button should be disabled
    get isDisabled() {
        if (this.showProductLayout) {
            return !this.selectedPlanId || this.isLoading;
        } else {
            // For service layout, check if at least one row is valid
            return this.isLoading || !this.isServiceDataValid();
        }
    }

    // Service layout computed properties
    get pageTitle() {
        return this.showProductLayout ? 'New Quote Line Item' : 'New Service Line Items';
    }

    get pageDescription() {
        return this.showProductLayout ? 'Add a new line item to your quote' : 'Add service line items to your quote';
    }

    // Check if service data is valid
    isServiceDataValid() {
        if (!this.serviceRows || this.serviceRows.length === 0) return false;
        
        return this.serviceRows.every(row => 
            row.title && row.title.trim() !== '' &&
            row.quantityHours && row.quantityHours > 0 &&
            row.pricePerHour && row.pricePerHour > 0
        );
    }

    // Initialize service rows
    initializeServiceRows() {
        this.serviceRows = [{
            id: this.generateRowId(),
            title: '',
            description: '',
            quantityHours: null,
            pricePerHour: null,
            totalPrice: 0
        }];
    }

    generateRowId() {
        return 'row_' + Date.now() + '_' + Math.floor(Math.random() * 1000);
    }

    // Check if only one service row exists (disable removal)
    get isOneRowDisabled() {
        return this.serviceRows.length === 1;
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

    async loadQuoteData() {
        this.isLoading = true;
        try {
            const quoteResult = await getQuoteDetails({ quoteId: this.recordId });
            
            this.quote = quoteResult;
            this.productName = quoteResult.ProductName;
            console.log('>> quote: ' + JSON.stringify(quoteResult));
            
            // Determine which layout to show
            // Service quotes should always show service layout
            // Product quotes show service layout only if they already have product lines
            if (quoteResult.isServiceQuote) {
                this.showProductLayout = false; // Service quotes always use service layout
            } else {
                this.showProductLayout = !quoteResult.hasProductLine; // Product quotes use service layout only if they have product lines
            }
            
            if (!this.showProductLayout) {
                // Initialize service layout
                this.initializeServiceRows();
            } else {
                // Load product plans for product layout
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
            }
        } catch (error) {
            console.error('Error loading data', error);
            await this.sendErrorEmail('loadQuoteData', error);
            this.showMessage('Failed to load quote details', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Product layout event handlers
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

    // Service layout event handlers
    handleServiceFieldChange(event) {
        const rowId = event.target.dataset.rowId;
        const fieldName = event.target.dataset.field;
        const value = event.target.value;
        console.log('event ', event);
        console.log('rowId ', event.target.dataset.rowId);
        
        const rowIndex = this.serviceRows.findIndex(row => row.id === rowId);
        console.log('rowIndex ', rowIndex);
        if (rowIndex !== -1) {
            this.serviceRows[rowIndex][fieldName] = fieldName === 'quantityHours' || fieldName === 'pricePerHour' 
                ? parseFloat(value) || 0 
                : value;
            
            // Calculate total price
            const row = this.serviceRows[rowIndex];
            row.totalPrice = (row.quantityHours || 0) * (row.pricePerHour || 0);
            
            // Update the serviceRows array to trigger reactivity
            this.serviceRows = [...this.serviceRows];
        }
    }

    handleAddRow() {
        this.serviceRows = [...this.serviceRows, {
            id: this.generateRowId(),
            title: '',
            description: '',
            quantityHours: null,
            pricePerHour: null,
            totalPrice: 0
        }];
    }

    handleRemoveRow(event) {
        const rowId = event.target.dataset.rowId;
        if (this.serviceRows.length > 1) {
            this.serviceRows = this.serviceRows.filter(row => row.id !== rowId);
        }
    }

    async handleSave() {
        if (this.showProductLayout) {
            return this.handleProductSave();
        } else {
            return this.handleServiceSave();
        }
    }

    async handleProductSave() {
        try {
            // Additional validation - ensure discount doesn't exceed 100%
            if (this.discount && this.discount > 100) {
                console.log('Invalid discount value: ' + this.discount);
                this.showMessage('Validation Error - Discount cannot exceed 100%', 'error');
                return;
            }

            this.isLoading = true;
            
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
            await this.sendErrorEmail('handleProductSave', error);
            this.showMessage('Failed to create Quote Line Item. Please try again.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleServiceSave() {
        if (!this.isServiceDataValid()) {
            this.showMessage('Please fill in all required fields for all service items', 'error');
            return;
        }

        this.isLoading = true;
        
        try {
            const serviceItems = this.serviceRows.map(row => ({
                title: row.title,
                description: row.description,
                quantityHours: row.quantityHours,
                pricePerHour: row.pricePerHour
            }));
            console.log('>> serviceItems: ' + JSON.stringify(serviceItems));

            const qliIds = await createServiceQuoteLineItems({
                quoteId: this.recordId,
                serviceItems: serviceItems
            });
            
            this.showMessage(`${qliIds.length} Service Line Items created successfully`, 'success');
            
            // Navigate back to quote
            setTimeout(() => {
                window.location.href = '/' + this.recordId;
            }, 2000);
            
        } catch (error) {
            console.error('Error creating service line items', error);
            await this.sendErrorEmail('handleServiceSave', error);
            this.showMessage('Failed to create service line items. Please try again.', 'error');
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

    // Send error email notification using Apex method
    async sendErrorEmail(methodName, error) {
        try {
            const errorMessage = error.body ? error.body.message : error.message;
            const stackTrace = error.body ? error.body.stackTrace : error.stack;
            
            const emailBody = `
                <h3>Error in AddProductsCustomLwc Component</h3>
                <br/>
                <strong>Component:</strong> addProductsCustomLwc<br/>
                <strong>Method:</strong> ${methodName}<br/>
                <strong>Quote ID:</strong> ${this.recordId}<br/>
                <strong>Error Message:</strong> ${errorMessage}<br/>
                <strong>Stack Trace:</strong> ${stackTrace || 'Not available'}<br/>
                <strong>User Context:</strong> Current user encountered this error<br/>
                <strong>Timestamp:</strong> ${new Date().toISOString()}<br/>
                <br/>
                <strong>Component State:</strong><br/>
                - Product Layout: ${this.showProductLayout}<br/>
                - Selected Plan ID: ${this.selectedPlanId}<br/>
                - Service Rows Count: ${this.serviceRows ? this.serviceRows.length : 0}<br/>
                <br/>
                Regards,<br/>
                PLMS Team
            `;
            
            await sendEmail({ body: emailBody });
            
        } catch (emailError) {
            console.error('Failed to send error notification email:', emailError);
            // Don't show this error to user as it's a secondary failure
        }
    }
}