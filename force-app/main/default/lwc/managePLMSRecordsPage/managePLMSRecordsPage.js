import { LightningElement, track } from 'lwc';
import searchAccounts from '@salesforce/apex/ManagePLMSRecordsPageController.searchAccounts';
import getOrganizationsByAccount from '@salesforce/apex/ManagePLMSRecordsPageController.getOrganizationsByAccount';
import getOrganizationById from '@salesforce/apex/ManagePLMSRecordsPageController.getOrganizationById';
import getProductSubscribersByOrganization from '@salesforce/apex/ManagePLMSRecordsPageController.getProductSubscribersByOrganization';
import getInvoicesByOrganization from '@salesforce/apex/ManagePLMSRecordsPageController.getInvoicesByOrganization';
import getProductVersionsBySubscriber from '@salesforce/apex/ManagePLMSRecordsPageController.getProductVersionsBySubscriber';
import getProductSubscriberById from '@salesforce/apex/ManagePLMSRecordsPageController.getProductSubscriberById';
import updateProductSubscriberExpiry from '@salesforce/apex/ManagePLMSRecordsPageController.updateProductSubscriberExpiry';
import updateProductSubscriberPlan from '@salesforce/apex/ManagePLMSRecordsPageController.updateProductSubscriberPlan';

const DEBOUNCE_MS = 300;
const PAGE_STEPS = { 
    SELECT: 'select', 
    ACTIONS: 'actions', 
    ORGANIZATIONS: 'organizations',
    ENVIRONMENT: 'environment'
};

const TABS = {
    PRODUCT_SUBSCRIBERS: 'product-subscribers',
    INVOICES: 'invoices'
};

export default class ManagePLMSRecordsPage extends LightningElement {
	@track query = '';
	@track accounts = [];
	@track organizations = [];
	@track productSubscribers = [];
	@track invoices = [];
	@track productVersions = [];
	@track loading = false;
	@track organizationLoading = false;
	@track sectionLoading = false;
	@track detailLoading = false;
	@track selected;
	@track selectedOrganization;
	@track selectedRecord;
	@track step = PAGE_STEPS.SELECT;
	@track listKey = 0;
	@track animFlip = false;
	@track navigationStack = [];
	@track breadcrumbStack = [];
	// Section Properties
	@track showOrganizationDetails = false;
	@track showRecordDetails = false;
	@track activeTab = TABS.PRODUCT_SUBSCRIBERS;
	
	// Update Properties
	@track showUpdateExpiryModal = false;
	@track showUpdateProductPlanModal = false;
	@track durationMonths = '';
	@track currentExpiryDate = '';
	@track newExpiryPreview = '';
	@track selectedProductPlanId = '';
	@track productPlanOptions = [
					{ label: 'Basic Plan', value: 'basic-plan-id' },
					{ label: 'Premium Plan', value: 'premium-plan-id' , isSelected: true },
					{ label: 'Enterprise Plan', value: 'enterprise-plan-id' },
					{ label: 'Trial Plan', value: 'trial-plan-id' }
				];;
	@track currentProductPlan = '';
	@track productPlanLoading = false;
	
	debounceId;

	connectedCallback() {
		// default: show placeholder; don't fetch until user searches
		this.accounts = [];
		this.hasSearched = false;
		this.navigationStack = [];
		this.breadcrumbStack = [];
		this.showOrganizationDetails = false;
		this.showRecordDetails = false;
		this.activeTab = TABS.PRODUCT_SUBSCRIBERS;
	}

	// UI state
	get isSelectStep() { return this.step === PAGE_STEPS.SELECT; }
	get isActionsStep() { return this.step === PAGE_STEPS.ACTIONS; }
	get isOrganizationsStep() { return this.step === PAGE_STEPS.ORGANIZATIONS; }
	get isEnvironmentStep() { return this.step === PAGE_STEPS.ENVIRONMENT; }
    
	// Show a global action bar (Back + Breadcrumbs) on all steps except the initial search
	get showGlobalActionBar() {
		return !this.isSelectStep || this.showOrganizationDetails || this.showRecordDetails;
	}
	
	get resultLabel() {
		const c = this.accounts?.length || 0;
		return c === 1 ? '1 account found' : `${c} accounts found`;
	}
	
	get organizationLabel() {
		const c = this.organizations?.length || 0;
		return c === 1 ? '1 organization found' : `${c} organizations found`;
	}
	
	get listClass() {
		return `account-list ${this.animFlip ? 'fade' : 'fade2'}`;
	}
	
