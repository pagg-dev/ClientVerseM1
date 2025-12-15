import {LightningElement, api, track, wire} from 'lwc';
import {FlowAttributeChangeEvent} from 'lightning/flowSupport';
import {getObjectInfo} from 'lightning/uiObjectInfoApi';
import getObjects from '@salesforce/apex/FieldPickerController.getObjects';
import runDynamicQuery from '@salesforce/apex/FieldPickerController.runDynamicQuery';
import updateListQuery from '@salesforce/apex/FieldPickerController.updateListQuery';
import deleteOldJobs from '@salesforce/apex/FieldPickerController.deleteOldJobs';
import scheduleQueryJob from '@salesforce/apex/FieldPickerController.scheduleQueryJob';
import createListMembers from '@salesforce/apex/FieldPickerController.createListMembers';
import { standardObjectOptions} from 'c/fieldSelectorUtils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import QUERY_FIELD from '@salesforce/schema/List__c.List_Query_String__c';
import { getRecord } from 'lightning/uiRecordApi';

export default class soqlQueryBuilder extends LightningElement {

    //Added Code

    @track queryReady = false;   
    @track tableData;            
    @track tableColumns = [];  
    @api recordId;
    @track updateFrequency;
    @track showSaveModal = false;
    @track jobName = '';
    @track modalFrequency = '';
    @track parentWhere = '';
    @track childWhere = {};
    @track fullWhere = '';
    @track NoData = false;

    @api label = "Create SOQL Query";
    @track header = "Create SOQL Query";
    @api disableObjectTypeSelection;
    @track _objectType;
    @track fields = [];
    @track whereClause;
    @track orderByField;
    @track orderByDirection;
    @track limit;
    @track _objectTypes = standardObjectOptions;
    @track _queryString;
    @track _selectedFields = [];
    @track fieldPickerStyle;
    isError;
    isConditionBuilderInitialized = false;
    errors = [];

    fieldOptions = [];
    labels = {
        chooseFields: 'Return which fields:',
        availableFields: 'Add fields',
        generatedQuery: 'Return Records meeting the following conditions:',
        whereClauses: 'Create the where clauses to your query below',
        orderBy: 'Order the number of results by:',
        incompatibleObject: 'The soql string that was passed in was incompatible with the provided object type name',
        lockObjectButNoSoqlNoObject: 'You need to either specify the object type, pass in an existing soql string, or allow the user to choose the object type',
        buttonRemoveAll: 'Remove All'
    };

    orderByDirections = [{label: 'ASC', value: 'ASC'}, {label: 'DESC', value: 'DESC'}];


    //Added Code

    handleSaveQuery() {
    this.showSaveModal = true;
    }

    closeSaveModal() {
        this.showSaveModal = false;
    }

    handleJobNameChange(event) {
        this.jobName = event.target.value;
    }

