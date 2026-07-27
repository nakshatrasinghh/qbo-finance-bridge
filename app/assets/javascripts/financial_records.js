document.addEventListener("DOMContentLoaded", () => {
  const dashboard = document.querySelector("[data-financial-records-dashboard]")
  if (!dashboard) return

  const accountsUrl = dashboard.dataset.accountsUrl
  const journalEntriesUrl = dashboard.dataset.journalEntriesUrl
  const auditHistoryUrl = dashboard.dataset.auditHistoryUrl
  const financialReportUrls = {
    profit_and_loss: dashboard.dataset.profitAndLossUrl,
    balance_sheet: dashboard.dataset.balanceSheetUrl,
    cash_flow: dashboard.dataset.cashFlowUrl,
    general_ledger: dashboard.dataset.generalLedgerUrl,
    trial_balance: dashboard.dataset.trialBalanceUrl
  }
  const form = dashboard.querySelector("[data-journal-entry-form]")
  const submitButton = form.querySelector("input[type='submit']")
  const debitSelect = form.querySelector("[name='journal_entry[debit_account_id]']")
  const creditSelect = form.querySelector("[name='journal_entry[credit_account_id]']")
  const alertBanner = document.querySelector("#api-alert")
  const alertTitle = document.querySelector("#api-alert-title")
  const alertMessage = document.querySelector("#api-alert-message")
  const dismissAlertButton = dashboard.querySelector("[data-dismiss-api-alert]")
  const status = document.querySelector("#api-status")
  const recordsSummary = document.querySelector("#records-summary")
  const recordRows = document.querySelector("#journal-entry-rows")
  const auditSummary = document.querySelector("#audit-summary")
  const auditRows = document.querySelector("#audit-operation-rows")
  const filterForm = dashboard.querySelector("[data-finance-filter-form]")
  const dateFromFilter = dashboard.querySelector("[data-filter-date-from]")
  const dateToFilter = dashboard.querySelector("[data-filter-date-to]")
  const memoFilter = dashboard.querySelector("[data-filter-memo]")
  const auditStatusFilter = dashboard.querySelector("[data-filter-audit-status]")
  const clearFiltersButton = dashboard.querySelector("[data-clear-filters]")
  const exportJournalEntriesButton = dashboard.querySelector("[data-export-journal-entries]")
  const exportAuditHistoryButton = dashboard.querySelector("[data-export-audit-history]")
  const loadMoreJournalEntriesButton = dashboard.querySelector("[data-load-more-journal-entries]")
  const loadMoreAuditButton = dashboard.querySelector("[data-load-more-audit]")
  const financialReportForm = dashboard.querySelector("[data-financial-report-form]")
  const financialReportType = dashboard.querySelector("[data-financial-report-type]")
  const financialReportStartDate = dashboard.querySelector("[data-financial-report-start-date]")
  const financialReportEndDate = dashboard.querySelector("[data-financial-report-end-date]")
  const financialReportAsOfDate = dashboard.querySelector("[data-financial-report-as-of-date]")
  const financialReportBasis = dashboard.querySelector("[data-financial-report-basis]")
  const financialReportBasisField = dashboard.querySelector("[data-report-basis-field]")
  const financialReportCashFlowBasisNote = dashboard.querySelector("[data-report-cash-flow-basis-note]")
  const financialReportPeriodFields = dashboard.querySelectorAll("[data-report-period-field]")
  const financialReportAsOfField = dashboard.querySelector("[data-report-as-of-field]")
  const loadFinancialReportButton = dashboard.querySelector("[data-load-financial-report]")
  const exportFinancialReportButton = dashboard.querySelector("[data-export-financial-report]")
  const financialReportSummary = document.querySelector("#financial-report-summary")
  const financialReportColumns = document.querySelector("#financial-report-columns")
  const financialReportRows = document.querySelector("#financial-report-rows")
  const financialReportMetadata = dashboard.querySelector("[data-financial-report-metadata]")
  const financialReportTitle = dashboard.querySelector("[data-report-title]")
  const financialReportBasisValue = dashboard.querySelector("[data-report-basis]")
  const financialReportPeriod = dashboard.querySelector("[data-report-period]")
  const financialReportCurrency = dashboard.querySelector("[data-report-currency]")
  const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
  const currency = new Intl.NumberFormat(undefined, { style: "currency", currency: "USD" })
  const nextIdempotencyKey = () => window.crypto.randomUUID()
  const readPageSize = 25
  const transientGetErrorCodes = new Set(["quickbooks_timeout", "quickbooks_unavailable"])
  const renewableIdempotencyErrorCodes = new Set([
    "idempotency_key_invalid",
    "idempotency_key_reused",
    "idempotency_request_rejected"
  ])

  let idempotencyKey = nextIdempotencyKey()
  let journalEntries = []
  let auditOperations = []
  let visibleJournalEntries = []
  let visibleAuditOperations = []
  let journalEntriesLoaded = false
  let auditHistoryLoaded = false
  let journalPagination = null
  let auditPagination = null
  let appliedFilters = { dateFrom: "", dateTo: "", memo: "", auditStatus: "" }
  let currentFinancialReport = null

  const setStatus = (message, isError = false) => {
    status.textContent = message
    status.classList.toggle("api-status-error", isError)
  }

  const showApiAlert = (title, message) => {
    alertTitle.textContent = title
    alertMessage.textContent = message
    alertBanner.hidden = false
  }

  const clearApiAlert = () => {
    alertBanner.hidden = true
    alertTitle.textContent = "API request failed"
    alertMessage.textContent = ""
  }

  dismissAlertButton.addEventListener("click", clearApiAlert)

  const apiRequest = async (url, options = {}, retryCount = 0) => {
    const headers = { Accept: "application/json", ...options.headers }
    if (csrfToken) headers["X-CSRF-Token"] = csrfToken

    const response = await fetch(url, { ...options, headers, credentials: "same-origin" }).catch(() => {
      throw new Error("The Rails API could not be reached.")
    })

    const data = await response.json().catch(() => ({}))
    if (!response.ok) {
      const code = data.error?.code || "api_error"
      const method = (options.method || "GET").toUpperCase()
      if (method === "GET" && retryCount === 0 && transientGetErrorCodes.has(code)) {
        await new Promise((resolve) => window.setTimeout(resolve, 500))
        return apiRequest(url, options, retryCount + 1)
      }

      const error = new Error(data.error?.message || `API request failed with HTTP ${response.status}.`)
      error.apiCode = code
      error.httpStatus = response.status
      throw error
    }

    return data
  }

  const addAccountOptions = (select, accounts) => {
    select.replaceChildren()
    const prompt = document.createElement("option")
    prompt.value = ""
    prompt.textContent = "Select an account"
    select.appendChild(prompt)

    accounts.forEach((account) => {
      const option = document.createElement("option")
      option.value = account.id
      option.textContent = `${account.display_name} — ${account.account_type}`
      select.appendChild(option)
    })
  }

  const markAccountsUnavailable = () => {
    [debitSelect, creditSelect].forEach((select) => {
      select.replaceChildren()
      const option = document.createElement("option")
      option.value = ""
      option.textContent = "Accounts API unavailable"
      select.appendChild(option)
    })
    submitButton.disabled = true
  }

  const markJournalEntriesUnavailable = () => {
    journalEntriesLoaded = false
    journalEntries = []
    visibleJournalEntries = []
    journalPagination = null
    exportJournalEntriesButton.disabled = true
    loadMoreJournalEntriesButton.hidden = true
    const row = document.createElement("tr")
    const cell = document.createElement("td")
    cell.colSpan = 4
    cell.textContent = "Journal Entries API unavailable."
    row.appendChild(cell)
    recordRows.replaceChildren(row)
    recordsSummary.textContent = "Journal Entries could not be loaded."
  }

  const markAuditHistoryUnavailable = () => {
    auditHistoryLoaded = false
    auditOperations = []
    visibleAuditOperations = []
    auditPagination = null
    exportAuditHistoryButton.disabled = true
    loadMoreAuditButton.hidden = true
    const row = document.createElement("tr")
    const cell = document.createElement("td")
    cell.colSpan = 7
    cell.textContent = "Audit history API unavailable."
    row.appendChild(cell)
    auditRows.replaceChildren(row)
    auditSummary.textContent = "Submission audit history could not be loaded."
  }

  const markFinancialReportUnavailable = () => {
    currentFinancialReport = null
    exportFinancialReportButton.disabled = true
    financialReportMetadata.hidden = true

    const heading = document.createElement("th")
    heading.scope = "col"
    heading.textContent = "Financial report unavailable"
    financialReportColumns.replaceChildren(heading)

    const row = document.createElement("tr")
    const cell = document.createElement("td")
    cell.textContent = "The selected QuickBooks financial report could not be loaded."
    row.appendChild(cell)
    financialReportRows.replaceChildren(row)
    financialReportSummary.textContent = "Financial statement data is unavailable."
  }

  const selectedFinancialReportName = () => {
    return financialReportType.options[financialReportType.selectedIndex].text
  }

  const syncFinancialReportDateFields = () => {
    const balanceSheetSelected = financialReportType.value === "balance_sheet"
    const cashFlowSelected = financialReportType.value === "cash_flow"
    financialReportPeriodFields.forEach((field) => { field.hidden = balanceSheetSelected })
    financialReportAsOfField.hidden = !balanceSheetSelected
    financialReportBasisField.hidden = cashFlowSelected
    financialReportCashFlowBasisNote.hidden = !cashFlowSelected
    financialReportBasis.disabled = cashFlowSelected
    financialReportStartDate.required = !balanceSheetSelected
    financialReportEndDate.required = !balanceSheetSelected
    financialReportAsOfDate.required = balanceSheetSelected
    financialReportEndDate.setCustomValidity("")
  }

  const financialReportDateRangeIsValid = () => {
    if (financialReportType.value === "balance_sheet") return true

    const invalid = financialReportStartDate.value && financialReportEndDate.value &&
      financialReportStartDate.value >= financialReportEndDate.value
    financialReportEndDate.setCustomValidity(invalid ? "End date must be after start date." : "")
    return !invalid
  }

  const financialReportRequestUrl = () => {
    const url = new URL(financialReportUrls[financialReportType.value], window.location.origin)
    if (financialReportType.value !== "cash_flow") {
      url.searchParams.set("accounting_method", financialReportBasis.value)
    }

    if (financialReportType.value === "balance_sheet") {
      url.searchParams.set("as_of_date", financialReportAsOfDate.value)
    } else {
      url.searchParams.set("start_date", financialReportStartDate.value)
      url.searchParams.set("end_date", financialReportEndDate.value)
    }

    return url
  }

  const reportPeriodLabel = (report) => {
    if (report.type === "balance_sheet") return `As of ${report.end_date || "the selected date"}`

    return `${report.start_date || "—"} to ${report.end_date || "—"}`
  }

  const renderFinancialReport = (report) => {
    financialReportColumns.replaceChildren()
    report.columns.forEach((column) => {
      const heading = document.createElement("th")
      heading.scope = "col"
      heading.textContent = column.title || column.type
      if (column.type === "Money") heading.classList.add("financial-report-money")
      financialReportColumns.appendChild(heading)
    })

    financialReportRows.replaceChildren()
    if (report.rows.length === 0) {
      const row = document.createElement("tr")
      const cell = document.createElement("td")
      cell.colSpan = report.columns.length
      cell.textContent = "QuickBooks returned no rows for this financial statement."
      row.appendChild(cell)
      financialReportRows.appendChild(row)
    } else {
      report.rows.forEach((reportRow) => {
        const row = document.createElement("tr")
        row.className = `financial-report-${reportRow.kind}`

        reportRow.cells.forEach((cellData, index) => {
          const cell = document.createElement("td")
          cell.textContent = cellData.value || "—"
          if (index === 0) {
            cell.classList.add("financial-report-label")
            cell.style.setProperty("--report-depth", String(reportRow.depth))
          }
          if (report.columns[index].type === "Money") cell.classList.add("financial-report-money")
          row.appendChild(cell)
        })

        financialReportRows.appendChild(row)
      })
    }

    financialReportTitle.textContent = report.title
    financialReportBasisValue.textContent = report.basis || "Not provided by QuickBooks"
    financialReportPeriod.textContent = reportPeriodLabel(report)
    financialReportCurrency.textContent = report.currency
    financialReportMetadata.hidden = false
    exportFinancialReportButton.disabled = report.no_data || report.rows.length === 0

    const generatedAt = new Date(report.generated_at).toLocaleString()
    const dataStatement = report.no_data ? " QuickBooks marked this result as having no report data." : ""
    financialReportSummary.textContent =
      `${report.title} loaded through its Rails GET API with ${report.rows.length} report ` +
      `${report.rows.length === 1 ? "row" : "rows"}. Generated by QuickBooks at ${generatedAt}.${dataStatement}`
  }

  const loadFinancialReport = async () => {
    const data = await apiRequest(financialReportRequestUrl())
    currentFinancialReport = data.report
    renderFinancialReport(currentFinancialReport)
    return currentFinancialReport
  }

  const loadAccounts = async () => {
    const data = await apiRequest(accountsUrl)
    addAccountOptions(debitSelect, data.accounts)
    addAccountOptions(creditSelect, data.accounts)
    submitButton.disabled = false
    return data.accounts.length
  }

  const filterValuesFromControls = () => ({
    dateFrom: dateFromFilter.value,
    dateTo: dateToFilter.value,
    memo: memoFilter.value.trim().toLocaleLowerCase(),
    auditStatus: auditStatusFilter.value
  })

  const currentFilters = () => appliedFilters

  const paginatedReadUrl = (baseUrl, page) => {
    const url = new URL(baseUrl, window.location.origin)
    url.searchParams.set("page", String(page))
    url.searchParams.set("per_page", String(readPageSize))
    if (appliedFilters.dateFrom) url.searchParams.set("txn_date_from", appliedFilters.dateFrom)
    if (appliedFilters.dateTo) url.searchParams.set("txn_date_to", appliedFilters.dateTo)
    return url
  }

  const appendUniqueById = (existingRecords, newRecords) => {
    const seenIds = new Set(existingRecords.map((record) => String(record.id)))
    return existingRecords.concat(newRecords.filter((record) => {
      const id = String(record.id)
      if (seenIds.has(id)) return false

      seenIds.add(id)
      return true
    }))
  }

  const matchesEntryFilters = (item, filters) => {
    if (filters.dateFrom && item.txn_date < filters.dateFrom) return false
    if (filters.dateTo && item.txn_date > filters.dateTo) return false

    return !filters.memo || (item.memo || "").toLocaleLowerCase().includes(filters.memo)
  }

  const lineList = (lines) => {
    const list = document.createElement("ul")
    lines.forEach((line) => {
      const item = document.createElement("li")
      const account = line.account_name || `Account ID ${line.account_id}`
      item.textContent = `${line.posting_type} ${currency.format(Number(line.amount))} — ${account}`
      list.appendChild(item)
    })
    return list
  }

  const renderEntries = (entries, total) => {
    recordRows.replaceChildren()
    const entryLabel = total === 1 ? "Journal Entry" : "Journal Entries"
    const page = journalPagination?.page || 1
    const availability = journalPagination?.has_more ?
      "More matching records are available." :
      "All matching records are loaded."
    recordsSummary.textContent = `Showing ${entries.length} of ${total} loaded ${entryLabel} through API page ` +
      `${page}. ${availability}`

    if (entries.length === 0) {
      const row = document.createElement("tr")
      const cell = document.createElement("td")
      cell.colSpan = 4
      cell.textContent = total === 0 ?
        "No Journal Entries were returned by QuickBooks." :
        "No Journal Entries match the current filters."
      row.appendChild(cell)
      recordRows.appendChild(row)
      return
    }

    entries.forEach((entry) => {
      const row = document.createElement("tr")
      const date = document.createElement("td")
      const id = document.createElement("td")
      const memo = document.createElement("td")
      const lines = document.createElement("td")

      date.textContent = entry.txn_date
      id.textContent = entry.doc_number ? `${entry.id} / ${entry.doc_number}` : entry.id
      memo.textContent = entry.memo || "—"
      lines.appendChild(lineList(entry.lines))
      row.append(date, id, memo, lines)
      recordRows.appendChild(row)
    })
  }

  const renderFilteredJournalEntries = () => {
    const filters = currentFilters()
    visibleJournalEntries = journalEntries.filter((entry) => matchesEntryFilters(entry, filters))
    exportJournalEntriesButton.disabled = visibleJournalEntries.length === 0
    renderEntries(visibleJournalEntries, journalEntries.length)
  }

  const loadJournalEntries = async ({ page = 1, append = false } = {}) => {
    const data = await apiRequest(paginatedReadUrl(journalEntriesUrl, page))
    journalEntries = append ? appendUniqueById(journalEntries, data.journal_entries) : data.journal_entries
    journalPagination = data.pagination
    journalEntriesLoaded = true
    loadMoreJournalEntriesButton.hidden = !journalPagination.has_more
    loadMoreJournalEntriesButton.disabled = false
    renderFilteredJournalEntries()
    return journalEntries.length
  }

  const renderAuditOperations = (operations, total) => {
    auditRows.replaceChildren()
    const operationLabel = total === 1 ? "operation" : "operations"
    const page = auditPagination?.page || 1
    const availability = auditPagination?.has_more ?
      "More matching operations are available." :
      "All matching operations are loaded."
    auditSummary.textContent = `Showing ${operations.length} of ${total} loaded local submission ` +
      `${operationLabel} through API page ${page}. ${availability}`

    if (operations.length === 0) {
      const row = document.createElement("tr")
      const cell = document.createElement("td")
      cell.colSpan = 7
      cell.textContent = total === 0 ?
        "No Journal Entry submissions have been recorded locally." :
        "No local submission operations match the current filters."
      row.appendChild(cell)
      auditRows.appendChild(row)
      return
    }

    operations.forEach((operation) => {
      const row = document.createElement("tr")
      const submitted = document.createElement("td")
      const state = document.createElement("td")
      const date = document.createElement("td")
      const memo = document.createElement("td")
      const amount = document.createElement("td")
      const accounts = document.createElement("td")
      const quickbooksId = document.createElement("td")

      submitted.textContent = new Date(operation.created_at).toLocaleString()
      state.textContent = `${operation.status} · operation ${operation.id}`
      state.className = `audit-status audit-status-${operation.status}`
      if (operation.error_code) state.textContent += ` · ${operation.error_code}`
      date.textContent = operation.txn_date
      memo.textContent = operation.memo
      amount.textContent = currency.format(Number(operation.amount))
      accounts.textContent = `Debit ${operation.debit_account_id} → Credit ${operation.credit_account_id}`
      quickbooksId.textContent = operation.quickbooks_journal_entry_id || "—"
      row.append(submitted, state, date, memo, amount, accounts, quickbooksId)
      auditRows.appendChild(row)
    })
  }

  const renderFilteredAuditOperations = () => {
    const filters = currentFilters()
    visibleAuditOperations = auditOperations.filter((operation) => {
      return matchesEntryFilters(operation, filters) &&
        (!filters.auditStatus || operation.status === filters.auditStatus)
    })
    exportAuditHistoryButton.disabled = visibleAuditOperations.length === 0
    renderAuditOperations(visibleAuditOperations, auditOperations.length)
  }

  const loadAuditHistory = async ({ page = 1, append = false } = {}) => {
    const data = await apiRequest(paginatedReadUrl(auditHistoryUrl, page))
    auditOperations = append ?
      appendUniqueById(auditOperations, data.journal_entry_operations) :
      data.journal_entry_operations
    auditPagination = data.pagination
    auditHistoryLoaded = true
    loadMoreAuditButton.hidden = !auditPagination.has_more
    loadMoreAuditButton.disabled = false
    renderFilteredAuditOperations()
    return auditOperations.length
  }

  const renderAppliedClientFilters = () => {
    if (journalEntriesLoaded) renderFilteredJournalEntries()
    if (auditHistoryLoaded) renderFilteredAuditOperations()
  }

  const reloadReadData = async () => {
    clearApiAlert()
    loadMoreJournalEntriesButton.disabled = true
    loadMoreAuditButton.disabled = true
    setStatus("GETting page 1 with the selected server-side entry dates…")

    const [entriesResult, auditResult] = await Promise.allSettled([
      loadJournalEntries(),
      loadAuditHistory()
    ])
    const failures = []

    if (entriesResult.status === "rejected") {
      failures.push(`Journal Entries: ${entriesResult.reason.message}`)
      markJournalEntriesUnavailable()
    }

    if (auditResult.status === "rejected") {
      failures.push(`Audit history: ${auditResult.reason.message}`)
      markAuditHistoryUnavailable()
    }

    if (failures.length > 0) {
      showApiAlert("Read-only filters could not be applied", failures.join(" "))
      setStatus("One or more filtered GET requests failed.", true)
      return
    }

    setStatus(
      `Server date filters loaded ${entriesResult.value} Journal Entries and ${auditResult.value} audit ` +
      `${auditResult.value === 1 ? "operation" : "operations"}. Memo and status filters apply to loaded pages.`
    )
  }

  const applyFilters = async () => {
    const nextFilters = filterValuesFromControls()
    const serverDatesChanged = nextFilters.dateFrom !== appliedFilters.dateFrom ||
      nextFilters.dateTo !== appliedFilters.dateTo
    appliedFilters = nextFilters

    if (serverDatesChanged || !journalEntriesLoaded || !auditHistoryLoaded) {
      await reloadReadData()
      return
    }

    renderAppliedClientFilters()
    setStatus(
      `Browser filters applied: ${visibleJournalEntries.length} of ${journalEntries.length} loaded Journal ` +
      `Entries and ${visibleAuditOperations.length} of ${auditOperations.length} loaded audit operations visible. ` +
      "No API request was made."
    )
  }

  const loadMoreJournalEntries = async () => {
    const nextPage = journalPagination?.next_page
    if (!nextPage) return

    const previousCount = journalEntries.length
    loadMoreJournalEntriesButton.disabled = true
    clearApiAlert()
    setStatus(`GETting Journal Entries API page ${nextPage}…`)

    try {
      await loadJournalEntries({ page: nextPage, append: true })
      const added = journalEntries.length - previousCount
      setStatus(
        `Loaded ${added} more Journal ${added === 1 ? "Entry" : "Entries"} through API page ${nextPage}.`
      )
    } catch (error) {
      showApiAlert("More Journal Entries could not be loaded", error.message)
      setStatus(`Journal Entries API page ${nextPage} failed.`, true)
      loadMoreJournalEntriesButton.disabled = false
    }
  }

  const loadMoreAuditHistory = async () => {
    const nextPage = auditPagination?.next_page
    if (!nextPage) return

    const previousCount = auditOperations.length
    loadMoreAuditButton.disabled = true
    clearApiAlert()
    setStatus(`GETting audit history API page ${nextPage}…`)

    try {
      await loadAuditHistory({ page: nextPage, append: true })
      const added = auditOperations.length - previousCount
      setStatus(
        `Loaded ${added} more audit ${added === 1 ? "operation" : "operations"} through API page ${nextPage}.`
      )
    } catch (error) {
      showApiAlert("More audit operations could not be loaded", error.message)
      setStatus(`Audit history API page ${nextPage} failed.`, true)
      loadMoreAuditButton.disabled = false
    }
  }

  const dateRangeIsValid = () => {
    const invalid = dateFromFilter.value && dateToFilter.value && dateFromFilter.value > dateToFilter.value
    dateToFilter.setCustomValidity(invalid ? "Entry date to must be on or after entry date from." : "")
    return !invalid
  }

  dateFromFilter.addEventListener("input", dateRangeIsValid)
  dateToFilter.addEventListener("input", dateRangeIsValid)
  financialReportStartDate.addEventListener("input", financialReportDateRangeIsValid)
  financialReportEndDate.addEventListener("input", financialReportDateRangeIsValid)
  financialReportType.addEventListener("change", syncFinancialReportDateFields)

  financialReportForm.addEventListener("submit", async (event) => {
    event.preventDefault()
    if (!financialReportDateRangeIsValid() || !financialReportForm.checkValidity()) {
      financialReportForm.reportValidity()
      return
    }

    clearApiAlert()
    loadFinancialReportButton.disabled = true
    exportFinancialReportButton.disabled = true
    financialReportSummary.textContent = `GETting ${selectedFinancialReportName()} from QuickBooks…`
    setStatus(`GETting ${selectedFinancialReportName()} through the Rails API…`)

    try {
      const report = await loadFinancialReport()
      setStatus(
        `${report.title} loaded as read-only JSON with ${report.rows.length} ` +
        `${report.rows.length === 1 ? "row" : "rows"}.`
      )
    } catch (error) {
      markFinancialReportUnavailable()
      showApiAlert("Financial statement request failed", error.message)
      setStatus("The selected financial statement API request failed.", true)
    } finally {
      loadFinancialReportButton.disabled = false
    }
  })

  filterForm.addEventListener("submit", async (event) => {
    event.preventDefault()
    if (!dateRangeIsValid()) {
      filterForm.reportValidity()
      return
    }

    await applyFilters()
  })

  clearFiltersButton.addEventListener("click", async (event) => {
    event.preventDefault()
    filterForm.reset()
    dateToFilter.setCustomValidity("")
    await applyFilters()
  })

  loadMoreJournalEntriesButton.addEventListener("click", loadMoreJournalEntries)
  loadMoreAuditButton.addEventListener("click", loadMoreAuditHistory)

  const csvCell = (value) => {
    const text = value == null ? "" : String(value)
    const spreadsheetSafeText = /^[=+\-@\t\r\n]/.test(text) ? `\t${text}` : text
    return `"${spreadsheetSafeText.replace(/"/g, '""')}"`
  }

  const filenameDate = () => {
    const now = new Date()
    const year = now.getFullYear()
    const month = String(now.getMonth() + 1).padStart(2, "0")
    const day = String(now.getDate()).padStart(2, "0")
    return `${year}-${month}-${day}`
  }

  const downloadCsv = (filename, headers, rows) => {
    const csv = [headers, ...rows].map((row) => row.map(csvCell).join(",")).join("\r\n")
    const blob = new Blob(["\uFEFF", csv], { type: "text/csv;charset=utf-8" })
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = url
    link.download = filename
    link.hidden = true
    document.body.appendChild(link)
    link.click()
    link.remove()
    window.setTimeout(() => URL.revokeObjectURL(url), 1000)
  }

  exportFinancialReportButton.addEventListener("click", () => {
    if (!currentFinancialReport) return

    const report = currentFinancialReport
    const columnHeaders = report.columns.map((column, index) => column.title || `column_${index + 1}`)
    const headers = [
      "report_type",
      "accounting_basis",
      "currency",
      "start_date",
      "end_date",
      "row_kind",
      "row_group",
      "row_depth",
      ...columnHeaders
    ]
    const rows = report.rows.map((row) => [
      report.type,
      report.basis,
      report.currency,
      report.start_date,
      report.end_date,
      row.kind,
      row.group,
      row.depth,
      ...row.cells.map((cell) => cell.value)
    ])
    const filenameType = report.type.replaceAll("_", "-")

    downloadCsv(`quickbooks-${filenameType}-${filenameDate()}.csv`, headers, rows)
    setStatus(
      `Downloaded ${rows.length} ${report.title} ${rows.length === 1 ? "row" : "rows"}. ` +
      "No API request was made."
    )
  })

  exportJournalEntriesButton.addEventListener("click", () => {
    const headers = [
      "txn_date",
      "quickbooks_journal_entry_id",
      "doc_number",
      "memo",
      "balanced",
      "posting_type",
      "amount",
      "account_id",
      "account_name",
      "line_description"
    ]
    const rows = visibleJournalEntries.flatMap((entry) => entry.lines.map((line) => [
      entry.txn_date,
      entry.id,
      entry.doc_number,
      entry.memo,
      entry.balanced,
      line.posting_type,
      line.amount,
      line.account_id,
      line.account_name,
      line.description
    ]))

    downloadCsv(`quickbooks-journal-entries-${filenameDate()}.csv`, headers, rows)
    const entryLabel = visibleJournalEntries.length === 1 ? "Journal Entry" : "Journal Entries"
    setStatus(
      `Downloaded ${rows.length} line ${rows.length === 1 ? "row" : "rows"} for ` +
      `${visibleJournalEntries.length} visible ${entryLabel}. No API request was made.`
    )
  })

  exportAuditHistoryButton.addEventListener("click", () => {
    const headers = [
      "operation_id",
      "status",
      "submitted_at",
      "completed_at",
      "txn_date",
      "memo",
      "amount",
      "debit_account_id",
      "credit_account_id",
      "quickbooks_journal_entry_id",
      "error_code"
    ]
    const rows = visibleAuditOperations.map((operation) => [
      operation.id,
      operation.status,
      operation.created_at,
      operation.completed_at,
      operation.txn_date,
      operation.memo,
      operation.amount,
      operation.debit_account_id,
      operation.credit_account_id,
      operation.quickbooks_journal_entry_id,
      operation.error_code
    ])

    downloadCsv(`journal-entry-audit-${filenameDate()}.csv`, headers, rows)
    setStatus(
      `Downloaded ${rows.length} visible audit ${rows.length === 1 ? "operation" : "operations"}. ` +
      "No API request was made."
    )
  })

  form.addEventListener("submit", async (event) => {
    event.preventDefault()
    if (!window.confirm("POST one real balanced Journal Entry to the QuickBooks sandbox?")) return

    submitButton.disabled = true
    clearApiAlert()
    setStatus("POSTing Journal Entry through the Rails API…")

    const formData = new FormData(form)
    const journalEntry = {
      txn_date: formData.get("journal_entry[txn_date]"),
      memo: formData.get("journal_entry[memo]"),
      amount: formData.get("journal_entry[amount]"),
      debit_account_id: formData.get("journal_entry[debit_account_id]"),
      credit_account_id: formData.get("journal_entry[credit_account_id]")
    }

    let data
    let postError
    try {
      data = await apiRequest(journalEntriesUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Idempotency-Key": idempotencyKey },
        body: JSON.stringify({ journal_entry: journalEntry })
      })
      idempotencyKey = nextIdempotencyKey()
      form.querySelector("[name='journal_entry[memo]']").value = ""
      form.querySelector("[name='journal_entry[amount]']").value = ""
    } catch (error) {
      postError = error
      if (error.apiCode === "quickbooks_journal_entry_input_invalid" ||
        renewableIdempotencyErrorCodes.has(error.apiCode)) {
        idempotencyKey = nextIdempotencyKey()
      }
    }

    const [entriesRefresh, auditRefresh] = await Promise.allSettled([
      loadJournalEntries(),
      loadAuditHistory()
    ])
    const refreshFailures = [entriesRefresh, auditRefresh]
      .filter((result) => result.status === "rejected")
      .map((result) => result.reason.message)

    if (postError) {
      const outcomeGuidance = postError.apiCode?.startsWith("idempotency_") ||
        postError.apiCode === "quickbooks_journal_entry_input_invalid" ?
        "" :
        " Check QuickBooks before retrying because the transaction status may be uncertain."
      const refreshGuidance = refreshFailures.length === 0 ?
        " Journal Entries and audit history were refreshed." :
        ` Related GET refresh failed: ${refreshFailures.join(" ")}`
      showApiAlert(
        "Journal Entry request failed",
        `${postError.message}${outcomeGuidance}${refreshGuidance}`
      )
      setStatus("The Journal Entry POST failed; its related GET APIs were attempted.", true)
    } else if (refreshFailures.length > 0) {
      const action = data.idempotency.replayed ? "Reused" : "Created"
      showApiAlert(
        `${action} Journal Entry, but refresh failed`,
        `QuickBooks Journal Entry ${data.journal_entry.id} is confirmed. ${refreshFailures.join(" ")}`
      )
      setStatus(`${action} QuickBooks Journal Entry ${data.journal_entry.id}; dashboard refresh failed.`, true)
    } else {
      const action = data.idempotency.replayed ? "Reused" : "Created"
      const replayMessage = data.idempotency.replayed ? " No duplicate transaction was created." : ""
      setStatus(
        `${action} QuickBooks Journal Entry ${data.journal_entry.id} through the API and read it back. ` +
        `Journal Entries and audit history were refreshed.${replayMessage}`
      )
    }

    submitButton.disabled = false
  })

  syncFinancialReportDateFields()

  Promise.allSettled([loadAccounts(), loadJournalEntries(), loadAuditHistory(), loadFinancialReport()]).then(([
    accountsResult,
    entriesResult,
    auditResult,
    reportResult
  ]) => {
    const failures = []

    if (accountsResult.status === "rejected") {
      failures.push(`Accounts: ${accountsResult.reason.message}`)
      markAccountsUnavailable()
    }

    if (entriesResult.status === "rejected") {
      failures.push(`Journal Entries: ${entriesResult.reason.message}`)
      markJournalEntriesUnavailable()
    }

    if (auditResult.status === "rejected") {
      failures.push(`Audit history: ${auditResult.reason.message}`)
      markAuditHistoryUnavailable()
    }

    if (reportResult.status === "rejected") {
      failures.push(`Profit & Loss: ${reportResult.reason.message}`)
      markFinancialReportUnavailable()
    }

    if (failures.length > 0) {
      showApiAlert("Dashboard API data could not be loaded", failures.join(" "))
      setStatus("One or more dashboard API requests failed.", true)
      return
    }

    setStatus(
      `API ready: ${accountsResult.value} Accounts, ${entriesResult.value} Journal Entries, and ` +
      `${auditResult.value} local audit ${auditResult.value === 1 ? "operation" : "operations"}, plus ` +
      `${reportResult.value.title}, loaded as JSON.`
    )
  })
})