	get hasAccounts() {
		return Array.isArray(this.accounts) && this.accounts.length > 0;
	}
	
	get hasOrganizations() {
		return Array.isArray(this.organizations) && this.organizations.length > 0;
	}
	
	get hasProductSubscribers() {
		return Array.isArray(this.productSubscribers) && this.productSubscribers.length > 0;
	}
	
	get hasInvoices() {
		return Array.isArray(this.invoices) && this.invoices.length > 0;
	}
	
	get hasProductVersions() {
		return Array.isArray(this.productVersions) && this.productVersions.length > 0;
	}
	
    get dynamicBreadcrumb() {
		const crumbs = [];
		if (this.selected?.Name) {
			const clickable = this.step !== PAGE_STEPS.ACTIONS || this.showOrganizationDetails || this.showRecordDetails;
			crumbs.push({ key: 'account', label: this.selected.Name, isClickable: clickable });
		}
		if (this.selectedOrganization?.Name) {
			const orgClickable = !!this.showRecordDetails; // allow jump back from details
			crumbs.push({ key: 'organization', label: this.selectedOrganization.Name, isClickable: orgClickable });
		}
		if (this.showRecordDetails && this.selectedRecord?.Name) {
			crumbs.push({ key: 'record', label: this.selectedRecord.Name, isClickable: false });
		}
		return crumbs.map((c, i) => ({ ...c, last: i === crumbs.length - 1 }));
	}

    handleBreadcrumbClick(event) {
		const key = event.currentTarget.dataset.step;
		if (key === 'account') {
			// Jump back to account actions
			this.showRecordDetails = false;
			this.showOrganizationDetails = false;
			this.selectedOrganization = null;
			this.productSubscribers = [];
			this.invoices = [];
			this.productVersions = [];
			this.step = PAGE_STEPS.ACTIONS;
		} else if (key === 'organization' && this.selectedOrganization) {
			// From record details back to organization details
			this.showRecordDetails = false;
			this.showOrganizationDetails = true;
			this.detailLoading = false;
		}
		this.scrollToTop();
	}

    async handleViewDetails(event) {
        console.log(this.productSubscribers);
        console.log('View Details clicked', event.currentTarget.dataset.id);
        console.log('View Details clicked', event.currentTarget.dataset.type);

        const recordId = event.currentTarget.dataset.id;
        const recordType = event.currentTarget.dataset.type;
        
        if (recordType === 'subscriber') {
            this.detailLoading = true;
            // Close organization details when opening record details
            this.showOrganizationDetails = false;
            this.showRecordDetails = true;
            
            try {
                // Get Product Subscriber details
                this.selectedRecord = await getProductSubscriberById({ productSubscriberId: recordId });
                console.log('Selected Record:', this.selectedRecord);
                
				// Get Product Versions for this subscriber
				this.productVersions = await getProductVersionsBySubscriber({ productSubscriberId: recordId });
				console.log('Product Versions:', this.productVersions);	
				this.productVersions = this.productVersions.map(opt => ({
					...opt,
					Installed_Date__c : opt?.Installed_Date__c?.split('T')[0] || null,
				}));
				console.log('Product Versions:', this.productVersions);	

                
            } catch (error) {
                console.error('Error fetching record details:', error);
                this.showToast('Error', 'Error fetching record details', 'error');
            } finally {
                this.detailLoading = false;
            }
        }
    }

    closeRecordDetails() {
		this.showRecordDetails = false;
		this.selectedRecord = null;
		this.productVersions = [];
		this.detailLoading = false;
		// Return to organization details view if we had one
		if (this.selectedOrganization) {
			this.showOrganizationDetails = true;
		}
    }

    handleCloseOrganizationDetails() {
        this.showOrganizationDetails = false;
        this.showRecordDetails = false;
        this.selectedOrganization = null;
        this.selectedRecord = null;
        this.productSubscribers = [];
        this.invoices = [];
        this.productVersions = [];
        this.activeTab = TABS.PRODUCT_SUBSCRIBERS;
    }	get backButtonText() {
        if (this.showRecordDetails) return 'Back to Organization';
        if (this.showOrganizationDetails) return 'Back to Actions';
		if (this.step === PAGE_STEPS.ACTIONS) return 'Back to Search';
		if (this.step === PAGE_STEPS.ORGANIZATIONS) return 'Back to Actions';
		if (this.step === PAGE_STEPS.ENVIRONMENT) return 'Back to Actions';
		return 'Back';
	}
	