    handleModalFrequencyChange(event) {
        this.modalFrequency = event.detail.value;
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [QUERY_FIELD]
    })
    wiredListRecord({ error, data }) {
        if (data) {
            const savedQuery = data.fields.List_Query_String__c.value;

            if (savedQuery && !this.tableData) {
                this._queryString = savedQuery;
                this.parseQuery(savedQuery);

                setTimeout(() => {
                    this.handleRunQuery();
                }, 0);
            }
        } else if (error) {
            console.error('Error loading List record: ', error);
        }
    }
    @api
    get objectType() {
        return this._objectType;
    }

    set objectType(value) {
        if (!this._objectType || !this.disableObjectTypeSelection) {
            this._objectType = value;
        } else if (this._objectType !== value && this.disableObjectTypeSelection) {
            this.errors.push(this.labels.incompatibleObject);
        }
    }

    @api
    get queryString() {
        return this._queryString;
    }

    set queryString(value) {
        this.parseQuery(value);
    }

    getNextKeywordIndex(query, indexes) {
        let validIndexes = indexes.filter(curIndex => curIndex !== -1);
        if (!validIndexes || !validIndexes.length) {
            return query.length;
        } else {
            return Math.min(...validIndexes);
        }
    }

    get errorMessage() {
        let errorResult = '';
        if (this.errors.length) {
            errorResult += this.errors.join('\n');
        }
        if (!this._objectType && !this._queryString && this.disableObjectTypeSelection) {
            errorResult += this.labels.lockObjectButNoSoqlNoObject;
        }
        return errorResult;
    }

    parseQuery(value) {
        this._queryString = value ? value : '';
        if (!value) {
            this.clearSelectedValues();
            this.addEmptyCondition();
            this.dispatchSoqlChangeEvent();
            return;
        }

        let selectIndex = value.indexOf("SELECT ");
        let fromIndex = value.indexOf(" FROM ");
        let whereIndex = value.indexOf(" WHERE ");
        let orderByIndex = value.indexOf(" ORDER BY ");
        let limitIndex = value.indexOf(" LIMIT ");

        if (fromIndex !== -1) {
            let objectName = value.substring(fromIndex + 6, this.getNextKeywordIndex(value, [whereIndex, orderByIndex, limitIndex]));
            if (objectName) {
                if (!this._objectType || !this.disableObjectTypeSelection) {
                    this._objectType = objectName.trim();
                } else if (this._objectType !== objectName.trim() && this.disableObjectTypeSelection) {
                    this.errors.push(this.labels.incompatibleObject);
                    return;
                }
            }
        }

        if (value.indexOf("SELECT ") !== -1) {
            let selectedFields = value.substring(selectIndex + 7, value.indexOf(" FROM "));
            this._selectedFields = selectedFields.split(',').map(curField => curField.trim());

        } else {
            this._selectedFields = [];
        }

        if (whereIndex !== -1) {
            this.whereClause = value.substring(whereIndex + 7, this.getNextKeywordIndex(value, [orderByIndex, limitIndex]));
        } else {
            this.whereClause = null;
            this.clearConditions();
            this.addEmptyCondition();
        }

        if (orderByIndex) {
            let orderByClause = value.substring(orderByIndex + 10);
            let orderByParts = orderByClause.split(' ');
            this.orderByField = orderByParts[0];
            this.orderByDirection = orderByParts.length > 1 ? (orderByParts[1] === 'ASC' || orderByParts[1] === 'DESC' ? orderByParts[1] : null) : null;
        } else {
            this.orderByField = null;
            this.orderByDirection = null;
        }

        if (limitIndex !== -1) {
            let limit = value.substring(limitIndex + 7);
            this.limit = limit;
        } else {
            this.limit = null;
        }
        this.prepareFieldDescriptors();
        this.dispatchSoqlChangeEvent();
    }

    get fieldOptionsWithNone() {
        return [...[{label: '--NONE--', value: ''}], ...this.fieldOptions];
    }

    get conditionBuilderDisabled() {
        return !this._objectType;
    }

    get conditionBuilderStyle() {
        return !this._objectType ? 'display: none' : '';
    }

    prepareFieldDescriptors() {
        if (this.fieldOptions && this.fieldOptions.length) {
            this.fields = this.fieldOptions.map(curField => {
                return {
                    ...curField, ...{
                        selected: this._selectedFields.includes(curField.value)
                    }
                };
            });
        } else {
            this.fields = [];
        }
    }

    buildQuery() {

        if (!this._objectType || !this._selectedFields.length) {
            return;
        }

        const parentFields = [];
        const childFieldsMap = {};

        this._selectedFields.forEach(f => {
            if (f.includes(".")) {
                const [rel, field] = f.split(".");
                if (!childFieldsMap[rel]) childFieldsMap[rel] = [];
                childFieldsMap[rel].push(field);
            } else {
                parentFields.push(f);
            }
        });

        let selectParts = [...parentFields];

        Object.keys(childFieldsMap).forEach(rel => {

            const fields = childFieldsMap[rel].join(", ");
            const filters = this.childWhere[rel]
                ? " WHERE " + this.childWhere[rel].join(" AND ")
                : "";

            selectParts.push(`(SELECT ${fields} FROM ${rel}${filters})`);
        });

        let resultQuery = `SELECT ${selectParts.join(", ")} FROM ${this._objectType}`;

        if (this.parentWhere && !this.fullWhere) {
            resultQuery += ` WHERE ${this.parentWhere}`;
        }

        if (this.fullWhere && this.parentWhere) {
            resultQuery += ` WHERE ${this.fullWhere}`;
        }

        if (this.fullWhere && !this.parentWhere) {
            resultQuery += ` WHERE ${this.fullWhere}`;
        }

        if (this.orderByField) {
            resultQuery += ` ORDER BY ${this.orderByField} ${this.orderByDirection}`;
        }

        if (this.limit) {
            resultQuery += ` LIMIT ${this.limit}`;
        }

        console.log('ressultquery');
        console.log(resultQuery);
        this._queryString = resultQuery;
        this.queryReady = true;

        this.dispatchSoqlChangeEvent();
    }


    dispatchSoqlChangeEvent() {
        const attributeChangeEvent = new FlowAttributeChangeEvent('queryString', this._queryString);
        this.dispatchEvent(attributeChangeEvent);
        this.dispatchEvent(new CustomEvent('change', { detail: this._queryString }));
    }

    clearSelectedValues() {
        this._selectedFields = [];
        this.whereClause = '';
        this._queryString = '';
        this.limit = null;
        this.orderByField = null;
        this.orderByDirection = null;
        this.clearConditions();
        this.dispatchSoqlChangeEvent();
    }

    clearConditions() {
        let conditionBuilder = this.template.querySelector('c-condition-builder');
        if (conditionBuilder) {
            conditionBuilder.clearConditions();
        }
    }

    handleConditionChanged(event) {
        const whereInfo = event.detail.whereClause;

        if (whereInfo?.type === "child") {

            if (!this.childWhere[whereInfo.relationshipName]) {
                this.childWhere[whereInfo.relationshipName] = [];
            }

            this.childWhere[whereInfo.relationshipName].push(
                `${whereInfo.fieldName} = '${whereInfo.value}'`
            );

            this.buildQuery();
            return;
        }

        if (whereInfo?.parentWhere) {
            this.parentWhere = whereInfo.parentWhere;
        }
        // console.log('parentWhere');
        // console.log(this.parentWhere);
        if (whereInfo?.fullWhere) {
            this.fullWhere = whereInfo.fullWhere;
        }
        // console.log('fullWhere');
        // console.log(this.fullWhere);

        this.buildQuery();
    }

    handleObjectTypeChange(event) {
        this._objectType = event.detail.value;
        this.clearSelectedValues();
        this.addEmptyCondition();
    }

    addEmptyCondition() {
        let conditionBuilder = this.template.querySelector('c-condition-builder');
        if (conditionBuilder) {
            conditionBuilder.addEmptyCondition({preventErrors: true});
        }
    }

    handleSoqlChange(event) {
        this.parseQuery(event.target.value);

    }

    handleFieldSelected(event) {
        const field = event.detail.value;

        // Ignore relationship ROOTS, not normal fields.
        // Relationship roots have no dot AND appear in fieldOptions as isParentSObject.
        const option = this.fieldOptions.find(f => f.value === field);

        if (option && option.isSObject && !field.includes('.')) {
            // User clicked the relationship label, not a field
            return;
        }

        this._selectedFields = this.toggle(this._selectedFields, field, true);
        this.prepareFieldDescriptors();
        this.buildQuery();
    }

    handleRemoveAll(event) {
        this._selectedFields = [];
        this.prepareFieldDescriptors();
        this._queryString = '';
        this.buildQuery();
    }

    handleAddAll(event) {
        this._selectedFields = this.fieldOptions.map(curOption => curOption.value);
        this.prepareFieldDescriptors();
        this.buildQuery();
    }

    handleFieldRemove(event) {
        this._selectedFields = this.toggle(this._selectedFields, event.detail.value);
        if (!this._selectedFields || !this._selectedFields.length) {
            this._queryString = '';
        }
        this.prepareFieldDescriptors();
        this.buildQuery();
    }

    @wire(getObjects, {})
    _getObjects({error, data}) {
        if (error) {
            console.log(error.body.message);
        } else if (data) {
            this._objectTypes = data;
        }
    }

    @wire(getObjectInfo, {objectApiName: '$_objectType'})
    _getObjectInfo({error, data}) {
        if (error) {
            console.log(error.body[0].message);
        } else if (data) {
            this.fieldOptions = Object.keys(data.fields).map(curFieldName => {
                let curField = data.fields[curFieldName];
                return {label: curField.label, value: curField.apiName, dataType: curField.dataType}
            }).sort((a, b) => (a.label > b.label) ? 1 : ((b.label > a.label) ? -1 : 0));
            this.prepareFieldDescriptors();
        }
    }

    calculateFieldPickerStyle() {
        if (!this.isConditionBuilderInitialized) {
            this.isConditionBuilderInitialized = true;
            if (!this.whereClause) {
                this.addEmptyCondition();
            }
        }

        let fieldPickerContainer = this.template.querySelector('.field-picker-container');
        if (fieldPickerContainer) {
            let fullHeight = fieldPickerContainer.offsetHeight;
            this.fieldPickerStyle = 'min-height: 120px; height: ' + (fullHeight - 50) + 'px';
        }
    }

    toggle(array, element, skipIfPersists) {
        if (array && element) {
            if (array.includes(element)) {
                if (skipIfPersists) {
                    this.flashSelectedField(element);
                    return array;
                } else {
                    return array.filter(curElement => curElement != element);
                }
            } else {
                array.push(element);
                return array;
            }
        } else {
            return array;
        }
    }

    flashSelectedField(fieldName) {
        let selectedFields = this.template.querySelector('c-selected-fields');
        if (selectedFields) {
            selectedFields.highlightField(fieldName);
        }
    }

    handleValueChanged(event) {
        let inputName = event.target.name;
        this[inputName] = event.detail.value;
        this.buildQuery();
    }

    get isRHSDisabled() {
        return (!this._selectedFields || !this._selectedFields.length);
    }


    //Added Functionality
    handleRunQuery() {
        runDynamicQuery({ soql: this._queryString })
            .then(result => {
                this.tableData = result;
                console.log(this.tableData);
                console.log(this.tableData.length);
                if (this.tableData.length === 0) {
                    this.NoData = true;
                }
                else {
                    this.NoData = false;
                }
                this.header = null;

                if (result.length) {
                    this.tableColumns = Object.keys(result[0]).map(key => {
                        return { label: key, fieldName: key, type: 'text' };
                    });
                }

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Query executed successfully',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                console.error(error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Query Error',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }

    handleGoBack() {
        this.tableData = null;
        //this.queryReady = true; 
        console.log('test 1')
        console.log(JSON.stringify(this.fieldOptions));
        console.log('test 2');
        console.log(JSON.stringify(this.whereClause));
        console.log('test 3');
        console.log(this._queryString);
        console.log('test 4');
        console.log(this._objectType);
        this.header = "Create SOQL Query";
    }

    handleReRun() {
        window.location.reload();
    }

    updateFrequencyOptions = [
        { label: '--None--', value: '' },
        { label: 'Hourly', value: 'Hourly' },
        { label: 'Daily', value: 'Daily' },
        { label: 'Weekly', value: 'Weekly' },
        { label: 'Monthly', value: 'Monthly' },
        { label: 'Quarterly', value: 'Quarterly' },
        { label: 'Annually', value: 'Annually' }
    ];

    handleModalSave() {
        if (!this.jobName || !this.modalFrequency) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Missing Information',
                    message: 'Please enter job name and select a frequency.',
                    variant: 'error'
                })
            );
            return;
        }

        deleteOldJobs ({
             recordId: this.recordId
        }).then(() => {
            console.log('Old Job Deleted');
        })

        updateListQuery({
            recordId: this.recordId,
            queryString: this._queryString,
            frequency: this.modalFrequency,
            jobName : this.jobName
        })
        .then(() => {

            return scheduleQueryJob({
                recordId: this.recordId,
                soql: this._queryString,
                frequency: this.modalFrequency,
                jobName: this.jobName
            });

        })
        .then(() => {

            this.showSaveModal = false;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Query saved and job scheduled successfully.',
                    variant: 'success'
                })
            );

        })
        .catch(error => {
            console.error(error);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message,
                    variant: 'error'
                })
            );
        });
        this.handleSaveMembers();
    }


    handleSaveMembers() {
        if (!this.tableData || this.tableData.length === 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'No Data',
                message: 'No contacts available to save.',
                variant: 'warning'
            }));
            return;
        }

        const contactIds = this.tableData.map(row => row.Id);

        createListMembers({
            listId: this.recordId,
            contactIds: contactIds
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'List Members created successfully.',
                variant: 'success'
            }));
        })
        .catch(error => {
            console.error(error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error creating List Members',
                message: error.body.message,
                variant: 'error'
            }));
        });
    }
}