import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sheetjs from '@salesforce/resourceUrl/sheetjs';
import { loadScript } from 'lightning/platformResourceLoader';
import previewValidation from '@salesforce/apex/QuoteBulkUploadController.previewValidation';
import submitForProcessing from '@salesforce/apex/QuoteBulkUploadController.submitForProcessing';
import getProcessStatus from '@salesforce/apex/QuoteBulkUploadController.getProcessStatus';
import getErrorReport from '@salesforce/apex/QuoteBulkUploadController.getErrorReport';

const POLL_INTERVAL_MS = 3000;
const TERMINAL_STATUSES = ['Completed', 'Failed'];
const STORAGE_KEY = 'quoteBulkUpload_lastRun';

function csvEscape(value) {
    const str = value === null || value === undefined ? '' : String(value);
    if (str.includes(',') || str.includes('"') || str.includes('\n')) {
        return '"' + str.replace(/"/g, '""') + '"';
    }
    return str;
}

export default class QuoteBulkUpload extends LightningElement {

    selectedFile;
    sheetJsInitialized = false;

    excelData = [];
    pendingWrapperData; // rows sent to previewValidation, re-sent to submitForProcessing on confirm

    isValidating = false;
    isSubmitting = false;
    isDownloading = false;
    isResuming = false;

    validationResponse; // QuoteUploadResponse from previewValidation/submitForProcessing
    processStatus;      // Upload_Process__c fields, refreshed by polling

    pollIntervalId;

    columns = [
        { label: 'Quote Number', fieldName: 'Quote Number' },
        { label: 'Customer', fieldName: 'Customer Name' },
        { label: 'Opportunity', fieldName: 'Opportunity Name' },
        { label: 'Quote', fieldName: 'Quote Name' },
        { label: 'Product', fieldName: 'Product Name' },
        { label: 'Quantity', fieldName: 'Quantity', type: 'number' },
        { label: 'Sales Price', fieldName: 'Sales Price', type: 'currency' }
    ];

    connectedCallback() {
        this.tryResumePreviousRun();
    }

    renderedCallback() {
        if (this.sheetJsInitialized) {
            return;
        }
        this.sheetJsInitialized = true;

        loadScript(this, sheetjs)
            .then(() => {
                console.log('SheetJS Loaded Successfully');
            })
            .catch(error => {
                console.error(error);
            });
    }

    disconnectedCallback() {
        this.stopPolling();
    }

    // --- Resume support -----------------------------------------------------
    // Processing keeps running server-side regardless of what the browser does.
    // We persist the last submitted run's id + validation summary to localStorage
    // so reopening this page (even a fresh tab, even after closing the browser)
    // can pick the live status back up instead of losing all context.

    async tryResumePreviousRun() {
        let saved;
        try {
            saved = JSON.parse(window.localStorage.getItem(STORAGE_KEY));
        } catch (e) {
            saved = null;
        }
        if (!saved || !saved.uploadProcessId) {
            return;
        }

        this.isResuming = true;
        this.validationResponse = saved.validationResponse;

        try {
            const status = await getProcessStatus({ processId: saved.uploadProcessId });
            this.processStatus = status;
            if (!TERMINAL_STATUSES.includes(status.Status__c)) {
                this.startPolling(saved.uploadProcessId);
            }
        } catch (error) {
            // The stored process id is no longer valid (e.g. deleted) - drop it.
            console.error(error);
            window.localStorage.removeItem(STORAGE_KEY);
            this.validationResponse = undefined;
        } finally {
            this.isResuming = false;
        }
    }

    persistRun() {
        if (!this.validationResponse || !this.validationResponse.uploadProcessId) {
            return;
        }
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify({
            uploadProcessId: this.validationResponse.uploadProcessId,
            validationResponse: this.validationResponse
        }));
    }

    clearPersistedRun() {
        window.localStorage.removeItem(STORAGE_KEY);
    }

    resetForNewUpload() {
        this.stopPolling();
        this.clearPersistedRun();
        this.excelData = [];
        this.pendingWrapperData = undefined;
        this.validationResponse = undefined;
        this.processStatus = undefined;
        this.selectedFile = undefined;
    }

    // --- File handling / validation preview ----------------------------------

    handleFileChange(event) {
        this.selectedFile = event.target.files[0];
        if (!this.selectedFile) {
            return;
        }

        this.stopPolling();
        this.clearPersistedRun();
        this.validationResponse = undefined;
        this.processStatus = undefined;

        const reader = new FileReader();

        reader.onload = (e) => {
            const workbook = window.XLSX.read(e.target.result, { type: 'binary' });
            const worksheet = workbook.Sheets[workbook.SheetNames[0]];
            this.excelData = window.XLSX.utils.sheet_to_json(worksheet);
            this.excelData = this.excelData.map((row, index) => {
                return {
                    id: index + 1,
                    ...row
                };
            });
        };
        reader.readAsBinaryString(this.selectedFile);
    }

    async validateExcel() {
        const wrapperData = this.convertToWrapper();

        this.isValidating = true;
        this.validationResponse = undefined;
        this.processStatus = undefined;
        this.stopPolling();
        this.clearPersistedRun();

        try {
            const result = await previewValidation({ excelRows: wrapperData });
            this.validationResponse = result;
            this.pendingWrapperData = wrapperData; // re-sent on confirm, nothing written yet
        } catch (error) {
            console.error(error);
        } finally {
            this.isValidating = false;
        }
    }

    convertToWrapper() {
        return this.excelData.map((row, index) => {
            return {
                rowNumber: index + 2,
                quoteNumber: row["Quote Number"],
                customerName: row["Customer Name"],
                opportunityName: row["Opportunity Name"],
                quoteName: row["Quote Name"],
                productName: row["Product Name"],
                quantity: row["Quantity"],
                salesPrice: row["Sales Price"],
                quoteStartDate: row["Quote Start Date"],
                quoteEndDate: row["Quote End Date"],
                notes: row["Notes"]
            };
        });
    }

    // --- Confirmation step ----------------------------------------------------

    async confirmProcessing() {
        if (!this.pendingWrapperData) {
            return;
        }

        this.isSubmitting = true;
        try {
            const result = await submitForProcessing({ excelRows: this.pendingWrapperData });
            this.validationResponse = result;

            if (result.uploadProcessId) {
                this.persistRun();
                this.startPolling(result.uploadProcessId);
            }
        } catch (error) {
            console.error(error);
        } finally {
            this.isSubmitting = false;
        }
    }

    cancelProcessing() {
        this.validationResponse = undefined;
        this.pendingWrapperData = undefined;
    }

    // --- Live status polling ---------------------------------------------------

    startPolling(processId) {
        this.refreshStatus(processId);
        this.pollIntervalId = setInterval(() => {
            this.refreshStatus(processId);
        }, POLL_INTERVAL_MS);
    }

    stopPolling() {
        if (this.pollIntervalId) {
            clearInterval(this.pollIntervalId);
            this.pollIntervalId = undefined;
        }
    }

    async refreshStatus(processId) {
        try {
            const status = await getProcessStatus({ processId });
            this.processStatus = status;

            if (TERMINAL_STATUSES.includes(status.Status__c)) {
                this.stopPolling();
            }
        } catch (error) {
            console.error(error);
            this.stopPolling();
        }
    }

    // --- Error report CSV -------------------------------------------------------

    async downloadErrorReport() {
        if (!this.validationResponse || !this.validationResponse.uploadProcessId) {
            return;
        }

        this.isDownloading = true;
        try {
            const errors = await getErrorReport({ processId: this.validationResponse.uploadProcessId });
            const csv = this.buildCsv(errors);
            this.triggerDownload(csv, 'Upload_Error_Report.csv');
        } catch (error) {
            console.error(error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Could not download error report',
                message: error && error.body && error.body.message ? error.body.message : 'An unexpected error occurred.',
                variant: 'error'
            }));
        } finally {
            this.isDownloading = false;
        }
    }

    buildCsv(errorRows) {
        const headers = [
            'Row Number', 'Quote Number', 'Product Name', 'Error Message',
            'Customer Name', 'Opportunity Name', 'Quote Name',
            'Quantity', 'Sales Price', 'Quote Start Date', 'Quote End Date', 'Notes'
        ];
        const lines = [headers.map(csvEscape).join(',')];

        errorRows.forEach(row => {
            // Row_Data__c (the original Excel row as JSON) is only populated for row-level
            // validation errors, not quote/line processing failures - parse it when present
            // so each field gets its own column instead of one raw JSON blob.
            let rowData = {};
            if (row.Row_Data__c) {
                try {
                    rowData = JSON.parse(row.Row_Data__c);
                } catch (e) {
                    rowData = {};
                }
            }

            const values = [
                row.Row_Number__c,
                row.Quote_Number__c,
                row.Product_Name__c,
                row.Error_Message__c,
                rowData.customerName,
                rowData.opportunityName,
                rowData.quoteName,
                rowData.quantity,
                rowData.salesPrice,
                rowData.quoteStartDate,
                rowData.quoteEndDate,
                rowData.notes
            ].map(csvEscape);

            lines.push(values.join(','));
        });

        return lines.join('\n');
    }

    triggerDownload(content, fileName) {
        // Lightning Web Security rejected 'text/csv' outright, and even 'text/plain;charset=
        // utf-8;' still triggered "Unsupported MIME type" - LWS's MIME check appears not to
        // parse the ';charset=...' suffix correctly. Per Salesforce's own LWS documentation,
        // an empty MIME type on a Blob is treated as text/plain, which IS supported - so we
        // omit the type entirely rather than specify one.
        const blob = new Blob([content]);
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = fileName;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    }

    // --- Template getters ---------------------------------------------------

    get validationErrorRows() {
        if (!this.validationResponse || !this.validationResponse.errors) {
            return [];
        }
        return this.validationResponse.errors.map((message, index) => {
            return { key: 'err-' + index, message };
        });
    }

    get hasValidationErrors() {
        return this.validationErrorRows.length > 0;
    }

    get canProceedToProcessing() {
        return !!(this.validationResponse
            && this.validationResponse.validRows > 0
            && !this.validationResponse.uploadProcessId);
    }

    get noValidRows() {
        return !!(this.validationResponse
            && this.validationResponse.validRows === 0
            && !this.validationResponse.uploadProcessId);
    }

    get isProcessingInFlight() {
        return !!(this.processStatus && !TERMINAL_STATUSES.includes(this.processStatus.Status__c));
    }

    get processedCount() {
        if (!this.processStatus) {
            return 0;
        }
        return (this.processStatus.Successful_Quotes__c || 0) + (this.processStatus.Failed_Quotes__c || 0);
    }

    get progressPercent() {
        if (!this.processStatus || !this.processStatus.Total_Quotes__c) {
            return 0;
        }
        return Math.round((this.processedCount / this.processStatus.Total_Quotes__c) * 100);
    }

    get isTerminalStatus() {
        return !!(this.processStatus && TERMINAL_STATUSES.includes(this.processStatus.Status__c));
    }

    get hasAnyFailures() {
        if (this.processStatus && this.processStatus.Failed_Quotes__c > 0) {
            return true;
        }
        return !!(this.validationResponse && this.validationResponse.invalidRows > 0);
    }
}