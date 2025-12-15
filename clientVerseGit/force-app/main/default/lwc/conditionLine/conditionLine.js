import {LightningElement, track, wire, api} from 'lwc';
import getChildRelationships from '@salesforce/apex/ChildRelationshipController.getChildRelationships';

export default class ConditionLine extends LightningElement {
    @api allOperations;
    @api allFields;
    @api fieldName;
    _fieldType;
    _objectType;
    @api operation;
    @api value;
    @api lineId;
    @api index;
    @api conditionCount;
    @api fieldTypeSettings;
    @api preventErrors;
    @api disabled;
    @track childRelationships = [];
    @track selectedChildRelationship;
    @track childFields = [];
    @track hasChildValue = false;
    @track hasValue = false;
    @track selectedChildField;
    @track isChildField = false;

    
    @api get objectType() {
        return this._objectType;
    }

    set objectType(value) {
        this._objectType = value;
    }

    @api get fieldType() {
        return this._fieldType;
    }

    set fieldType(value) {
        this._fieldType = value;
    }

    get inputType() {
        if (this._fieldType && this.fieldTypeSettings[this._fieldType]) {
            return this.fieldTypeSettings[this._fieldType].inputType;
        }
    }

    get availableOperations() {
        if (this.allOperations) {
            return this.allOperations.filter(curOperation => {
                if (this._fieldType) {
                    return curOperation.types.toLowerCase().includes(this._fieldType.toLowerCase());
                } else {
                    return false;
                }

            });
        }

    }

    @wire(getChildRelationships, { parentObjectApiName: '$_objectType' })
    wiredChildRels({ data, error }) {
        if (data) {
            this.childRelationships = data.filter(cr => cr.relationshipName).map(cr => ({
                label: cr.relationshipName + ' (' + cr.childObject + ')',
                value: cr.childObject,
                fields: cr.fields,
                childObject: cr.childObject
            }));
        } else if (error) {
            console.error(error);
        }
    }

    get conditionIndex() {
        return this.index + 1;
    }

    get isDisabled() {
        return (this.disabled || !this.fieldName);
    }

    get valueVariant() {
        return (this._fieldType === 'Date' || this._fieldType === 'DateTime') ? 'label-hidden' : 'label-stacked';
    }

    // handleConditionChanged(event) {
    //     let inputName = event.target.name;
    //     this[inputName] = (this._fieldType === 'Boolean' && inputName === 'value') ? event.target.checked : event.target.value;
    //     this.dispatchConditionChangedEvent();
    // }

    handleChildFieldChange(event) {
        this.selectedChildField = event.detail.value;
        this.hasValue = true;
        this.dispatchChildConditionIfComplete();
    }

    handleConditionChanged(event) {
        const inputName = event.target.name;
        this[inputName] = event.target.value;
        console.log('inputName: ' + inputName)
        console.log('event.target.value: ' + event.target.value)
        console.log(this.operation);
        if (this.operation == 'Child') {
            this.isChildField = true;
            this.hasChildValue = true;
            this.hasValue = true;
        }
        else {
            this.isChildField = false;
            this.hasChildValue = false;
            this.hasValue = false;
        }

        console.log(this.isChildField);
        // if (this.isChildField) {
        //     this.dispatchChildConditionIfComplete();
        //     return;
        // }

        // normal parent condition
        this.dispatchConditionChangedEvent();
    }

    dispatchChildConditionIfComplete() {
        if (!this.isChildField) return;
        if (!this.selectedChildRelationship) return;
        if (!this.selectedChildField) return;
        if (!this.value) return; 

        const rel = this.childRelationships.find(
            cr => cr.value === this.selectedChildRelationship
        );

        this.dispatchEvent(
            new CustomEvent("conditionchanged", {
                detail: {
                    whereClause: {
                        type: "child",
                        relationshipName: rel.value,
                        childObject: rel.childObject,
                        fieldName: this.selectedChildField,
                        value: this.value
                    }
                }
            })
        );
    }

    handleFieldChanged(event) {
        this.fieldName = event.detail.newValue;
        if (event.detail.displayType) {
            this._fieldType = event.detail.displayType;
            if (event.detail.isSObject) {
                this._objectType = event.detail.displayType;
            }
        }
        if (!this.fieldName) {
            this.value = null;
            this._fieldType = null;
        }
        this.dispatchConditionChangedEvent();
    }

    handleConditionRemove(event) {
        const filterChangedEvent = new CustomEvent('conditionremoved', {
            detail: {
                id: this.lineId
            }
        });
        this.dispatchEvent(filterChangedEvent);
    }

    get valueClass() {
        let resultClass = '';
        if (this._fieldType === 'Date' || this._fieldType === 'DateTime') {
            resultClass += 'slds-p-top--large '
        }
        if (this._fieldType && !this.value) {
            resultClass += 'slds-has-error ';
        }
        return resultClass;
    }

    get preventRemoval() {
        return (this.conditionCount <= 1);
    }

    handleChildRelationshipChange(event) {
        this.selectedChildRelationship = event.detail.value;
        const selected = this.childRelationships.find(
            cr => cr.value === this.selectedChildRelationship
        );
        this.childFields = selected ? selected.fields : [];
        this.selectedChildField = null;
        this.hasChildValue = true;
        this.hasValue = true; 
    }

    dispatchConditionChangedEvent() {
        if (this.operation == 'Child') {
            const filterChildChangedEvent = new CustomEvent('conditionchanged', {
                detail: {
                    fieldName: this.fieldName,
                    dataType: this._fieldType,
                    objectType: this._objectType,
                    operation: this.operation,
                    childRelationship: this.selectedChildRelationship,
                    childField: this.selectedChildField,
                    value: this.value,
                    id: this.lineId
                }
            });
            this.dispatchEvent(filterChildChangedEvent);
        }
        else {
            const filterChangedEvent = new CustomEvent('conditionchanged', {
                detail: {
                    fieldName: this.fieldName,
                    dataType: this._fieldType,
                    objectType: this._objectType,
                    operation: this.operation,
                    value: this.value,
                    id: this.lineId
                }
            });
            this.dispatchEvent(filterChangedEvent);
        }
        
    }
}