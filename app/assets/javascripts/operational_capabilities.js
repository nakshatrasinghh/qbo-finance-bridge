document.addEventListener("DOMContentLoaded", () => {
  const dashboard = document.querySelector("[data-operational-capabilities]")
  if (!dashboard) return

  const urls = {
    employees: dashboard.dataset.employeesUrl,
    timeActivities: dashboard.dataset.timeActivitiesUrl,
    taxCodes: dashboard.dataset.taxCodesUrl,
    inventoryItems: dashboard.dataset.inventoryItemsUrl
  }
  const status = document.querySelector("#operations-api-status")
  const alert = document.querySelector("#operations-api-alert")
  const alertTitle = document.querySelector("#operations-api-alert-title")
  const alertMessage = document.querySelector("#operations-api-alert-message")
  const employeeForm = document.querySelector("[data-employee-create-form]")
  const timeActivityForm = document.querySelector("[data-time-activity-create-form]")
  const taxCodeForm = document.querySelector("[data-tax-code-create-form]")
  const inventoryItemForm = document.querySelector("[data-inventory-item-create-form]")
  const forms = [employeeForm, timeActivityForm, taxCodeForm, inventoryItemForm]
  const keys = new WeakMap()
  const state = {
    employees: [],
    timeActivities: [],
    taxCodes: [],
    taxRates: [],
    taxAgencies: [],
    inventoryItems: [],
    accountChoices: { income: [], expense: [], asset: [] }
  }

  class ApiError extends Error {
    constructor(message, code, statusCode) {
      super(message)
      this.apiCode = code
      this.statusCode = statusCode
    }
  }

  const csrfToken = () => document.querySelector("meta[name='csrf-token']")?.content
  const nextIdempotencyKey = () => window.crypto.randomUUID()
  const idempotencyKey = (form) => {
    if (!keys.has(form)) keys.set(form, nextIdempotencyKey())
    return keys.get(form)
  }
  const resetIdempotencyKey = (form) => keys.set(form, nextIdempotencyKey())

  const apiRequest = async (url, options = {}) => {
    const headers = { Accept: "application/json", ...options.headers }
    const token = csrfToken()
    if (token && options.method && options.method !== "GET") headers["X-CSRF-Token"] = token

    const response = await fetch(url, { ...options, headers, credentials: "same-origin" }).catch(() => {
      throw new ApiError("Rails could not be reached. Confirm the local server is running.", "network_error", 0)
    })
    const data = await response.json().catch(() => ({}))
    if (!response.ok) {
      throw new ApiError(
        data.error?.message || `API request failed with HTTP ${response.status}.`,
        data.error?.code || "api_error",
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

  const replaceRows = (tbody, rows, colspan, emptyMessage) => {
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
    select.replaceChildren(new Option(emptyLabel, ""))
    records.forEach((record) => select.add(new Option(label(record), record.id)))
  }

  const submitButton = (form) => form.querySelector("input[type='submit'], button[type='submit']")
  const enableSubmit = (form, enabled) => {
    submitButton(form).disabled = !enabled
  }

  const renderEmployees = () => {
    replaceRows(
      document.querySelector("#employees-rows"),
      state.employees.map((employee) => [employee.id, employee.display_name, employee.email, employee.phone]),
      4,
      "No active Employees returned by QuickBooks."
    )
    document.querySelector("#employees-summary").textContent =
      `${state.employees.length} active Employee records loaded through the Rails GET API. Full payroll is unavailable.`

    const select = timeActivityForm.elements.namedItem("time_activity[employee_id]")
    populateSelect(select, state.employees, (employee) => employee.display_name, "Select an active Employee")
    enableSubmit(employeeForm, true)
    enableSubmit(timeActivityForm, state.employees.length > 0)
  }

  const renderTimeActivities = () => {
    replaceRows(
      document.querySelector("#time-activities-rows"),
      state.timeActivities.map((activity) => [
        activity.id,
        activity.txn_date,
        activity.employee_name || activity.employee_id,
        `${activity.hours}h ${activity.minutes}m`,
        activity.description
      ]),
      5,
      "No employee TimeActivities returned by QuickBooks."
    )
    document.querySelector("#time-activities-summary").textContent =
      `${state.timeActivities.length} TimeActivity records loaded through the Rails GET API.`
  }

  const renderTaxCatalog = () => {
    replaceRows(
      document.querySelector("#tax-codes-rows"),
      state.taxCodes.map((code) => [
        code.id,
        code.name,
        code.taxable ? "Yes" : "No",
        code.sales_rate_ids.join(", "),
        code.purchase_rate_ids.join(", ")
      ]),
      5,
      "No TaxCodes returned by QuickBooks."
    )
    replaceRows(
      document.querySelector("#tax-rates-rows"),
      state.taxRates.map((rate) => [rate.id, rate.name, `${rate.rate_value}%`, rate.agency_name || rate.agency_id]),
      4,
      "No TaxRates returned by QuickBooks."
    )
    document.querySelector("#tax-codes-summary").textContent =
      `${state.taxCodes.length} TaxCodes, ${state.taxRates.length} TaxRates, and ${state.taxAgencies.length} TaxAgencies loaded.`

    const activeRates = state.taxRates.filter((rate) => rate.active)
    const select = taxCodeForm.elements.namedItem("tax_code[tax_rate_id]")
    populateSelect(select, activeRates, (rate) => `${rate.name} — ${rate.rate_value}%`, "Select an existing TaxRate")
    enableSubmit(taxCodeForm, activeRates.length > 0)
  }

  const renderInventoryCatalog = () => {
    replaceRows(
      document.querySelector("#inventory-items-rows"),
      state.inventoryItems.map((item) => [
        item.id,
        item.name,
        item.sku,
        item.quantity_on_hand,
        item.purchase_cost,
        item.unit_price
      ]),
      6,
      "No Inventory Items returned by QuickBooks."
    )
    document.querySelector("#inventory-items-summary").textContent =
      `${state.inventoryItems.length} Inventory Items loaded through the Rails GET API.`

    const mappings = [
      ["inventory_item[income_account_id]", state.accountChoices.income, "Select sales income Account"],
      ["inventory_item[expense_account_id]", state.accountChoices.expense, "Select COGS Account"],
      ["inventory_item[asset_account_id]", state.accountChoices.asset, "Select inventory asset Account"]
    ]
    mappings.forEach(([name, records, emptyLabel]) => {
      populateSelect(inventoryItemForm.elements.namedItem(name), records, (record) => record.display_name, emptyLabel)
    })
    const ready = mappings.every(([, records]) => records.length > 0)
    enableSubmit(inventoryItemForm, ready)
  }

  const loadEmployees = async () => {
    const data = await apiRequest(urls.employees)
    state.employees = Array.isArray(data.employees) ? data.employees : []
    renderEmployees()
  }

  const loadTimeActivities = async () => {
    const data = await apiRequest(urls.timeActivities)
    state.timeActivities = Array.isArray(data.time_activities) ? data.time_activities : []
    renderTimeActivities()
  }

  const loadTaxCatalog = async () => {
    const data = await apiRequest(urls.taxCodes)
    state.taxCodes = Array.isArray(data.tax_codes) ? data.tax_codes : []
    state.taxRates = Array.isArray(data.tax_rates) ? data.tax_rates : []
    state.taxAgencies = Array.isArray(data.tax_agencies) ? data.tax_agencies : []
    renderTaxCatalog()
  }

  const loadInventoryCatalog = async () => {
    const data = await apiRequest(urls.inventoryItems)
    state.inventoryItems = Array.isArray(data.inventory_items) ? data.inventory_items : []
    state.accountChoices = data.account_choices || { income: [], expense: [], asset: [] }
    renderInventoryCatalog()
  }

  const formPayload = (form, scope, fields) => {
    const payload = {}
    fields.forEach((field) => {
      payload[field] = form.elements.namedItem(`${scope}[${field}]`).value
    })
    return { [scope]: payload }
  }

  const submitCreate = async ({form, scope, fields, confirmMessage, successLabel, refresh, localErrorCode}) => {
    if (!window.confirm(confirmMessage)) return

    clearAlert()
    enableSubmit(form, false)
    setStatus(`Submitting ${successLabel} through the Rails POST API…`)
    try {
      const data = await apiRequest(form.action, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Idempotency-Key": idempotencyKey(form) },
        body: JSON.stringify(formPayload(form, scope, fields))
      })
      resetIdempotencyKey(form)
      form.reset()
      await refresh()
      setStatus(
        `${successLabel} ${data[scope].id} was created, read back, and recorded as local operation ` +
          `${data.idempotency.operation_id}.`
      )
    } catch (error) {
      if (error.apiCode === localErrorCode || error.apiCode === "idempotency_key_invalid") {
        resetIdempotencyKey(form)
      }
      showAlert(`${successLabel} POST failed`, error)
      setStatus(`${successLabel} was not confirmed. Review the alert before retrying.`)
    } finally {
      if (scope === "employee") enableSubmit(form, true)
      if (scope === "time_activity") enableSubmit(form, state.employees.length > 0)
      if (scope === "tax_code") enableSubmit(form, state.taxRates.some((rate) => rate.active))
      if (scope === "inventory_item") {
        enableSubmit(
          form,
          state.accountChoices.income.length > 0 &&
            state.accountChoices.expense.length > 0 &&
            state.accountChoices.asset.length > 0
        )
      }
    }
  }

  document.querySelector("[data-dismiss-operations-alert]").addEventListener("click", clearAlert)

  employeeForm.addEventListener("submit", (event) => {
    event.preventDefault()
    submitCreate({
      form: employeeForm,
      scope: "employee",
      fields: ["given_name", "family_name", "email", "phone"],
      confirmMessage: "POST one real Employee record to the QuickBooks sandbox?",
      successLabel: "Employee",
      refresh: loadEmployees,
      localErrorCode: "quickbooks_employee_input_invalid"
    })
  })

  timeActivityForm.addEventListener("submit", (event) => {
    event.preventDefault()
    submitCreate({
      form: timeActivityForm,
      scope: "time_activity",
      fields: ["employee_id", "txn_date", "hours", "minutes", "description"],
      confirmMessage: "POST one real employee TimeActivity to the QuickBooks sandbox?",
      successLabel: "TimeActivity",
      refresh: loadTimeActivities,
      localErrorCode: "quickbooks_time_activity_input_invalid"
    })
  })

  taxCodeForm.addEventListener("submit", (event) => {
    event.preventDefault()
    submitCreate({
      form: taxCodeForm,
      scope: "tax_code",
      fields: ["name", "tax_rate_id", "applicable_on"],
      confirmMessage: "POST one real TaxCode using the selected QuickBooks TaxRate?",
      successLabel: "TaxCode",
      refresh: loadTaxCatalog,
      localErrorCode: "quickbooks_tax_code_input_invalid"
    })
  })

  inventoryItemForm.addEventListener("submit", (event) => {
    event.preventDefault()
    submitCreate({
      form: inventoryItemForm,
      scope: "inventory_item",
      fields: [
        "name",
        "sku",
        "description",
        "inventory_start_date",
        "quantity_on_hand",
        "unit_price",
        "purchase_cost",
        "income_account_id",
        "expense_account_id",
        "asset_account_id"
      ],
      confirmMessage:
        "POST one real Inventory Item? Positive opening quantity and cost can change QuickBooks inventory value.",
      successLabel: "Inventory Item",
      refresh: loadInventoryCatalog,
      localErrorCode: "quickbooks_inventory_item_input_invalid"
    })
  })

  forms.forEach((form) => enableSubmit(form, false))
  Promise.allSettled([loadEmployees(), loadTimeActivities(), loadTaxCatalog(), loadInventoryCatalog()]).then(
    (results) => {
      const failures = results.filter((result) => result.status === "rejected")
      if (failures.length > 0) {
        showAlert("One or more GET APIs failed", failures[0].reason)
        setStatus(`${4 - failures.length} of 4 capability GET APIs loaded. Failed sources remain unavailable.`)
        return
      }
      clearAlert()
      setStatus(
        `API ready: ${state.employees.length} Employees, ${state.timeActivities.length} TimeActivities, ` +
          `${state.taxCodes.length} TaxCodes, and ${state.inventoryItems.length} Inventory Items.`
      )
    }
  )
})
