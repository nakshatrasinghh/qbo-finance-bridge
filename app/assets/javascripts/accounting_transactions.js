document.addEventListener("DOMContentLoaded", () => {
  const dashboard = document.querySelector("[data-accounting-transactions]")
  if (!dashboard) return

  const urls = {
    customers: dashboard.dataset.customersUrl,
    vendors: dashboard.dataset.vendorsUrl,
    invoices: dashboard.dataset.invoicesUrl,
    bills: dashboard.dataset.billsUrl,
    customerPayments: dashboard.dataset.customerPaymentsUrl,
    billPayments: dashboard.dataset.billPaymentsUrl
  }
  const status = document.querySelector("#transactions-api-status")
  const alert = document.querySelector("#transactions-api-alert")
  const alertTitle = document.querySelector("#transactions-api-alert-title")
  const alertMessage = document.querySelector("#transactions-api-alert-message")
  const forms = {
    customer: document.querySelector("[data-customer-create-form]"),
    vendor: document.querySelector("[data-vendor-create-form]"),
    invoice: document.querySelector("[data-invoice-create-form]"),
    bill: document.querySelector("[data-bill-create-form]"),
    customerPayment: document.querySelector("[data-customer-payment-create-form]"),
    billPayment: document.querySelector("[data-bill-payment-create-form]")
  }
  const transientGetErrorCodes = new Set(["quickbooks_timeout", "quickbooks_unavailable"])
  const state = {
    customers: [],
    vendors: [],
    invoices: [],
    bills: [],
    customerPayments: [],
    billPayments: [],
    customerChoices: [],
    vendorChoices: [],
    itemChoices: [],
    expenseAccountChoices: [],
    payableAccountChoices: [],
    openInvoiceChoices: [],
    openBillChoices: [],
    bankAccountChoices: []
  }

  class ApiError extends Error {
    constructor(message, code, statusCode) {
      super(message)
      this.apiCode = code
      this.statusCode = statusCode
    }
  }

  const csrfToken = () => document.querySelector("meta[name='csrf-token']")?.content

  const apiRequest = async (url, options = {}, retryCount = 0) => {
    const headers = { Accept: "application/json", ...options.headers }
    const token = csrfToken()
    if (token && options.method && options.method !== "GET") headers["X-CSRF-Token"] = token

    const response = await fetch(url, { ...options, headers, credentials: "same-origin" }).catch(() => {
      throw new ApiError("Rails could not be reached. Confirm the local server is running.", "network_error", 0)
    })
    const data = await response.json().catch(() => ({}))
    if (!response.ok) {
      const code = data.error?.code || "api_error"
      const method = (options.method || "GET").toUpperCase()
      if (method === "GET" && retryCount === 0 && transientGetErrorCodes.has(code)) {
        await new Promise((resolve) => window.setTimeout(resolve, 500))
        return apiRequest(url, options, retryCount + 1)
      }

      throw new ApiError(
        data.error?.message || `API request failed with HTTP ${response.status}.`,
        code,
        response.status
      )
    }
    return data
  }

  const showAlert = (title, error) => {
    alertTitle.textContent = title
    alertMessage.textContent = `${error.message} (code: ${error.apiCode || "unknown"})`
    alert.hidden = false
    status.classList.add("api-status-error")
  }

  const clearAlert = () => {
    alert.hidden = true
    alertMessage.textContent = ""
    status.classList.remove("api-status-error")
  }

  const setStatus = (message) => {
    status.textContent = message
  }

  const text = (value, fallback = "—") => {
    const string = value == null ? "" : String(value)
    return string.length > 0 ? string : fallback
  }

  const replaceRows = (selector, rows, colspan, emptyMessage) => {
    const tbody = document.querySelector(selector)
    tbody.replaceChildren()
    if (rows.length === 0) {
      const row = document.createElement("tr")
      const cell = document.createElement("td")
      cell.colSpan = colspan
      cell.textContent = emptyMessage
      row.append(cell)
      tbody.append(row)
      return
    }

    rows.forEach((cells) => {
      const row = document.createElement("tr")
      cells.forEach((value) => {
        const cell = document.createElement("td")
        cell.textContent = text(value)
        row.append(cell)
      })
      tbody.append(row)
    })
  }

  const populateSelect = (select, records, label, emptyLabel) => {
    const selected = select.value
    select.replaceChildren(new Option(emptyLabel, ""))
    records.forEach((record) => select.add(new Option(label(record), record.id)))
    if (records.some((record) => String(record.id) === selected)) select.value = selected
  }

  const submitButton = (form) => form.querySelector("input[type='submit'], button[type='submit']")
  const enableSubmit = (form, enabled) => {
    submitButton(form).disabled = !enabled
  }

  const customerName = (record) => record.customer_name || record.customer_id
  const vendorName = (record) => record.vendor_name || record.vendor_id
  const documentNumber = (record, fallback) => record.doc_number || `${fallback} ID ${record.id}`
  const invoiceLines = (invoice) => invoice.lines
    .map((line) => `${line.item_name || line.item_id}: ${line.amount}`)
    .join("; ")
  const billLines = (bill) => bill.lines
    .map((line) => `${line.account_name || line.account_id}: ${line.amount}`)
    .join("; ")

  const renderCustomers = () => {
    replaceRows(
      "#customers-rows",
      state.customers.map((customer) => [
        customer.id,
        customer.display_name,
        customer.company_name,
        customer.email,
        customer.phone,
        customer.balance
      ]),
      6,
      "No active Customers returned by QuickBooks."
    )
    document.querySelector("#customers-summary").textContent =
      `${state.customers.length} active Customers loaded through the Rails GET API.`
    enableSubmit(forms.customer, true)
  }

  const renderVendors = () => {
    replaceRows(
      "#vendors-rows",
      state.vendors.map((vendor) => [
        vendor.id,
        vendor.display_name,
        vendor.company_name,
        vendor.email,
        vendor.phone,
        vendor.balance
      ]),
      6,
      "No active Vendors returned by QuickBooks."
    )
    document.querySelector("#vendors-summary").textContent =
      `${state.vendors.length} active Vendors loaded through the Rails GET API.`
    enableSubmit(forms.vendor, true)
  }

  const renderInvoices = () => {
    replaceRows(
      "#invoices-rows",
      state.invoices.map((invoice) => [
        invoice.txn_date,
        documentNumber(invoice, "Invoice"),
        customerName(invoice),
        invoice.total_amount,
        invoice.balance,
        invoiceLines(invoice)
      ]),
      6,
      "No Invoices returned by QuickBooks."
    )
    document.querySelector("#invoices-summary").textContent =
      `${state.invoices.length} Invoices loaded; ${state.invoices.filter((invoice) => Number(invoice.balance) > 0).length} have an open balance.`

    populateSelect(
      forms.invoice.elements.namedItem("invoice[customer_id]"),
      state.customerChoices,
      (customer) => customer.display_name,
      "Select an active Customer"
    )
    populateSelect(
      forms.invoice.elements.namedItem("invoice[item_id]"),
      state.itemChoices,
      (item) => `${item.name} — ${item.item_type}`,
      "Select an active product or service"
    )
    enableSubmit(forms.invoice, state.customerChoices.length > 0 && state.itemChoices.length > 0)
  }

  const renderBills = () => {
    replaceRows(
      "#bills-rows",
      state.bills.map((bill) => [
        bill.txn_date,
        documentNumber(bill, "Bill"),
        vendorName(bill),
        bill.total_amount,
        bill.balance,
        billLines(bill)
      ]),
      6,
      "No Bills returned by QuickBooks."
    )
    document.querySelector("#bills-summary").textContent =
      `${state.bills.length} Bills loaded; ${state.bills.filter((bill) => Number(bill.balance) > 0).length} have an open balance.`

    populateSelect(
      forms.bill.elements.namedItem("bill[vendor_id]"),
      state.vendorChoices,
      (vendor) => vendor.display_name,
      "Select an active Vendor"
    )
    populateSelect(
      forms.bill.elements.namedItem("bill[expense_account_id]"),
      state.expenseAccountChoices,
      (account) => account.display_name,
      "Select an expense Account"
    )
    populateSelect(
      forms.bill.elements.namedItem("bill[payable_account_id]"),
      state.payableAccountChoices,
      (account) => account.display_name,
      "Select an Accounts Payable Account"
    )
    const ready = state.vendorChoices.length > 0 && state.expenseAccountChoices.length > 0 &&
      state.payableAccountChoices.length > 0
    enableSubmit(forms.bill, ready)
  }

  const renderCustomerPayments = () => {
    replaceRows(
      "#customer-payments-rows",
      state.customerPayments.map((payment) => [
        payment.txn_date,
        payment.id,
        customerName(payment),
        payment.total_amount,
        payment.unapplied_amount,
        payment.applied_invoices.map((invoice) => `${invoice.invoice_id}: ${invoice.amount}`).join("; ")
      ]),
      6,
      "No Customer Payments returned by QuickBooks."
    )
    document.querySelector("#customer-payments-summary").textContent =
      `${state.customerPayments.length} Customer Payments and ${state.openInvoiceChoices.length} open Invoice choices loaded.`

    populateSelect(
      forms.customerPayment.elements.namedItem("customer_payment[invoice_id]"),
      state.openInvoiceChoices,
      (invoice) => `${documentNumber(invoice, "Invoice")} — ${customerName(invoice)} — balance ${invoice.balance}`,
      "Select one open Invoice"
    )
    enableSubmit(forms.customerPayment, state.openInvoiceChoices.length > 0)
  }

  const renderBillPayments = () => {
    replaceRows(
      "#bill-payments-rows",
      state.billPayments.map((payment) => [
        payment.txn_date,
        payment.id,
        vendorName(payment),
        payment.pay_type,
        payment.payment_account_name || payment.payment_account_id,
        payment.total_amount,
        payment.applied_bills.map((bill) => `${bill.bill_id}: ${bill.amount}`).join("; ")
      ]),
      7,
      "No Bill Payments returned by QuickBooks."
    )
    document.querySelector("#bill-payments-summary").textContent =
      `${state.billPayments.length} Bill Payments, ${state.openBillChoices.length} open Bills, and ` +
      `${state.bankAccountChoices.length} bank Accounts loaded.`

    populateSelect(
      forms.billPayment.elements.namedItem("bill_payment[bill_id]"),
      state.openBillChoices,
      (bill) => `${documentNumber(bill, "Bill")} — ${vendorName(bill)} — balance ${bill.balance}`,
      "Select one open Bill"
    )
    populateSelect(
      forms.billPayment.elements.namedItem("bill_payment[bank_account_id]"),
      state.bankAccountChoices,
      (account) => account.display_name,
      "Select one active bank Account"
    )
    enableSubmit(forms.billPayment, state.openBillChoices.length > 0 && state.bankAccountChoices.length > 0)
  }

  const loadCustomers = async () => {
    const data = await apiRequest(urls.customers)
    state.customers = Array.isArray(data.customers) ? data.customers : []
    renderCustomers()
  }

  const loadVendors = async () => {
    const data = await apiRequest(urls.vendors)
    state.vendors = Array.isArray(data.vendors) ? data.vendors : []
    renderVendors()
  }

  const loadInvoices = async () => {
    const data = await apiRequest(urls.invoices)
    state.invoices = Array.isArray(data.invoices) ? data.invoices : []
    state.customerChoices = Array.isArray(data.customer_choices) ? data.customer_choices : []
    state.itemChoices = Array.isArray(data.item_choices) ? data.item_choices : []
    renderInvoices()
  }

  const loadBills = async () => {
    const data = await apiRequest(urls.bills)
    state.bills = Array.isArray(data.bills) ? data.bills : []
    state.vendorChoices = Array.isArray(data.vendor_choices) ? data.vendor_choices : []
    state.expenseAccountChoices = Array.isArray(data.account_choices?.expense) ? data.account_choices.expense : []
    state.payableAccountChoices = Array.isArray(data.account_choices?.payable) ? data.account_choices.payable : []
    renderBills()
  }

  const loadCustomerPayments = async () => {
    const data = await apiRequest(urls.customerPayments)
    state.customerPayments = Array.isArray(data.customer_payments) ? data.customer_payments : []
    state.openInvoiceChoices = Array.isArray(data.open_invoice_choices) ? data.open_invoice_choices : []
    renderCustomerPayments()
  }

  const loadBillPayments = async () => {
    const data = await apiRequest(urls.billPayments)
    state.billPayments = Array.isArray(data.bill_payments) ? data.bill_payments : []
    state.openBillChoices = Array.isArray(data.open_bill_choices) ? data.open_bill_choices : []
    state.bankAccountChoices = Array.isArray(data.bank_account_choices) ? data.bank_account_choices : []
    renderBillPayments()
  }

  const formPayload = (form, scope, fields) => {
    const payload = {}
    fields.forEach((field) => {
      payload[field] = form.elements.namedItem(`${scope}[${field}]`).value
    })
    return { [scope]: payload }
  }

  const submitCreate = async (settings) => {
    const { form, scope, responseKey, fields, confirmMessage, successLabel, refresh, ready } = settings
    if (!window.confirm(confirmMessage)) return

    clearAlert()
    enableSubmit(form, false)
    setStatus(`Submitting ${successLabel} through the Rails POST API…`)
    let data
    let postError
    try {
      data = await apiRequest(form.action, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(formPayload(form, scope, fields))
      })
      form.reset()
    } catch (error) {
      postError = error
    }

    const refreshResult = await Promise.allSettled([refresh()]).then(([result]) => result)
    if (postError) {
      const refreshMessage = refreshResult.status === "fulfilled" ?
        "The related GET APIs were refreshed." :
        `The related GET refresh also failed: ${refreshResult.reason.message}`
      showAlert(
        `${successLabel} POST failed`,
        new ApiError(
          `${postError.message} ${refreshMessage} Check QuickBooks before repeating the POST because a repeated ` +
            "execution may create another record.",
          postError.apiCode,
          postError.statusCode
        )
      )
      setStatus(`${successLabel} was not confirmed; its related GET APIs were attempted.`)
    } else if (refreshResult.status === "rejected") {
      showAlert(
        `${successLabel} was created, but refresh failed`,
        new ApiError(refreshResult.reason.message, refreshResult.reason.apiCode, refreshResult.reason.statusCode)
      )
      setStatus(`${successLabel} ${data[responseKey].id} is confirmed; its related GET refresh failed.`)
    } else {
      setStatus(
        `${successLabel} ${data[responseKey].id} was created and verified by QuickBooks readback. ` +
        "Its related GET APIs were refreshed."
      )
    }

    enableSubmit(form, ready())
  }

  document.querySelector("[data-dismiss-transactions-alert]").addEventListener("click", clearAlert)

  forms.customer.addEventListener("submit", (event) => {
    event.preventDefault()
    submitCreate({
      form: forms.customer,
      scope: "customer",
      responseKey: "customer",
      fields: ["display_name", "company_name", "email", "phone"],
      confirmMessage: "POST one real Customer list record to the QuickBooks sandbox?",
      successLabel: "Customer",
      refresh: () => Promise.all([loadCustomers(), loadInvoices()]),
      ready: () => true
    })
  })

  forms.vendor.addEventListener("submit", (event) => {
    event.preventDefault()
    submitCreate({
      form: forms.vendor,
      scope: "vendor",
      responseKey: "vendor",
      fields: ["display_name", "company_name", "email", "phone"],
      confirmMessage: "POST one real Vendor list record to the QuickBooks sandbox?",
      successLabel: "Vendor",
      refresh: () => Promise.all([loadVendors(), loadBills()]),
      ready: () => true
    })
  })

  forms.invoice.addEventListener("submit", (event) => {
    event.preventDefault()
    submitCreate({
      form: forms.invoice,
      scope: "invoice",
      responseKey: "invoice",
      fields: ["customer_id", "item_id", "txn_date", "due_date", "amount", "description"],
      confirmMessage: "POST one real Invoice? This changes sandbox receivable and sales balances.",
      successLabel: "Invoice",
      refresh: () => Promise.all([loadInvoices(), loadCustomerPayments()]),
      ready: () => state.customerChoices.length > 0 && state.itemChoices.length > 0
    })
  })

  forms.bill.addEventListener("submit", (event) => {
    event.preventDefault()
    submitCreate({
      form: forms.bill,
      scope: "bill",
      responseKey: "bill",
      fields: ["vendor_id", "expense_account_id", "payable_account_id", "txn_date", "due_date", "amount", "description"],
      confirmMessage: "POST one real Bill? This changes sandbox payable and expense balances.",
      successLabel: "Bill",
      refresh: () => Promise.all([loadBills(), loadBillPayments()]),
      ready: () => state.vendorChoices.length > 0 && state.expenseAccountChoices.length > 0 &&
        state.payableAccountChoices.length > 0
    })
  })

  forms.customerPayment.addEventListener("submit", (event) => {
    event.preventDefault()
    submitCreate({
      form: forms.customerPayment,
      scope: "customer_payment",
      responseKey: "customer_payment",
      fields: ["invoice_id", "txn_date", "amount"],
      confirmMessage: "POST one real Payment and apply it to the selected open Invoice?",
      successLabel: "Customer Payment",
      refresh: () => Promise.all([loadCustomerPayments(), loadInvoices()]),
      ready: () => state.openInvoiceChoices.length > 0
    })
  })

  forms.billPayment.addEventListener("submit", (event) => {
    event.preventDefault()
    submitCreate({
      form: forms.billPayment,
      scope: "bill_payment",
      responseKey: "bill_payment",
      fields: ["bill_id", "bank_account_id", "txn_date", "amount"],
      confirmMessage: "POST one real check-style BillPayment from the selected bank Account?",
      successLabel: "Bill Payment",
      refresh: () => Promise.all([loadBillPayments(), loadBills()]),
      ready: () => state.openBillChoices.length > 0 && state.bankAccountChoices.length > 0
    })
  })

  Object.values(forms).forEach((form) => enableSubmit(form, false))
  Promise.allSettled([
    loadCustomers(),
    loadVendors(),
    loadInvoices(),
    loadBills(),
    loadCustomerPayments(),
    loadBillPayments()
  ]).then((results) => {
    const failures = results.filter((result) => result.status === "rejected")
    if (failures.length > 0) {
      showAlert("One or more GET APIs failed", failures[0].reason)
      setStatus(`${6 - failures.length} of 6 sales and payables GET APIs loaded.`)
      return
    }

    clearAlert()
    setStatus(
      `API ready: ${state.customers.length} Customers, ${state.vendors.length} Vendors, ` +
      `${state.invoices.length} Invoices, ${state.bills.length} Bills, ` +
      `${state.customerPayments.length} Customer Payments, and ${state.billPayments.length} Bill Payments.`
    )
  })
})