	get sectionTitle() {
		if (this.step === PAGE_STEPS.ACTIONS) return 'Account Actions';
		if (this.step === PAGE_STEPS.ORGANIZATIONS) return 'Organizations';
		if (this.step === PAGE_STEPS.ENVIRONMENT) return 'Environment Details';
		return 'Search Accounts';
	}
	
	get isProductSubscribersTab() {
		return this.activeTab === TABS.PRODUCT_SUBSCRIBERS;
	}
	
	get isInvoicesTab() {
		return this.activeTab === TABS.INVOICES;
	}
	
	get productSubscribersTabClass() {
		return this.isProductSubscribersTab ? 'tab-button active' : 'tab-button';
	}
	
    get invoicesTabClass() {
        return this.activeTab === 'invoices' ? 'tab-button active' : 'tab-button';
    }

    get isProductSubscribersTab() {
        return this.activeTab === 'product-subscribers';
    }

    get isInvoicesTab() {
        return this.activeTab === 'invoices';
    }    

    // Search input with auto-search and debounce
    handleSearchInput(e) {
        const val = e.target.value || '';
        this.query = val;
        window.clearTimeout(this.debounceId);
        this.debounceId = window.setTimeout(() => {
            this.hasSearched = true;
            this.fetchAccounts(this.query);
        }, DEBOUNCE_MS);
    }	async fetchAccounts(term) {
		this.loading = true;
		try {
			const data = await searchAccounts({ searchTerm: term, maxSize: 50 });
			// add index for display
			this.accounts = (data || []).map((a, i) => ({
				...a,
				idx: i + 1,
				
			}));
			// animate list refresh by toggling key on container
			this.listKey = Math.random();
			this.animFlip = !this.animFlip;
		} catch (e) {
			// eslint-disable-next-line no-console
			console.error('Account search failed', e);
			this.accounts = [];
		} finally {
			this.loading = false;
		}
	}

	handleSelectAccount(e) {
		const id = e.currentTarget?.dataset?.id;
		const found = this.accounts.find(a => a.Id === id);
		if (found) {
			this.selected = found;
			this.navigationStack.push({step: PAGE_STEPS.SELECT, data: null});
			// slide out first section, slide in second
			this.step = PAGE_STEPS.ACTIONS;
			this.scrollToTop();
		}
	}

	handleItemKeydown(e) {
		if (e.key === 'Enter' || e.key === ' ') {
			e.preventDefault();
			this.handleSelectAccount(e);
		}
	}

	handleOrganizationItemKeydown(e) {
		if (e.key === 'Enter' || e.key === ' ') {
			e.preventDefault();
			this.handleSelectOrganization(e);
		}
	}

	handleBack() {
		// If in a detail subview, close it first
		if (this.showRecordDetails) {
			this.closeRecordDetails();
			this.scrollToTop();
			return;
		}
		if (this.showOrganizationDetails) {
			this.handleCloseOrganizationDetails();
			this.step = PAGE_STEPS.ORGANIZATIONS;
			this.scrollToTop();
			return;
		}

		if (this.navigationStack.length > 0) {
			const previousState = this.navigationStack.pop();
			this.step = previousState.step;
			if (previousState.step === PAGE_STEPS.SELECT) {
				this.selected = null;
				this.selectedOrganization = null;
				this.organizations = [];
			} else if (previousState.step === PAGE_STEPS.ACTIONS) {
				this.selectedOrganization = null;
			}
		} else {
			this.step = PAGE_STEPS.SELECT;
			this.selected = null;
			this.selectedOrganization = null;
			this.organizations = [];
		}
		this.scrollToTop();
	}
	
	scrollToTop() {
		requestAnimationFrame(() => {
			try { 
				this.template.host.scrollIntoView({ behavior: 'smooth', block: 'start' }); 
			} catch (e) {}
			window.scrollTo({ top: 0, behavior: 'smooth' });
		});
	}

	get showPlaceholder() {
		return !this.loading && !this.hasSearched && this.step === PAGE_STEPS.SELECT;
	}

