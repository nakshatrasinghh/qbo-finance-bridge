# QuickBooks references

Current official Intuit documentation checked through 2026-07-21 for the implemented dashboard:

Phase 8 introduces no new QuickBooks entity, field, report, or request. Its audit-history GET reads only the local
`quickbooks_sync_operations` table, so the existing Intuit references below remain unchanged and no QuickBooks
capability is inferred from local audit data.

Phase 9 also introduces no Intuit behavior. Entry-date, memo, and audit-status filtering plus CSV generation run
only in the browser against bounded JSON already returned by the existing APIs. Applying, clearing, or exporting
a filter makes no QuickBooks request and adds no QuickBooks field, entity, or write.

Phase 10 moves only the transaction-date predicate and page selection into the two existing read APIs. The
QuickBooks Journal Entry GET uses native `TxnDate` filtering plus documented query ordering/pagination. The local
audit GET applies the same date meaning to the original preserved submitted date in PostgreSQL and does not call
QuickBooks. Memo/status filtering and CSV generation remain browser-only.

Phase 11 adds no Intuit capability. Final acceptance reuses existing read-only CompanyInfo, Account, and Journal
Entry calls. A direct sandbox Account query confirmed that legacy Account `1150040000`,
`CFO Bridge Demo Operating Expense`, remains active and typed `Expense`; it was not modified. The Account remains
excluded from both selectors and Journal Entry validation.

Phase 12 adds three read-only generated financial statements. It does not create or update any QuickBooks entity.
Profit & Loss and Cash Flow use an inclusive period; Balance Sheet uses one as-of date that Rails forwards as the
report `end_date`. Profit & Loss and Balance Sheet may explicitly request `Cash` or `Accrual` accounting basis.
The Cash Flow reference does not list `accounting_method`, and its response header does not include `ReportBasis`.

Phase 13 adds only the public Accounting API surface that the connected sandbox exposes for the requested
payroll, tax, and inventory domains. Intuit's current release notes state that the dedicated Payroll API is closed
beta and unavailable to new developers. Employee and TimeActivity are therefore labeled payroll-adjacent; the app
does not claim to calculate or submit payroll.

Phase 14 added the documented Customer, Vendor, Invoice, Bill, Payment, and BillPayment Accounting API resources
plus Trial Balance and General Ledger Rails GETs. The scope is one-line controlled transactions using
pre-existing active references; it does not infer electronic payment processing or document-delivery behavior.

Phase 15 corrects only the General Ledger vendor path after read-only sandbox comparison. Intuit's report
inventory names `GeneralLedgerDetail`, while its Accounting API overview refers to `GeneralLedger`. In the
connected sandbox, every `GeneralLedgerDetail` parameter variant returned `5020`, but `reports/GeneralLedger`
returned HTTP 200 with the requested dates and Accrual basis. The fixed explicit map now uses the verified path;
no caller can supply a vendor endpoint.

## OAuth 2.0

