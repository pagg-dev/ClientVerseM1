import { LightningElement, api,wire, track } from 'lwc';
import parseCsv from '@salesforce/apex/CSVImportController.parseCsv';
import importRowsWithFile from '@salesforce/apex/CSVImportController.importRowsWithFile';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference } from 'lightning/navigation';
import COLORS from '@salesforce/resourceUrl/bgColor';
import {loadStyle} from 'lightning/platformResourceLoader';

export default class CsvImportFunctionality extends LightningElement {
    wireRecordId;
    currectRecordId;
    @track rows = [];
    draftValues = [];
    isCssLoaded = false;
    emailCounts = {};
    @track currentStep = 1;
    @track selectedRowsData = [];
    mergePanel=false;
    isIncorrectSelection=false;
    finalMergeRow=[];
    showRowNumber=false;


    get showExact() { return this.currentStep === 1; }
    get showFuzzy() { return this.currentStep === 2; }

    get showCsvDuplicate() { return this.currentStep === 3; }
    get showAlreadyLinked() { return this.currentStep === 4; }
    get showNone() { return this.currentStep === 5; }

    get isFirstStep() { return this.currentStep === 1; }
    get isLastStep() { return this.currentStep === 5; }
    get isNotLastStep() { return this.currentStep !== 5; }
    

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.wireRecordId = currentPageReference.state.recordId;
        }
    }

    get exactRows() {
        return this.styledRows.filter(r =>{
            console.log('exact fuzzy : ',r.email, r.matchType);
            return r.matchType === 'EMAIL MATCH'
        });
    }

    get exactRowsLength() {
        return this.exactRows.length;
    }

    get fuzzyRows() {
        return this.styledRows.filter(r =>{
            console.log('exact fuzzy : ',r.email, r.matchType);
            return r.matchType === 'FUZZY MATCH'
        });
    }

    get fuzzyRowsLength() {
        return this.fuzzyRows.length;
    }

    get alreadyLinkedRows() {
        return this.styledRows.filter(r =>
            r.isDuplicate === true
        );
    }

    get alreadyLinkedRowsLength() {
        return this.alreadyLinkedRows.length;
    }


    get duplicateRows() {
        const data = this.styledRows.filter(r =>
            this.counts[r.email] > 1
        );
        return data.sort((a, b) =>
            a.email.localeCompare(b.email)
        );

    }

    get duplicateRowsLength() {
        return this.duplicateRows.length;
    }

    get noneMatchRows() {
        return this.styledRows.filter(r =>{
            console.log('non : ', r.email, r.matchType);
            return r.matchType === 'NONE' 
        });
    }

    get noneMatchRowsLength() {
        return this.noneMatchRows.length;
    }

    get styledRows() {
        return this.rows.map(r => {
            console.log('SR : ',r.email,r.matchType);
            return { 
                ...r, 
                duplicateColor: r.isDuplicate || this.counts[r.email] > 1 ? "duplicate-row" : "",
                matchType: this.counts[r.email] > 1 ? 'CSV contains the duplicate email' : r.matchType
            };
        });
    }

    
    get incorrectSelection(){
        const result = this.selectedRowsData.every(
            (item) => item.email === this.selectedRowsData[0].email
        );
        return !result;

    }

    get showMergePanel(){
            return this.incorrectSelection==false && this.mergePanel;
    }

    @api set recordId(value) {
        this.currectRecordId = value;
        console.log('this.currectRecordId ',this.currectRecordId);
    }

    get recordId() {
        return this.currectRecordId;
    }

    get isDataNotFilled() {
        for (let key in this.finalMergeRow[0]) {
            if (!this.finalMergeRow[0].hasOwnProperty(key)) continue; // skip inherited properties
            const value = this.finalMergeRow[0][key];

            // Check if value is null, undefined, or empty string after trimming
            if (value === null || value === undefined || value.toString().trim() === '') {
                return true; // At least one empty field
            }
        }
        return false;
    }



    columns = [
        { label: 'First Name', fieldName: 'firstName', editable: true, cellAttributes:{
        class:{fieldName:'duplicateColor'}
        } },
        { label: 'Last Name', fieldName: 'lastName', editable: true,cellAttributes:{
        class:{fieldName:'duplicateColor'}
        } },
        { label: 'Email', fieldName: 'email', editable: true,cellAttributes:{
        class:{fieldName:'duplicateColor'}
        } },
        { label: 'Company', fieldName: 'company', editable: true,cellAttributes:{
        class:{fieldName:'duplicateColor'}
        }  },
        { label: 'Title', fieldName: 'title',cellAttributes:{
        class:{fieldName:'duplicateColor'}
        }  },
        { label: 'Match Type', fieldName: 'matchType',cellAttributes:{
        class:{fieldName:'duplicateColor'}
        }  },
        { label: 'Matched Contact', fieldName: 'matchedContactId',cellAttributes:{
        class:{fieldName:'duplicateColor'}
        }  },
        // {
        //     fieldName: '',
        //     label: '',
        //     cellAttributes: { class:{fieldName:'duplicateColor'}, iconName: 'utility:delete' }
        // }
        {
            type: 'button-icon',
            typeAttributes: {
                iconName: 'utility:delete',
                title: 'Delete',
                variant: 'bare',
                alternativeText: 'Delete',
                actionName: 'delete'
            },
            cellAttributes: { class:{fieldName:'duplicateColor'}}
        }

    ];


    mergeColumns = [
        { label: 'First Name', fieldName: 'firstName' },
        { label: 'Last Name', fieldName: 'lastName' },
        { label: 'Email', fieldName: 'email'},
        { label: 'Company', fieldName: 'company'},
        { label: 'Title', fieldName: 'title'},
        { label: 'Match Type', fieldName: 'matchType'},
        { label: 'Matched Contact', fieldName: 'matchedContactId' }
    ];


    finalMergeColumns = [
        { label: 'First Name', fieldName: 'firstname', editable: true },
        { label: 'Last Name',  fieldName: 'lastname', editable: true },
        { label: 'Email', fieldName: 'email', editable: false },
        { label: 'Company', fieldName: 'company', editable: true },
        { label: 'Title', fieldName: 'title', editable: true }
    ];



    handleNext() {
        if (this.currentStep < 5) {
            this.currentStep++;
        }
    }

    handlePrevious() {
        if (this.currentStep > 1) {
            this.currentStep--;
        }
    }
    
    renderedCallback(){ 
        if(this.isCssLoaded) return
        this.isCssLoaded = true
        loadStyle(this, COLORS).then(()=>{
            console.log("Loaded Successfully")
        }).catch(error=>{ 
            console.error("Error in loading the colors")
        })
    }


    handleFileUpload(event) {
        const file = event.target.files[0];
        this.fileName = file.name;

        const reader = new FileReader();
        this.counts = {};
        reader.onload = () => {
            this.fileContent = reader.result;

            parseCsv({ csvBody: reader.result, listId: this.currectRecordId })
                .then(data => {
                    
                    this.rows = data.map((r, index) => {
                        if(r.email!=null)
                            this.counts[r.email] = (this.counts[r.email] || 0) + 1;
                        return { id: index, ...r }});
                    console.log('Count : ',this.counts);    
                })
                .catch(err => console.error(err));
        };

        reader.readAsText(file);
    }

    handleSaveDraft(event) {
        const updates = event.detail.draftValues;
        updates.forEach(update => {
            const rowIndex = this.rows.findIndex(r => r.id === update.id);
            Object.assign(this.rows[rowIndex], update);
        });
        this.draftValues = [];
    }

    handleImport() {
        const defaults = {
            Status__c: 'Included',
            Source_List_Name__c: 'CSV Import'
        };

        const cleanedRows = this.rows.map(({ id, ...rest }) => rest);

        importRowsWithFile({
            rows: cleanedRows,
            listId: this.currectRecordId,
            defaultFields: defaults,
            fileName: this.fileName,
            fileContent: this.fileContent
        })
        .then(() => {
            this.dispatchEvent(new CloseActionScreenEvent());
        })
        .catch(err => console.error(err));
    }

    handleClose() {

        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleRowAction(event) {
        const cleanObj = JSON.parse(JSON.stringify(event.detail.action));

        //console.log('cleanObj',cleanObj);
        //console.log(JSON.parse(JSON.stringify(event)));
        //console.log(unwrap(event));
        
        c//onsole.log(unwrap(event.detail.action));

        setTimeout((event) => {
                console.log('late',JSON.parse(JSON.stringify(event)));
        }, 2000);

        const action = event.detail.action.name;
        const row = event.detail.row;

        console.log('handleRowAction : ',action, row);

        //if (action === 'delete') {
            this.deleteRow(row);
        //}
    }

    deleteRow(row) {
                console.log('rows beofre : ', this.rows);
        this.rows = this.rows.filter(r => r.id !== row.id);
                        console.log('rows after : ', this.rows);
    }


    handleSelectedRows(event) {
        console.log('handleSelectedRows ',JSON.stringify(event.detail.selectedRows));
        this.selectedRowsData = [...event.detail.selectedRows];
        console.log('Selected Rows ',JSON.stringify(this.selectedRowsData));
    }

    handleMerge(){
        if(!this.incorrectSelection)
        {       
            this.mergePanel=true;
            this.template.querySelector('lightning-datatable').selectedRows = [];
            this.finalMergeRow = [{
                firstname: '',
                lastname: '',
                email: this.selectedRowsData[0].email,
                company: '',
                title: ''
            }];
        }
        else{
            this.isIncorrectSelection=true;
             setTimeout(() => {
                 this.isIncorrectSelection = false;
             }, 2000);
        }
    }

    handleCellChange(event) {
        // updated values come in event.detail.draftValues
        const changedValues = event.detail.draftValues;

        // // merge changes into data
        // changedValues.forEach(change => {
        //     const index = this.finalMergeRow.findIndex(row => row.id === change.id);
        //     if (index !== -1) {
        //         this.finalMergeRow = [
        //             ...this.finalMergeRow.slice(0, index),
        //             { ...this.finalMergeRow[index], ...change },
        //             ...this.finalMergeRow.slice(index + 1)
        //         ];
        //     }
        // });

        this.finalMergeRow = [{ ...this.finalMergeRow[0], ...changedValues[0] }];

        // clear draft values to visually commit edit
        this.template.querySelector('[data-id="finalMergeTable"]').draftValues = [];
    }

    handleRowMerge(){
        alert('Update CSV');
    }

    
}