    async handleOpenOrganization() {
        if (!this.selected?.Id) return;
        
        this.organizationLoading = true;
        this.navigationStack.push({step: this.step, data: this.selected});
        
        // Close all sections when navigating to organizations
        this.showOrganizationDetails = false;
        this.showRecordDetails = false;
        this.selectedOrganization = null;
        this.selectedRecord = null;
        this.productSubscribers = [];
        this.invoices = [];
        this.productVersions = [];
        this.activeTab = TABS.PRODUCT_SUBSCRIBERS;
        
        try {
            const data = await getOrganizationsByAccount({ accountId: this.selected.Id });
            this.organizations = (data || []).map((org, i) => ({
                ...org,
                idx: i + 1
            }));
            this.step = PAGE_STEPS.ORGANIZATIONS;
            this.scrollToTop();
        } catch (e) {
            console.error('Failed to fetch organizations', e);
            this.organizations = [];
            // Don't change step if there's an error
            this.navigationStack.pop(); // Remove the pushed state
        } finally {
            this.organizationLoading = false;
        }
    }

	handleSelectOrganization(e) {
		const id = e.currentTarget?.dataset?.id;
		const found = this.organizations.find(org => org.Id === id);
		if (found) {
			this.selectedOrganization = found;
			// Close any other open sections
			this.showRecordDetails = false;
			this.showOrganizationDetails = true;
			this.activeTab = TABS.PRODUCT_SUBSCRIBERS;
			this.loadSectionData();
		}
	}
	
	async loadSectionData() {
		if (!this.selectedOrganization?.Id) return;
		
		this.sectionLoading = true;
		try {
			// Load both tabs data in parallel
			const [productSubscribers, invoices] = await Promise.all([
				getProductSubscribersByOrganization({ organizationId: this.selectedOrganization.Id }),
				getInvoicesByOrganization({ organizationId: this.selectedOrganization.Id })
			]);
			
			// Process Product Subscribers with serial numbers
			this.productSubscribers = (productSubscribers || []).map((ps, index) => ({
				...ps,
				serialNumber: index + 1,
				productName: ps.Product__r?.Name || 'N/A',
				installDateFormatted: ps.Install_Date__c ? this.formatDate(ps.Install_Date__c) : 'N/A',
				expirationDateFormatted: ps.Expiration_DateTime__c ? this.formatDate(ps.Expiration_DateTime__c) : 'N/A',
				isTrialText: ps.Is_Trial__c ? 'Yes' : 'No',
				statusClass: ps.Active__c ? 'status-active' : 'status-inactive'
			}));
			
			// Process Invoices with serial numbers
			this.invoices = (invoices || []).map((inv, index) => ({
				...inv,
				serialNumber: index + 1,
				invoiceNumber: inv.Name || 'N/A',
				dateFormatted: inv.Start_Date__c ? this.formatDate(inv.Start_Date__c) : 'N/A',
				amount: inv.Price__c ? `$${inv.Price__c.toFixed(2)}` : '$0.00',
				status: inv.Status__c || 'Unknown'
			}));
			
		} catch (e) {
			console.error('Failed to load section data', e);
			this.productSubscribers = [];
			this.invoices = [];
		} finally {
			this.sectionLoading = false;
		}
	}
	
	formatDate(dateString) {
		if (!dateString) return 'N/A';
		try {
			const date = new Date(dateString);
			return date.toLocaleDateString('en-US', {
				year: 'numeric',
				month: '2-digit',
				day: '2-digit'
			});
		} catch (e) {
			return 'Invalid Date';
		}
	}

	// --- JSON-driven detail fields for templates ---
	get recordInfoFields() {
		if (!this.selectedRecord) return [];
		return [
			{ key: 'name', label: 'Product Subscriber Name', value: this.selectedRecord.Name || '-' },
			{ key: 'installDate', label: 'Install Date', value: this.selectedRecord.Install_Date__c ? this.formatDate(this.selectedRecord.Install_Date__c) : '-' },
			{ key: 'lastUpgrade', label: 'Last Upgrade Date', value: this.selectedRecord.Last_Upgrade_Date__c ? this.formatDate(this.selectedRecord.Last_Upgrade_Date__c) : '-' },
			{ key: 'uninstallDate', label: 'Uninstall Date', value: this.selectedRecord.Uninstall_Date__c ? this.formatDate(this.selectedRecord.Uninstall_Date__c) : '-' },
			{ key: 'isTrial', label: 'Is Trial', value: this.selectedRecord.Is_Trial__c ? 'Yes' : 'No' },
			{ key: 'active', label: 'Active', value: this.selectedRecord.Active__c ? 'Yes' : 'No' },
			{ key: 'product', label: 'Product', value: this.selectedRecord?.Product__r?.Name || '-' },
			{ key: 'version', label: 'Version Number', value: this.selectedRecord.Version_Number__c || '-' },
			{ key: 'expiration', label: 'Expiration DateTime', value: this.selectedRecord.Expiration_DateTime__c ? this.formatDate(this.selectedRecord.Expiration_DateTime__c) : '-' },
			{ key: 'productPlan', label: 'Product Plan', value: this.selectedRecord?.Product_Plan__r?.Name || '-' }
		];
	}

