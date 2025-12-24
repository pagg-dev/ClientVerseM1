import { LightningElement, track } from "lwc";
import Toast from "lightning/toast";
import resolveShareAccess from "@salesforce/apex/SharedListViewerController.resolveShareAccess";
import submitListChanges from "@salesforce/apex/SharedListViewerController.submitListChanges";

export default class SharedListViewer extends LightningElement {
	token;
	listName = "";
	access = "";
	listId = "";
	shareId = "";

	@track members = [];
	originalMembers = []; // snapshot to revert changes
	@track searchTerm = "";

	addModalOpen = false;

	// pending selections from list builder (array of contact-like objects)
	pendingSelectedContacts = [];

	isSubmitting = false;

	statusOptions = [
		{ label: "Included", value: "Included" },
		{ label: "Excluded", value: "Excluded" }
	];

	// permission flags (derived after load)
	canAdd = false;
	canRemove = false;
	canEditNotes = false;
	canSubmit = false;
	isReadOnly = false;

	get canAddMemberButtonDisabled() {
		return !this.canAdd || this.isReadOnly;
	}

	get canSubmitButtonDisabled() {
		return !this.canSubmit || this.isReadOnly || this.isSubmitting;
	}

	get editNotesInputDisabled() {
		return !this.canEditNotes || this.isReadOnly;
	}

	get removeMembersDisabled() {
		return !this.canRemove || this.isReadOnly;
	}

	// disable modal Add Members button when read-only or no pending selection
	get addMembersButtonDisabled() {
		return (
			this.isReadOnly ||
			!this.pendingSelectedContacts ||
			this.pendingSelectedContacts.length === 0
		);
	}

	connectedCallback() {
		const params = new URLSearchParams(window.location.search);
		this.token = params.get("token");
		if (!this.token) {
			this.showToast("Error", "Missing token in URL", "error");
			return;
		}
		this.loadData();
	}

	async loadData() {
		try {
			const r = await resolveShareAccess({ token: this.token });

			this.listName = r.listName;
			this.access = r.access;
			this.listId = r.listId;
			this.shareId = r.shareId;

			this.members = (r.members || []).map((m) => ({
				...m,
				isNew: false,
				markedForRemoval: false,
				nameClass: "name"
			}));

			// keep a deep copy for cancel
			this.originalMembers = JSON.parse(JSON.stringify(this.members));

			// derive permission flags from access string
			this.applyPermissions(this.access);
		} catch (err) {
			console.error(err);
			const errMsg = err && err.body && err.body.message ? "Failed to load data. " + err.body.message : "Failed to load data";
			this.showToast("Error", errMsg, "error");
		}
	}

	applyPermissions(accessLabel) {
		const a = (accessLabel || "").trim();

		this.canAdd = false;
		this.canRemove = false;
		this.canEditNotes = false;
		this.canSubmit = false;
		this.isReadOnly = false;

		if (!a) {
			this.isReadOnly = true;
			return;
		}

		if (a === "View") {
			this.isReadOnly = true;
		} else if (a === "Add Members") {
			this.canAdd = true;
			this.canEditNotes = true;
			this.canSubmit = true;
		} else if (a === "Remove Members") {
			this.canRemove = true;
			this.canEditNotes = true;
			this.canSubmit = true;
		} else if (a === "All" || a === "Approved Reviewer") {
			this.canAdd = true;
			this.canRemove = true;
			this.canEditNotes = true;
			this.canSubmit = true;
		} else {
			this.isReadOnly = true;
		}
	}

	/* ----------------------- SEARCH ------------------------ */

	get filteredMembers() {
		if (!this.searchTerm) return this.members;
		const s = this.searchTerm.toLowerCase();
		return this.members.filter((m) =>
			(m.displayName || "").toLowerCase().includes(s)
		);
	}

	get noRows() {
		return this.filteredMembers.length === 0;
	}

	handleSearchChange(event) {
		this.searchTerm = event.target.value;
	}

	/* ----------------------- NOTE + REASON ------------------------ */

	handleNoteChange(event) {
		if (!this.canEditNotes || this.isReadOnly) {
			this.showToast("Error", "You do not have permission to edit notes", "error");
			const rowId = event.target.dataset.rowid;
			const m = this.members.find((x) => x.id === rowId);
			if (m) {
				event.target.value = m.note || "";
			}
			return;
		}

		const rowId = event.target.dataset.rowid;
		const value = event.target.value;
		this.updateRow(rowId, { note: value });
	}

	handleReasonChange(event) {
		if (!this.canEditNotes || this.isReadOnly) {
			this.showToast(
				"Error",
				"You do not have permission to provide reason",
				"error"
			);
			const rowId = event.target.dataset.rowid;
			const m = this.members.find((x) => x.id === rowId);
			if (m) {
				event.target.value = m.reason || "";
			}
			return;
		}

		const rowId = event.target.dataset.rowid;
		const value = event.target.value;
		this.updateRow(rowId, { reason: value });
	}

	/* ----------------------- ACTIONS ------------------------ */

