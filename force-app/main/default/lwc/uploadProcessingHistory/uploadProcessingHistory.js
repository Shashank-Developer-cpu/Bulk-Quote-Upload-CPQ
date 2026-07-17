import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getProcessingHistory from '@salesforce/apex/QuoteBulkUploadController.getProcessingHistory';
import getErrorReport from '@salesforce/apex/QuoteBulkUploadController.getErrorReport';

function csvEscape(value) {
    if (value === undefined || value === null) return '';
    const str = String(value);
    if (str.includes(',') || str.includes('"') || str.includes('\n')) {
        return '"' + str.replace(/"/g, '""') + '"';
    }
    return str;
}

const COLUMNS = [
    {
        label: 'Upload Process', fieldName: 'recordUrl', type: 'url',
        typeAttributes: { label: { fieldName: 'Name' }, target: '_self' }
    },
    { label: 'Status', fieldName: 'Status__c' },
    { label: 'Total Quotes', fieldName: 'Total_Quotes__c', type: 'number' },
    { label: 'Successful', fieldName: 'Successful_Quotes__c', type: 'number' },
    { label: 'Failed', fieldName: 'Failed_Quotes__c', type: 'number' },
    { label: 'Total Quote Lines', fieldName: 'Total_Quote_Lines__c', type: 'number' },
    {
        label: 'Uploaded On', fieldName: 'CreatedDate', type: 'date',
        typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View Record', name: 'view' },
                { label: 'Download Error Report', name: 'download_errors' }
            ]
        }
    }
];

export default class UploadProcessingHistory extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    records = [];
    wiredResult;
    isLoading = true;
    isDownloading = false;

    @wire(getProcessingHistory)
    wiredHistory(result) {
        this.wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.records = result.data.map((r) => ({
                ...r,
                recordUrl: '/lightning/r/Upload_Process__c/' + r.Id + '/view'
            }));
        } else if (result.error) {
            console.error(result.error);
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        await refreshApex(this.wiredResult);
        this.isLoading = false;
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.Id,
                    objectApiName: 'Upload_Process__c',
                    actionName: 'view'
                }
            });
        } else if (actionName === 'download_errors') {
            await this.downloadErrorsFor(row);
        }
    }

    async downloadErrorsFor(row) {
        this.isDownloading = true;
        try {
            const errors = await getErrorReport({ processId: row.Id });
            const csv = this.buildCsv(errors);
            this.triggerDownload(csv, row.Name + '_Error_Report.csv');
        } catch (error) {
            console.error(error);
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

        errorRows.forEach((row) => {
            let rowData = {};
            if (row.Row_Data__c) {
                try {
                    rowData = JSON.parse(row.Row_Data__c);
                } catch (e) {
                    rowData = {};
                }
            }
            const values = [
                row.Row_Number__c, row.Quote_Number__c, row.Product_Name__c, row.Error_Message__c,
                rowData.customerName, rowData.opportunityName, rowData.quoteName,
                rowData.quantity, rowData.salesPrice, rowData.quoteStartDate, rowData.quoteEndDate, rowData.notes
            ].map(csvEscape);
            lines.push(values.join(','));
        });

        return lines.join('\n');
    }

    triggerDownload(content, fileName) {
        const blob = new Blob([content], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = fileName;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    }

    get hasRecords() {
        return this.records && this.records.length > 0;
    }
}