	// split fields into two columns for layout
	get recordInfoLeft() {
		const f = this.recordInfoFields;
		return f.slice(0, Math.ceil(f.length / 2));
	}

	get recordInfoRight() {
		const f = this.recordInfoFields;
		return f.slice(Math.ceil(f.length / 2));
	}

	get orgInfoFields() {
		if (!this.selectedRecord) return [];
		return [
			{ key: 'orgId', label: 'Organization Id', value: this.selectedRecord.Org_Id__c || '-' },
			{ key: 'orgType', label: 'Organization Type', value: this.selectedRecord.Org_Type__c || '-' },
			{ key: 'orgName', label: 'Organization Name', value: this.selectedRecord.Org_Name__c || '-' }
		];
	}

	get orgInfoLeft() {
		const f = this.orgInfoFields;
		return f.slice(0, Math.ceil(f.length / 2));
	}

	get orgInfoRight() {
		const f = this.orgInfoFields;
		return f.slice(Math.ceil(f.length / 2));
	}

	get installedUserFields() {
		if (!this.selectedRecord) return [];
		return [
			{ key: 'userId', label: 'User Id', value: this.selectedRecord.User_Id__c || '-' },
			{ key: 'firstName', label: 'First Name', value: this.selectedRecord.First_Name__c || '-' },
			{ key: 'email', label: 'Email', value: this.selectedRecord.Email__c || '-' },
			{ key: 'username', label: 'Username', value: this.selectedRecord.Username__c || '-' },
			{ key: 'lastName', label: 'Last Name', value: this.selectedRecord.Last_Name__c || '-' },
			{ key: 'phone', label: 'Phone', value: this.selectedRecord.Mobile_Phone__c || '-' }
		];
	}

	get installedUserLeft() {
		const f = this.installedUserFields;
		return f.slice(0, Math.ceil(f.length / 2));
	}

	get installedUserRight() {
		const f = this.installedUserFields;
		return f.slice(Math.ceil(f.length / 2));
	}

	// Columns config for invoices table
	get invoiceColumns() {
		return [
			{ key: 'serialNumber', label: 'Serial Number' },
			{ key: 'invoiceNumber', label: 'Invoice Number' },
			{ key: 'dateFormatted', label: 'Date' },
			{ key: 'amount', label: 'Amount' },
			{ key: 'status', label: 'Status' }
		];
	}
	
	handleTabClick(e) {
		const tab = e.currentTarget?.dataset?.tab;
		if (tab && tab !== this.activeTab) {
			this.activeTab = tab;
		}
	}

	handleOpenQuotes() {
		// Placeholder: wire navigation/event hook here
		// eslint-disable-next-line no-console
		console.log('Open Quotes for', this.selected?.Id);
	}
	
	get resultsVisible() {
		return !this.loading && this.hasSearched && this.step === PAGE_STEPS.SELECT;
	}
	
	get organizationsVisible() {
		return !this.organizationLoading && this.step === PAGE_STEPS.ORGANIZATIONS;
	}

	// Update Expiry Date Methods
	handleUpdateExpiry() {
		if (this.selectedRecord && this.selectedRecord.Expiration_DateTime__c) {
			this.currentExpiryDate = this.selectedRecord.Expiration_DateTime__c;
			this.durationMonths = '';
			this.newExpiryPreview = '';
			this.showUpdateExpiryModal = true;
		}
	}

	closeUpdateExpiryModal() {
		this.showUpdateExpiryModal = false;
		this.durationMonths = '';
		this.newExpiryPreview = '';
	}

	handleDurationChange(event) {
		this.durationMonths = event.currentTarget.value;
		this.calculateNewExpiryDate();
	}

	calculateNewExpiryDate() {
		if (this.currentExpiryDate && this.durationMonths) {
			try {
				const currentDate = new Date(this.currentExpiryDate);
				const newDate = new Date(currentDate);
				newDate.setMonth(newDate.getMonth() + parseInt(this.durationMonths));
				
				// Format the new date
				this.newExpiryPreview = newDate.toLocaleString('en-US', {
					year: 'numeric',
					month: '2-digit',
					day: '2-digit',
					hour: '2-digit',
					minute: '2-digit',
					hour12: true
				});
			} catch (error) {
				console.error('Error calculating new expiry date:', error);
				this.newExpiryPreview = '';
			}
		} else {
			this.newExpiryPreview = '';
		}
	}

