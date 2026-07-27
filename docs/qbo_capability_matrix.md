# QuickBooks capability matrix

The current app exposes a controlled local QuickBooks Online sandbox surface.

| Data | QuickBooks representation | GET | POST | Accounting impact | Status |
|---|---|---|---|---|---|
| Company connection | CompanyInfo/OAuth | Yes | OAuth only | None | Live sandbox validated |
| CFO reports | ProfitAndLoss, BalanceSheet, CashFlow, GeneralLedger, TrialBalance | Five explicit Rails GETs | No report POST | None; QuickBooks calculates from transactions | All five live sandbox validated; General Ledger reconciled 8 controlled posting legs and 2 zero-dollar inventory-start rows |
| Journal Entry account choices | Account | Eligible active Account query | No Account creation | None from reading | 87 choices live validated |
| Financial records | JournalEntry | Date-filtered and paginated GET | Audited/idempotent balanced create + readback | Selected Accounts are debited/credited | GET and one approved $1 write validated |
| Submission audit history | **Local-only** `quickbooks_sync_operations` | PostgreSQL GET | Rows produced by create APIs | None from reading | Existing Journal Entry audit remains scoped to its operation type |
| Employee directory | Employee | Active Employee query | Names plus optional email/phone; no payroll/PII fields | Non-posting master data | 3 live; controlled create/readback ID `400000001` validated |
| Employee time | TimeActivity | Recent employee time query | Active Employee, ISO date, whole hours/minutes, description | Records time; does not calculate payroll or invoice | 6 live; controlled 15-minute ID `1073741824` validated |
| Tax configuration | TaxCode, TaxRate, TaxAgency, TaxService | Codes, distinct rates, and agencies | New TaxCode from one existing active rate | Configuration only; no filing/payment/calculation | 6/3/2 live; TaxCode `4` created/read back with Rate `3` |
| Inventory master data | Item plus supporting Accounts | Inventory Items and eligible account choices | New Inventory Item with decimal-safe quantity/cost/price and readback | Positive opening quantity/cost can affect inventory value | 5 live; zero-opening Item `19` created/read back and reports reconciled |
| Customers | Customer | Active Customer query | Unique display name and optional company/contact data | Non-posting list record | 30 live; controlled create/readback ID `58` validated |
| Vendors | Vendor | Active Vendor query | Unique display name and optional company/contact data | Non-posting list record | 27 live; controlled create/readback ID `59` validated |
| Sales invoices | Invoice plus Customer and Item choices | Up to 1,000 Invoices and active references | One sale Item line, ISO dates, decimal amount, readback | Increases sales/receivable and may affect inventory | 32 live; $2 Invoice `147` created/read back and settled |
| Vendor bills | Bill plus Vendor and Account choices | Up to 1,000 Bills and active references | One account-based expense line, ISO dates, decimal amount, readback | Increases expense/payable | 16 live; $1 Bill `149` created/read back and settled |
| Customer receipts | Payment plus open Invoice choices | Payments and open Invoices | One Payment linked to one open Invoice, capped at current balance | Reduces receivable; QuickBooks chooses its default deposit behavior | 17 live; Payment `148` fully applied to Invoice `147` |
| Vendor disbursements | BillPayment plus open Bill/bank choices | BillPayments, open Bills, active bank Accounts | One check-style BillPayment linked to one Bill, capped at current balance | Reduces cash and payable | 11 live; BillPayment `150` fully applied from Checking to Bill `149` |
| Browser views/CSV | Rails HTML/JavaScript | API-backed tables and existing financial CSV projections | No extra API write | None from display/export | Dashboard shell and API alerts retained |

Not supported: payroll runs, compensation, paychecks, deductions, benefits, payroll calculations or filings;
tax-rate/agency creation, tax calculation, returns, payments, or filings; inventory adjustments, purchase orders,
sales receipts, categories, bundles, or Account auto-creation; invoice delivery, electronic payment processing,
multi-line editing, refunds, credits, arbitrary JSON uploads, production QuickBooks, bulk synchronization, or
reports beyond the five listed reports.