	handleMarkRemoveClick(event) {
		if (!this.canRemove || this.isReadOnly) {
			this.showToast(
				"Error",
				"You do not have permission to remove members",
				"error"
			);
			return;
		}

		const rowId = event.currentTarget.dataset.rowid;
		this.updateRow(rowId, {
			markedForRemoval: true,
			nameClass: "wrap-text name name-removed"
		});
	}

	handleUndoClick(event) {
		const rowId = event.currentTarget.dataset.rowid;
		this.updateRow(rowId, {
			markedForRemoval: false,
			reason: "",
			nameClass: this.members.find((m) => m.id === rowId)?.isNew
				? "wrap-text name name-added"
				: "wrap-text name"
		});
	}

	handleDeleteNewClick(event) {
		if (this.isReadOnly) {
			this.showToast(
				"Error",
				"You do not have permission to remove members",
				"error"
			);
			return;
		}
		const rowId = event.currentTarget.dataset.rowid;
		this.members = this.members.filter((m) => m.id !== rowId);
	}

	updateRow(rowId, fields) {
		this.members = this.members.map((m) =>
			m.id === rowId ? { ...m, ...fields } : m
		);
	}

	/* ----------------------- ADD MEMBER MODAL ------------------------ */

	openAddModal() {
		if (!this.canAdd || this.isReadOnly) {
			this.showToast("Error", "You do not have permission to add members", "error");
			return;
		}
		this.addModalOpen = true;
		this.pendingSelectedContacts = [];
	}

	closeAddModal() {
		this.addModalOpen = false;
		this.pendingSelectedContacts = [];
	}

	handleAddMembers(event) {
		const selected = (event.detail && event.detail.selectedContacts) || [];
		this.pendingSelectedContacts = Array.isArray(selected) ? selected : [];
	}

	confirmAddSelected() {
		if (!this.canAdd || this.isReadOnly) {
			this.showToast("Error", "You do not have permission to add members", "error");
			return;
		}

		const selected = this.pendingSelectedContacts || [];
		if (!selected.length) {
			this.showToast("Info", "No contacts selected", "info");
			return;
		}

		let added = 0;
		let skipped = 0;
		const existingContactIds = new Set(
			this.members.map((m) => m.contactId).filter(Boolean)
		);

		const newRows = selected.reduce((acc, c, idx) => {
			const contactId = c.Id || c.id || c.contactId || null;
			if (!contactId) {
				skipped++;
				return acc;
			}

			// skip duplicates
			if (existingContactIds.has(contactId)) {
				skipped++;
				return acc;
			}

			const displayName =
				c.Name ||
				(Array.isArray(c.displayFields) &&
					c.displayFields.length &&
					(c.displayFields[0].value ||
						c.displayFields.find((f) => f.key === "Name")?.value)) ||
				"New Contact";

			const row = {
				id: `new-${Date.now()}-${idx}`,
				contactId: contactId,
				displayName: displayName,
				status: "Included",
				isNew: true,
				markedForRemoval: false,
				note: "",
				reason: "",
				nameClass: "wrap-text name name-added",
				title: "",
				company: "",
				initialSponsor: ""
			};

			existingContactIds.add(contactId);
			acc.push(row);
			added++;
			return acc;
		}, []);

		if (newRows.length) {
			this.members = [...newRows, ...this.members];
			this.showToast(
				"Success",
				`${added} member(s) added. ${skipped ? skipped + " skipped" : ""}`,
				"success"
			);
		} else {
			this.showToast(
				"Info",
				`No new members to add. ${skipped ? skipped + " skipped" : ""}`,
				"info"
			);
		}

		this.pendingSelectedContacts = [];
		this.closeAddModal();
	}

	/* ----------------------- SUBMIT & CANCEL ------------------------ */

	async submitChanges() {
		if (!this.listId) {
			this.showToast("Error", "List not loaded", "error");
			return;
		}

		if (!this.canSubmit || this.isReadOnly) {
			this.showToast(
				"Error",
				"You do not have permission to submit changes",
				"error"
			);
			return;
		}

		const changes = this.members.map((m) => ({
			id: m.id,
			contactId: m.contactId,
			isNew: m.isNew,
			markedForRemoval: m.markedForRemoval,
			note: m.note,
			reason: m.reason,
			status: m.status
		}));

		this.isSubmitting = true;
		try {
			await submitListChanges({
				listId: this.listId,
				shareId: this.shareId,
				changesJson: JSON.stringify(changes)
			});

			this.showToast("Success", "Changes submitted successfully", "success");
			this.originalMembers = JSON.parse(JSON.stringify(this.members));
		} catch (err) {
			console.error(err);
			const msg =
				err && err.body && err.body.message
					? err.body.message
					: "Failed to submit changes";
			this.showToast("Error", msg, "error");
		} finally {
			this.isSubmitting = false;
		}
	}

	cancelChanges() {
		// revert to originalMembers
		this.members = JSON.parse(JSON.stringify(this.originalMembers || []));
		this.showToast("Info", "Changes have been reverted", "info");
	}

	showToast(title, message, variant = "info", mode = "dismissible") {
		const cfg = {
			label: title,
			message: message,
			variant: variant,
			mode: mode
		};
		Toast.show(cfg, this);
	}
}