	get saveExpiryDisabled() {
		return !this.currentExpiryDate;
	}

	async saveExpiryUpdate() {
		if (this.saveExpiryDisabled) return;

		if (!this.selectedRecord || !this.selectedRecord.Id) {
			this.showToast('Error', 'No selected record to update', 'error');
			return;
		}

		this.sectionLoading = true;
		try {
			// send date string (YYYY-MM-DD) to Apex
			const result = await updateProductSubscriberExpiry({ productSubscriberId: this.selectedRecord.Id, newExpirationDate: this.currentExpiryDate });
			if (result) {
				this.showToast('Success', 'Expiry date updated successfully', 'success');
				// Refresh selectedRecord from server
				this.selectedRecord = await getProductSubscriberById({ productSubscriberId: this.selectedRecord.Id });
				// Also refresh the parent lists so UI shows updated expiration in the table
				if (this.selectedOrganization && this.showOrganizationDetails) {
					await this.loadSectionData();
				}
			} else {
				this.showToast('Error', 'Failed to update expiry date', 'error');
			}
		} catch (err) {
			console.error('saveExpiryUpdate error', err);
			this.showToast('Error', 'Error updating expiry date', 'error');
		} finally {
			this.sectionLoading = false;
			this.closeUpdateExpiryModal();
		}
	}

	// Update Product Plan Methods
	async handleUpdateProductPlan() {
		if (this.selectedRecord) {
			this.currentProductPlan = this.selectedRecord.Product_Plan__r?.Name || 'No plan selected';
			this.selectedProductPlanId = this.selectedRecord.Product_Plan__c || '';
			this.productPlanLoading = true;
			this.showUpdateProductPlanModal = true;

			try {
				// TODO: Implement Apex method to fetch product plans
				// For now, using mock data
				this.productPlanOptions = [
					{ label: 'Basic Plan', value: 'basic-plan-id' },
					{ label: 'Premium Plan', value: 'premium-plan-id' },
					{ label: 'Enterprise Plan', value: 'enterprise-plan-id' },
					{ label: 'Trial Plan', value: 'trial-plan-id' }
				];
			} catch (error) {
				console.error('Error fetching product plans:', error);
				this.showToast('Error', 'Error loading product plans', 'error');
			} finally {
				this.productPlanLoading = false;
			}
		}
	}

	closeUpdateProductPlanModal() {
		this.showUpdateProductPlanModal = false;
		this.selectedProductPlanId = '';
		// this.productPlanOptions = [];
		this.productPlanLoading = false;
	}

	handleProductPlanChange(event) {
		this.selectedProductPlanId = event.currentTarget.value;
	}

	get saveProductPlanDisabled() {
		return !this.selectedProductPlanId || this.productPlanLoading;
	}


	async saveProductPlanUpdate() {
			if (this.saveProductPlanDisabled) return;

			if (!this.selectedRecord || !this.selectedRecord.Id) {
				this.showToast('Error', 'No selected record to update', 'error');
				return;
			}

			this.productPlanLoading = true;
			try {
				const result = await updateProductSubscriberPlan({ productSubscriberId: this.selectedRecord.Id, newProductPlanId: this.selectedProductPlanId });
				if (result) {
					this.showToast('Success', 'Product plan updated successfully', 'success');
					// Refresh selectedRecord from server to reflect new plan
					this.selectedRecord = await getProductSubscriberById({ productSubscriberId: this.selectedRecord.Id });
				} else {
					this.showToast('Error', 'Failed to update product plan', 'error');
				}
			} catch (err) {
				console.error('saveProductPlanUpdate error', err);
				this.showToast('Error', 'Error updating product plan', 'error');
			} finally {
				this.productPlanLoading = false;
				this.closeUpdateProductPlanModal();
			}
		}

	// Helper method to show toast messages
	showToast(title, message, variant) {
		// Using console.log for now since we don't have access to ShowToastEvent
		console.log(`${variant.toUpperCase()}: ${title} - ${message}`);
	}

	// Prevent clicks inside modals from closing them
	handleModalClick(event) {
		event.stopPropagation();
	}

	// Helper method for safe access to nested properties
	safeAccess(obj, path, defaultValue = 'N/A') {
		return path.split('.').reduce((current, prop) => {
			return current && current[prop] !== undefined ? current[prop] : null;
		}, obj) || defaultValue;
	}
}