- [Set up OAuth 2.0](https://developer.intuit.com/app/developer/qbo/docs/develop/authentication-and-authorization/oauth-2.0)
- [OAuth 2.0 FAQ](https://developer.intuit.com/app/developer/qbo/docs/develop/authentication-and-authorization/faq)

Used for the accounting scope, authorization/token/revocation endpoints, state handling, access-token lifetime, refresh-token rotation, and disconnect behavior.

## REST requests

- [Basic schema and REST API formats](https://developer.intuit.com/app/developer/qbo/docs/learn/rest-api-features)
- [Request ID field definition](https://developer.intuit.com/app/developer/qbpayments/docs/learn/learn-basic-field-definitions)
- [QuickBooks Online error codes](https://developer.intuit.com/app/developer/qbo/docs/develop/troubleshooting/error-codes)

Used for the sandbox realm-scoped URI, JSON POST, single-entity GET, query GET, bearer/accept/content-type headers, `intuit_tid`, timeouts, and 429 behavior.

For Journal Entry writes, Rails requires a UUID no longer than 50 characters and forwards the same value as
Intuit's `requestid` query parameter. Intuit documents this parameter as the per-company idempotency identifier for
QuickBooks Online Accounting API writes. Duplicate request ID (`600`), invalid request ID (`2130`), and balanced
Journal Entry (`2300`) error guidance was reviewed for Phase 7. Rails additionally scopes and enforces the key by
the local QuickBooks connection before making the external request.

## Queries

- [Query operations and syntax](https://developer.intuit.com/app/developer/qbo/docs/learn/explore-the-quickbooks-online-api/data-queries)

Used for `SELECT * FROM Account WHERE Active = true` and date-filtered/ordered `SELECT * FROM JournalEntry`
queries. Intuit documents filter conditions joined with `AND`, `ORDERBY`, one-based positive `STARTPOSITION`,
positive `MAXRESULTS`, and a 1,000-entity maximum. This API deliberately caps requested pages at 50 records and
uses one additional lookahead record to report whether another page exists.

## Accounts

- [Financial accounts in QuickBooks Online](https://developer.intuit.com/app/developer/qbo/docs/learn/learn-basic-bookkeeping/accounts)
- [Account entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/account)

Used for active Account IDs/names/types in the debit and credit dropdowns. A/R and A/P are excluded because a simple Journal Entry line to those control accounts requires additional entity context.

## Journal Entries

- [JournalEntry entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/journalentry)
- [Transaction `TxnDate` schema](https://static.developer.intuit.com/sdkdocs/qbv3doc/ippdotnetdevkitv3/html/0b5f8961-f32e-e396-3a39-7b3e241434e8.htm)
- [JournalEntryLineDetail schema](https://static.developer.intuit.com/sdkdocs/qbv3doc/ipp-v3-java-devkit-javadoc/com/intuit/ipp/data/JournalEntryLineDetail.html)
- [Basic bookkeeping](https://developer.intuit.com/app/developer/qbo/docs/learn/learn-basic-bookkeeping)

Used for `TxnDate`, `PrivateNote`, `Line`, `Amount`, `DetailType: JournalEntryLineDetail`, `PostingType` (`Debit`/`Credit`), and `AccountRef.value`. The dashboard always sends equal positive debit and credit amounts in the same request.

The Intuit transaction schema also identifies `TxnDate` as filterable and sortable. Phase 10 therefore orders
Journal Entry reads by `TxnDate DESC, Id DESC` and applies inclusive `TxnDate >=`/`TxnDate <=` predicates only
when the corresponding validated ISO date parameter is present.

## Financial reports

- [Run reports](https://developer.intuit.com/app/developer/qbo/docs/workflows/run-reports)
- [Reporting in QuickBooks Online](https://developer.intuit.com/app/developer/qbo/docs/learn/learn-basic-bookkeeping/business-analytics)
- [ProfitAndLoss entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/profitandloss)
- [BalanceSheet entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/balancesheet)
- [CashFlow entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/cashflow)

Used for realm-scoped GET requests to `reports/ProfitAndLoss`, `reports/BalanceSheet`, and `reports/CashFlow`.
Intuit documents report metadata in `Header`, ordered column definitions in `Columns`, and recursively nested
section/data/summary content in `Rows`. The implementation preserves that ordering in a flattened presentation
shape, keeps money as decimal strings, and reports the QuickBooks-provided accounting basis, currency, generated
time, start/end periods, and `NoReportData` state.

Live Cash Flow validation on 2026-07-16 found one leaf row with `ColData` and `group` but no `type`. The normalizer
accepts this exact observed response only as a data row when `ColData` is an array. It continues to reject unknown
row types and missing cell arrays rather than silently dropping report content.

Intuit recommends report date ranges of no more than six months. Rails enforces that bound for Profit & Loss and
Cash Flow. Balance Sheet is a point-in-time statement, so its public `as_of_date` becomes QuickBooks `end_date`.
The Profit & Loss and Balance Sheet entity references list `accounting_method` with `Cash` and `Accrual`; the Cash
Flow entity reference does not, so Rails does not forward or claim that parameter for Cash Flow. No `POST`, local
snapshot, report recalculation, or unsupported field is introduced.

Phase 14 added Trial Balance and the General Ledger Rails endpoint using the report inventory's
`GeneralLedgerDetail` name. Phase 15 reconciles that documentation with observed sandbox behavior and the
Accounting API overview's `GeneralLedger` name. The corrected `reports/GeneralLedger` GET accepts the same
validated six-month period and accounting basis and returns the standard Header/Columns/Rows envelope, so the
existing strict parser is reused unchanged.

## Customers, vendors, invoices, bills, and payments

- [Explore the QuickBooks Online Accounting API](https://developer.intuit.com/app/developer/qbo/docs/learn/explore-the-quickbooks-online-api)
- [Customer entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/customer)
- [Vendor entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/vendor)
- [Invoice entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/invoice)
- [Bill entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/bill)
- [Payment entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/payment)
- [BillPayment entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/billpayment)
- [Create basic invoices](https://developer.intuit.com/app/developer/qbo/docs/workflows/create-an-invoice)
- [Basic invoicing implementation](https://developer.intuit.com/app/developer/qbo/docs/develop/basic-implementations/basic-invoicing-implementation)
- [Basic billing implementation](https://developer.intuit.com/app/developer/qbo/docs/develop/basic-implementations/basic-billing-implementation)

Intuit identifies Customer and Vendor as list resources, and Invoice, Bill, Payment, and BillPayment as
transaction resources. The official invoicing workflow requires a Customer and Item reference. The billing
implementation shows a Vendor, account-based expense line, and Accounts Payable reference. Its payment examples
link Payment to Invoice and BillPayment to Bill; check-style BillPayment uses `CheckPayment.BankAccountRef`.

Rails therefore creates only those minimal shapes, reloads every referenced list/source record before POST,
forwards the UUID as Intuit `requestid`, and verifies the returned entity by ID. Amounts never pass through
`Float`. Customer Payment omits `DepositToAccountRef`, matching Intuit's basic implementation and leaving the
company's default receive-payment deposit behavior to QuickBooks.

## Payroll-adjacent workforce and time

- [Employee entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/employee)
- [TimeActivity entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/timeactivity)
- [QuickBooks Online release notes](https://developer.intuit.com/app/developer/qbo/docs/release-notes/general-release-notes)

Employee supports create/query/read/update regardless of whether QuickBooks Payroll is enabled, but payroll-enabled
companies restrict fields such as DisplayName and SSN. Rails deliberately limits creation to GivenName,
FamilyName, optional email, and optional phone and never accepts or returns SSN, birth date, pay rate, compensation,
or address. TimeActivity supports create/query/read/update/delete; Phase 13 uses only active EmployeeRef,
`NameOf: Employee`, exact TxnDate, integer Hours/Minutes, and Description. The closed-group PayrollItemRef is not
used. Neither operation is represented as a payroll run, paycheck, deduction, benefit, correction, or filing.

## Tax configuration

- [TaxCode entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/taxcode)
- [TaxRate entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/taxrate)
- [TaxService entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/taxservice)

TaxCode and TaxRate are query/read resources. New codes and rates are created through TaxService. Phase 13 reads
codes, rates, and agencies but limits POST to one new TaxCode associated with one existing active rate for Sales or
Purchase. It does not create a rate/agency, calculate tax on a transaction, submit a return, or make a TaxPayment.
US companies expose system-managed agencies/rates; vendor rejection remains a visible sanitized API error.

## Inventory items

- [Item entity reference](https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/item)
- [Items and inventory](https://developer.intuit.com/app/developer/qbo/docs/learn/learn-basic-bookkeeping/manage-inventory)
- [Basic inventory implementation](https://developer.intuit.com/app/developer/qbo/docs/develop/basic-implementations/basic-inventory-implementation)

Inventory Item creation requires a unique Name, `Type: Inventory`, InvStartDate, QtyOnHand, TrackQtyOnHand, and
references to an income, cost-of-goods-sold, and inventory-asset Account. Rails validates all referenced Accounts
against a fresh QuickBooks query, uses decimal-safe quantity/cost/price handling, and reads the Item back after
creation. Positive opening quantity/cost may affect QuickBooks inventory value. Phase 13 does not create Accounts,
categories, bundles, purchases, sales, or InventoryAdjustment transactions.

### Phase 17 contract revalidation

The official Intuit entity references for Employee, TimeActivity, TaxService, and Item were reviewed again on
2026-07-21 together with the Accounting API query guide, error-code reference, time-tracking workflow, inventory
overview, and basic inventory implementation already linked in this document. The controlled acceptance remains
inside the documented public Accounting API boundary:

- Employee is a list record; the acceptance uses only `GivenName` and `FamilyName`.
- Employee TimeActivity uses `NameOf: Employee`, one current `EmployeeRef`, `TxnDate`, `Hours`, `Minutes`, and
  `Description`; it does not supply payroll compensation or convert time into payroll or an invoice.
- TaxService creates a named TaxCode from one existing active TaxRate using `TaxRateDetails` and
  `TaxApplicableOn`; it does not create a rate or agency or file/pay tax.
- Inventory Item uses `Type: Inventory`, `TrackQtyOnHand`, `QtyOnHand`, `InvStartDate`, and current income, COGS,
  and inventory-asset references. The official inventory guidance confirms those three account roles.

Phase 17 therefore uses a zero opening inventory quantity. Unit price and purchase cost still validate decimal
fields and readback, while zero quantity makes the expected financial balance delta zero. QuickBooks can still
emit zero-dollar General Ledger initialization rows, which Phase 17 preserves and reconciles explicitly below.

## Live evidence

On 2026-07-21, read-only Phase 13 capability queries returned two Employees, five TimeActivities, five TaxCodes,
three TaxRates, two TaxAgencies, and eighteen Items including four Inventory Items. CompanyInfo returned
`PayrollFeature=false` and `ItemCategoriesFeature=true`. No Phase 13 POST was sent during this review.

On 2026-07-21, Phase 14 read-only queries returned 29 Customers, 26 Vendors, 31 Invoices, 15 Bills, 16 customer
Payments, and 10 BillPayments. Reference catalogs returned 18 eligible sales Items, 49 expense Accounts, one
Accounts Payable Account, 20 open Invoices, five open Bills, and two bank Accounts. Trial Balance returned three
columns and 49 rows. The initial `GeneralLedgerDetail` request returned Intuit `5020 Permission Denied`. Phase 15
then compared safe GET-only variants: `GeneralLedgerDetail` failed with full, date-only, and default parameters,
while `GeneralLedger` returned HTTP 200. The exact dashboard parameters normalized to 8 columns and 452 rows with
Accrual basis. No Phase 14 or Phase 15 POST was sent and the local audit ledger remained unchanged.

Phase 16 sent the six explicitly approved sandbox creates through the Rails JSON controllers. Customer `58` and
Vendor `59` were read back first. Invoice `147` used Customer `58`, Service Item `1`, and $2.00; Payment `148`
linked the full $2.00 to that Invoice. Bill `149` used Vendor `59`, Office Expenses `15`, Accounts Payable `33`,
and $1.00; BillPayment `150` linked the full $1.00 from Checking `35`. Independent reads returned zero remaining
balance on Invoice `147` and Bill `149`. P&L, Balance Sheet, Trial Balance, and General Ledger reconciled the
expected changes, and General Ledger showed exactly eight native accounting legs. Six same-key replays returned
stored HTTP 200 results and did not create another QuickBooks record or local operation.

A later stale browser confirmation submitted the same Customer fields with a new UUID. The existing
entity-specific active-name validation queried current Customers, detected Customer `58`, and returned HTTP 422
before any Customer POST. Local operation `24` is preserved as rejected audit evidence; Customer count and all
reconciled financial values remained unchanged.

Phase 17 sent four explicitly approved sandbox creates through the Rails JSON controllers. Employee `400000001`,
linked TimeActivity `1073741824`, Sales TaxCode `4`, and zero-opening Inventory Item `19` were each read back
before Rails returned HTTP 201. Independent GETs returned exactly one matching record and counts of 3 Employees,
6 TimeActivities, 6 TaxCodes, 3 distinct TaxRates, 2 TaxAgencies, and 5 Inventory Items. Four same-key replays
returned stored HTTP 200 results without another QuickBooks write or audit row.

The TaxRate query returned identical TaxRate ID `3` twice after the new code reused that rate. Rails now
normalizes identical duplicate IDs to one record and rejects conflicting duplicates. QuickBooks also emitted two
General Ledger rows for transaction `151`, `Inventory Starting Value`, even though Item `19` opened at quantity
zero. Both amounts are `.00`, split between Opening Balance Equity and Inventory Asset. P&L, Balance Sheet, Cash
Flow, and Trial Balance remained byte-for-byte stable; General Ledger increased from 460 to 462 rows with no
balance change.

On 2026-07-15, the connected sandbox returned 90 active Accounts; after excluding A/R, A/P, and the discarded
demo Account, 87 are available to the form.

Phase 6 sent one explicitly approved controlled JournalEntry POST. QuickBooks returned ID `146` for a 2026-07-15
$1.00 debit to Office Expenses (Account `15`) and equal credit to Supplies (Account `20`). The create operation
read the entity back before returning success. A subsequent independent Journal Entries query returned five total
records and exactly one matching memo, with `balanced: true` and both expected lines. No retry was sent.

For Phase 10, a live read-only query used both inclusive date bounds, `ORDERBY TxnDate DESC, Id DESC`,
`STARTPOSITION 1`, and `MAXRESULTS 3`. The sandbox returned IDs `146`, `145`, and `8` in the expected deterministic
order. Subsequent API and dashboard validation read the same five total Journal Entries. Phase 10 sent no
QuickBooks POST and changed no local financial/audit data.
