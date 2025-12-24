import { LightningElement, track, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from "lightning/actions";
import generateToken from "@salesforce/apex/ListShareActionController.generateToken";
import revokeToken from "@salesforce/apex/ListShareActionController.revokeToken";

export default class ShareAction extends LightningElement {
	// SHARE MODE
	shareMode = "Authenticated";
	shareModeOptions = [{ label: "Authenticated User", value: "Authenticated" }];

	// generated link + id
	generatedUrl = "";
	currentListShareId = null;

	@api recordId;

	// AUTH LOOKUP
	@track selectedUserId = null;

	// ACCESS TYPE
	accessType = "View";
	accessTypeOptions = [
		{ label: "View", value: "View" },
		{ label: "Add Members", value: "Add Members" },
		{ label: "Remove Members", value: "Remove Members" },
		{ label: "All", value: "All" },
		{ label: "Approved Reviewer", value: "Approved Reviewer" }
	];

	// EXPIRY: date + time inputs
	expiryDate = null;
	expiryTime = null;

	// TOKEN TYPE
	tokenType = "Single";
	tokenTypeOptions = [
		{ label: "Single-use", value: "Single Use" },
		{ label: "Multi-use", value: "Multi Use" }
	];
	maxUses = null;

	get showAuthLookup() {
		return this.shareMode === "Authenticated";
	}

	get disableInputs() {
		return Boolean(this.generatedUrl && this.generatedUrl !== "");
	}

	get isMultiUse() {
		return this.tokenType === "Multi";
	}

	handleShareModeChange(event) {
		const mode = event.detail.value;
		if (this.shareMode !== mode) {
			this.shareMode = mode;
			this.clearSelectedUser();
			this.clearGeneratedShare();
		}
	}

	handleRecordPickerChange(event) {
		this.selectedUserId = event.detail?.recordId ?? null;
		this.clearGeneratedShare();
	}

	clearSelectedUser() {
		this.selectedUserId = null;
	}

	handleAccessTypeChange(event) {
		this.accessType = event.detail.value;
	}

	handleExpiryDateChange(event) {
		this.expiryDate = event.detail.value;
	}

	handleExpiryTimeChange(event) {
		this.expiryTime = event.detail.value;
	}

	handleTokenTypeChange(event) {
		this.tokenType = event.detail.value;
	}

	handleMaxUsesChange(event) {
		this.maxUses = event.detail.value;
	}

	// combine date + time into ISO datetime string (UTC)
	buildExpiryDateTimeIso() {
		if (!this.expiryDate) return null;

		// If user provided time, use it; otherwise default to 00:00 local
		let hour = 0,
			minute = 0;
		if (this.expiryTime) {
			const [hh, mm] = this.expiryTime.split(":");
			hour = parseInt(hh, 10);
			minute = parseInt(mm, 10);
		}

		// expiryDate is 'YYYY-MM-DD'
		const parts = this.expiryDate.split("-");
		const year = parseInt(parts[0], 10);
		const month = parseInt(parts[1], 10) - 1;
		const day = parseInt(parts[2], 10);

		// Create a local Date and convert to ISO string (UTC)
		const dt = new Date(year, month, day, hour, minute, 0, 0);
		return dt.toISOString(); // e.g. '2025-12-31T18:30:00.000Z'
	}

	handleGenerate() {
		// Validation
		if (this.showAuthLookup && !this.selectedUserId) {
			this.showToast(
				"Validation",
				"Please choose a user to share with.",
				"warning"
			);
			return;
		}

		const expiresAtIso = this.buildExpiryDateTimeIso(); // null if no expiry
		const listShare = {
			objectApiName: "View_Share_Config__c",
			Sharing_Type__c: this.shareMode,
			Shared_With__c: this.selectedUserId,
			Token_Type__c: this.tokenType,
			Access_Type__c: this.accessType,
			Expires_At__c: expiresAtIso,
			List__c: this.recordId,
			Max_Uses__c: this.maxUses
		};

		generateToken({ listShare })
			.then((res) => {
				this.generatedUrl = res.Tokenized_URL__c || "";
				this.currentListShareId = res.Id || null;
				this.showToast("Success", "Share link generated.", "success");
			})
			.catch((err) => {
				const msg = err?.body?.message || err.message || JSON.stringify(err);
				this.showToast("Error", msg, "error");
			});
	}

	get generatedUrlShort() {
		if (!this.generatedUrl) return "";
		const start = this.generatedUrl.slice(0, 32);
		const end = this.generatedUrl.slice(-12);
		return `${start}......${end}`;
	}

	copyUrl() {
		if (!this.generatedUrl) {
			this.showToast("Copy", "No URL to copy.", "info");
			return;
		}
		navigator.clipboard
			.writeText(this.generatedUrl)
			.then(() => this.showToast("Copied", "Link copied to clipboard.", "success"))
			.catch(() =>
				this.showToast("Copy failed", "Unable to copy to clipboard.", "error")
			);
	}

	revokeLink() {
		if (!this.currentListShareId) {
			this.showToast("Error", "Unable to revoke link.", "error");
			return;
		}

		revokeToken({ listShareId: this.currentListShareId })
			.then((ok) => {
				if (ok) {
					this.clearSelectedUser();
					this.clearGeneratedShare();
					this.showToast("Revoked", "Link has been revoked.", "success");
				} else {
					this.showToast("Error", "Unable to revoke link.", "error");
				}
			})
			.catch((err) => {
				const msg = err?.body?.message || err.message || JSON.stringify(err);
				this.showToast("Error", msg, "error");
			});
	}

	handleClose() {
		this.dispatchEvent(new CloseActionScreenEvent());
	}

	showToast(title, message, variant = "info") {
		this.dispatchEvent(
			new ShowToastEvent({ title, message, variant, mode: "dismissable" })
		);
	}

	clearGeneratedShare() {
		this.generatedUrl = "";
		this.currentListShareId = null;
		this.expiryDate = null;
		this.expiryTime = null;
		this.tokenType = null;
		this.accessType = "View";
	}
}